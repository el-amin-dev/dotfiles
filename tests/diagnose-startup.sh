#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  diagnose-startup.sh — find out WHY a shell hangs or starts slowly.
#
#  Run it on the machine that misbehaves:
#      ./tests/diagnose-startup.sh
#
#  Every check has a timeout, so this script itself can never hang the
#  way the shell does. A check that times out IS the answer.
#
#  Written for a specific failure: on one machine the terminal accepted
#  no input until Ctrl-C, `source ~/.zshrc` did the same, and the
#  interrupted prompt sometimes left a literal `$(spaceship::rprompt)`
#  on screen. The same config was fine on three other machines. The
#  checks below are ordered by how likely each cause is, cheapest first.
# ════════════════════════════════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$REPO_DIR/zshprofile"
CACHE_DIR="$PROFILE_DIR/cache"
HISTFILE_PATH="$CACHE_DIR/zsh_history"

ok()    { printf '\033[1;32m  OK   \033[0m %s\n' "$1"; }
bad()   { printf '\033[1;31m  BAD  \033[0m %s\n' "$1"; }
info()  { printf '\033[1;36m  INFO \033[0m %s\n' "$1"; }
sect()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

verdicts=()

# ── 1. Where does the shell's state actually live? ─────────────────
# This is the single most useful fact. Network-mounted state is the
# root of the whole class of hangs below.
sect "1. Filesystem holding the shell's state"

fstype_of() {
  stat -f -c %T "$1" 2>/dev/null || echo unknown
}

for target in "$HOME" "$REPO_DIR" "$CACHE_DIR"; do
  [[ -e "$target" ]] || continue
  fs="$(fstype_of "$target")"
  case "$fs" in
    nfs*|smb*|cifs*|fuseblk|fuse*|afs*|9p*|glusterfs|lustre*|ceph*)
      bad "$target is on '$fs' — a NETWORK filesystem"
      verdicts+=( "network-fs:$target:$fs" )
      ;;
    unknown)
      info "$target — filesystem type could not be determined"
      ;;
    *)
      ok "$target is on '$fs' (local)"
      ;;
  esac
done

# ── 2. fcntl() locking on the history file ─────────────────────────
# `setopt HIST_FCNTL_LOCK` makes zsh take an fcntl() lock on $HISTFILE.
# That is correct and effectively free on a local disk. Over NFS or SMB
# it goes to the server's lock manager, and when that is unreachable,
# not running, or the export disallows locking, the call BLOCKS — with
# no error and no timeout. The shell stops before it can accept input,
# and Ctrl-C is the only way out, because interrupting the syscall is
# exactly what Ctrl-C does.
#
# `flock` here is a stand-in for the same kernel machinery zsh uses.
sect "2. fcntl/flock on the history file"

if [[ ! -e "$HISTFILE_PATH" ]]; then
  info "no history file yet at $HISTFILE_PATH — creating an empty one to test"
  mkdir -p "$CACHE_DIR" 2>/dev/null
  : > "$HISTFILE_PATH" 2>/dev/null
fi

if [[ ! -w "$HISTFILE_PATH" ]]; then
  bad "history file is not writable: $HISTFILE_PATH"
  verdicts+=( "histfile-unwritable" )
elif ! command -v flock >/dev/null 2>&1; then
  info "flock(1) not installed — skipping the direct lock test"
else
  if timeout 5 flock -x "$HISTFILE_PATH" -c true 2>/dev/null; then
    ok "took an exclusive lock in under 5s"
  else
    rc=$?
    if (( rc == 124 )); then
      bad "LOCKING HUNG — flock did not return within 5s"
      bad "  This is the failure. HIST_FCNTL_LOCK will hang the shell here."
      verdicts+=( "lock-hang" )
    else
      bad "locking failed (exit $rc) — the filesystem may not support it"
      verdicts+=( "lock-unsupported" )
    fi
  fi
fi

# Same thing, but through zsh itself, exactly as the config uses it.
if command -v zsh >/dev/null 2>&1; then
  if timeout 8 zsh -f -c "
      setopt HIST_FCNTL_LOCK
      HISTFILE='$HISTFILE_PATH'
      SAVEHIST=100; HISTSIZE=100
      fc -R 2>/dev/null
      print -s 'diagnostic probe'
      fc -A 2>/dev/null
      exit 0" >/dev/null 2>&1; then
    ok "zsh read and appended history with HIST_FCNTL_LOCK set"
  else
    if (( $? == 124 )); then
      bad "zsh HUNG writing history with HIST_FCNTL_LOCK — confirmed cause"
      verdicts+=( "zsh-hist-lock-hang" )
    else
      info "zsh history probe returned non-zero (not necessarily fatal)"
    fi
  fi
fi

# ── 3. Does the shell start at all, and how fast? ──────────────────
sect "3. Shell startup"

if ! command -v zsh >/dev/null 2>&1; then
  bad "zsh is not installed"
else
  start=$(date +%s%N)
  if timeout 20 zsh -i -c 'exit' >/dev/null 2>&1; then
    elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
    if (( elapsed > 2000 )); then
      bad "interactive startup took ${elapsed}ms — far too slow"
      verdicts+=( "slow-start:${elapsed}ms" )
    elif (( elapsed > 800 )); then
      info "interactive startup took ${elapsed}ms — slower than it should be"
    else
      ok "interactive startup: ${elapsed}ms"
    fi
  else
    bad "SHELL HUNG — no interactive prompt within 20s"
    verdicts+=( "startup-hang" )
  fi
fi

# ── 4. Which module is responsible? ────────────────────────────────
# Sources modules one at a time, cumulatively, each under a timeout.
# The first one that stalls is the culprit.
sect "4. Per-module load (cumulative, 15s timeout each)"

if command -v zsh >/dev/null 2>&1; then
  script=""
  for m in "$PROFILE_DIR"/modules/[0-9]*.zsh; do
    [[ -r "$m" ]] || continue
    name="${m##*/}"
    script+="source '$m'
"
    start=$(date +%s%N)
    if timeout 15 zsh -f -c "
        export ZSH_PROFILE_DIR='$PROFILE_DIR'
        $script
        exit 0" >/dev/null 2>&1; then
      elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
      if (( elapsed > 1000 )); then
        bad "  through $name: ${elapsed}ms"
        verdicts+=( "slow-module:$name" )
      else
        ok "  through $name: ${elapsed}ms"
      fi
    else
      bad "  HUNG at $name — this module is the problem"
      verdicts+=( "module-hang:$name" )
      break
    fi
  done
fi

# ── 5. Spaceship async worker ──────────────────────────────────────
# SPACESHIP_PROMPT_ASYNC forks a worker per prompt. Endpoint-security
# agents on managed machines can make fork/exec pathologically slow, and
# a worker that never reports back leaves the prompt half-rendered —
# which is what a stray literal `$(spaceship::rprompt)` on screen means.
sect "5. Prompt rendering"

if command -v zsh >/dev/null 2>&1; then
  if timeout 15 zsh -i -c 'print -rn -- "$PROMPT$RPROMPT"' 2>/dev/null | grep -q 'spaceship::rprompt'; then
    bad "prompt contains a LITERAL \$(spaceship::rprompt)"
    bad "  PROMPT_SUBST is off, or the theme did not finish loading."
    verdicts+=( "rprompt-literal" )
  else
    ok "no unexpanded prompt substitution"
  fi

  if timeout 15 zsh -i -c 'exit' >/dev/null 2>&1; then
    ok "prompt rendered without stalling"
  else
    bad "prompt rendering stalled — try SPACESHIP_PROMPT_ASYNC=false"
    verdicts+=( "prompt-async-hang" )
  fi
fi

# ── Verdict ────────────────────────────────────────────────────────
printf '\n────────────────────────────────────────\n'
if (( ${#verdicts[@]} == 0 )); then
  printf '\033[1;32mNothing wrong found on this machine.\033[0m\n'
  exit 0
fi

printf '\033[1;31mFindings:\033[0m\n'
printf '  %s\n' "${verdicts[@]}"

printf '\n\033[1mWhat to do\033[0m\n'
for v in "${verdicts[@]}"; do
  case "$v" in
    lock-hang|zsh-hist-lock-hang|lock-unsupported)
      cat <<'EOF'
  • History locking is the cause. modules/30-history.zsh now enables
    HIST_FCNTL_LOCK only on a local filesystem, so pulling the latest
    config fixes this. To confirm by hand right now:
        zsh -f -c 'HISTFILE=/tmp/h; setopt HIST_FCNTL_LOCK; fc -A'
    To override the autodetection permanently, in local/local.zsh:
        unsetopt HIST_FCNTL_LOCK
EOF
      ;;
    network-fs:*)
      printf '  • %s is network-mounted. Keep shell state off it:\n' "${v#network-fs:}"
      printf '    put  export ZSH_CACHE_DIR=/var/tmp/zsh-$USER  in local/local.zsh\n'
      ;;
    prompt-async-hang|rprompt-literal)
      printf '  • Prompt rendering stalls. In local/local.zsh:\n'
      printf '        SPACESHIP_PROMPT_ASYNC=false\n'
      ;;
    module-hang:*)
      printf '  • %s never finished loading — inspect it directly.\n' "${v#module-hang:}"
      ;;
  esac
done
exit 1
