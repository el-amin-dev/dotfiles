#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  test-syntax.sh — static + load checks for the zsh profile.
#
#  Run from anywhere:  ./tests/test-syntax.sh
#  Exit status: 0 = all passed, 1 = at least one failure.
#
#  These checks exist because every one of them corresponds to a bug
#  that actually shipped:
#
#    • a syntax error in one module aborts the rest of the load, and
#      the shell still opens — so the breakage is easy to miss
#    • a trailing failed test in .zshrc leaks a non-zero exit status
#      into the first prompt, showing a phantom "✘ 1" (see the loader)
#    • integrations executed by `sh` (MANPAGER, FZF_*) cannot use this
#      shell's aliases, so they silently degrade when they reference a
#      binary name that does not exist on this distro (ADR-003)
# ════════════════════════════════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE_DIR="$REPO_DIR/zshprofile"

pass_count=0
fail_count=0
warn_count=0

pass() { printf '\033[1;32m  PASS\033[0m  %s\n' "$1"; pass_count=$((pass_count + 1)); }
fail() { printf '\033[1;31m  FAIL\033[0m  %s\n'  "$1"; fail_count=$((fail_count + 1)); }
# WARN = a real problem this repo does not control. Reported, not fatal.
warn() { printf '\033[1;33m  WARN\033[0m  %s\n' "$1"; warn_count=$((warn_count + 1)); }
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

if ! command -v zsh >/dev/null 2>&1; then
  printf '\033[1;31mzsh is not installed — cannot run these tests.\033[0m\n'
  exit 1
fi

# ── 1. Every module parses ─────────────────────────────────────────
section "1. Syntax (zsh -n)"
for f in "$PROFILE_DIR/.zshrc" "$PROFILE_DIR"/modules/[0-9]*.zsh; do
  [[ -r "$f" ]] || continue
  name="${f#"$REPO_DIR"/}"
  if err="$(zsh -n "$f" 2>&1)"; then
    pass "$name"
  else
    fail "$name -- $err"
  fi
done

# ── 2. The profile loads, and leaves a clean exit status ───────────
# A non-zero status here is what paints a phantom "✘ 1" on the first
# prompt of every new terminal.
section "2. Clean load"
if ZDOTDIR="$PROFILE_DIR" zsh -i -c 'exit 0' >/dev/null 2>&1; then
  pass "profile loads and exits 0"
else
  fail "profile load exited non-zero (phantom exit status on first prompt)"
fi

# ── 3. Modules are loaded in numeric order by the loader ───────────
# 95-zoxide MUST come after 90-spaceship: zoxide's chpwd hook is
# dropped if the prompt framework rebuilds $chpwd_functions afterwards
# (ADR-004).
section "3. Load order"
order="$(ZDOTDIR="$PROFILE_DIR" zsh -i -c \
  'print -l "$ZSH_PROFILE_DIR"/modules/[0-9]*.zsh(N:t)' 2>/dev/null)"
if [[ "$order" == "$(printf '%s\n' "$order" | sort)" ]]; then
  pass "modules glob in numeric order"
else
  fail "module load order is not sorted numerically"
fi
if [[ -r "$PROFILE_DIR/modules/95-zoxide.zsh" ]]; then
  pass "zoxide lives in a 95-* module (loads after the 90 prompt)"
else
  fail "zoxide module missing from modules/95-zoxide.zsh"
fi

# ── 4. sh-executed integrations reference a real binary (ADR-003) ──
# These are run by `sh`, NOT by the interactive shell, so they cannot
# use aliases. On Debian/Ubuntu the binaries are fdfind and batcat.
section "4. Alias-free integrations resolve to real binaries"
probe() {
  ZDOTDIR="$PROFILE_DIR" zsh -i -c "printf '%s' \"\${$1}\"" 2>/dev/null
}

for var in ZSH_FD_BIN ZSH_BAT_BIN; do
  val="$(probe "$var")"
  if [[ -z "$val" ]]; then
    pass "$var empty (tool not installed — integrations correctly skipped)"
  elif command -v "$val" >/dev/null 2>&1; then
    pass "$var=$val resolves to an executable"
  else
    fail "$var=$val is not an executable on this machine"
  fi
done

# Whatever binary each integration names, `sh` must be able to find it.
check_cmd_in() {
  local label="$1" value="$2" binary="$3"
  if [[ -z "$value" ]]; then
    pass "$label unset (dependency absent — correctly skipped)"
  elif [[ -z "$binary" ]]; then
    fail "$label is set but names no binary: $value"
  elif sh -c "command -v $binary" >/dev/null 2>&1; then
    pass "$label uses '$binary', which sh can execute"
  else
    fail "$label references '$binary', which sh cannot find (alias-only name?)"
  fi
}

fzf_cmd="$(probe FZF_DEFAULT_COMMAND)"
check_cmd_in "FZF_DEFAULT_COMMAND" "$fzf_cmd" "${fzf_cmd%% *}"

altc_cmd="$(probe FZF_ALT_C_COMMAND)"
check_cmd_in "FZF_ALT_C_COMMAND" "$altc_cmd" "${altc_cmd%% *}"

manpager="$(probe MANPAGER)"
# MANPAGER is a pipeline: "sh -c 'col -bx | <bat> --language=man ...'"
man_bin="$(printf '%s' "$manpager" | sed -n 's/.*| *\([^ ]*\).*/\1/p')"
check_cmd_in "MANPAGER" "$manpager" "$man_bin"

# ── 5. Standard tools are not shadowed (ADR-002) ───────────────────
# A standard tool may be aliased only ADDITIVELY: the alias must still
# invoke that same binary. Pointing it at a different tool (grep→rg,
# cat→bat) changes its flags and its results, which is what ADR-002
# forbids. Note this must be checked at runtime, not by reading
# 60-aliases.zsh: Oh My Zsh defines aliases of its own.
section "5. No shadowing of standard tools (ADR-002)"
for cmd in cat grep egrep fgrep find sed awk; do
  definition="$(ZDOTDIR="$PROFILE_DIR" zsh -i -c "alias $cmd" 2>/dev/null)"
  if [[ -z "$definition" ]]; then
    pass "$cmd is not aliased"
    continue
  fi
  # "grep='grep --color=auto'" -> "grep --color=auto"
  expansion="${definition#*=}"
  expansion="${expansion#\'}"
  expansion="${expansion%\'}"
  target="${expansion%% *}"
  # egrep/fgrep legitimately expand to grep -E / grep -F.
  case "$cmd" in
    egrep|fgrep) expected="grep" ;;
    *)           expected="$cmd" ;;
  esac
  if [[ "$target" != "$expected" ]]; then
    fail "$cmd is aliased to '$target' — ADR-002 forbids shadowing with a different tool"
  elif [[ "$expansion" == *--exclude* || "$expansion" == *--ignore* ]]; then
    fail "$cmd alias silently filters results: $expansion"
  else
    pass "$cmd alias is additive only ($expansion)"
  fi
done

# ── 6. Secrets never reach the history file ────────────────────────
section "6. History hygiene"
if ZDOTDIR="$PROFILE_DIR" zsh -i -c '[[ -o histignorespace ]]' 2>/dev/null; then
  pass "HIST_IGNORE_SPACE set (space-prefixed commands are not recorded)"
else
  fail "HIST_IGNORE_SPACE unset — a space-prefixed secret would be saved"
fi
if ZDOTDIR="$PROFILE_DIR" zsh -i -c '[[ -o incappendhistorytime ]]' 2>/dev/null; then
  pass "INC_APPEND_HISTORY_TIME set (history survives a killed terminal)"
else
  fail "INC_APPEND_HISTORY_TIME unset — history is lost unless zsh exits cleanly"
fi
if ZDOTDIR="$PROFILE_DIR" zsh -i -c '[[ -o sharehistory ]]' 2>/dev/null; then
  fail "SHARE_HISTORY set — ADR-005 rejects live cross-terminal history"
else
  pass "SHARE_HISTORY unset (per ADR-005)"
fi

# ── 7. $HOME stays clean ───────────────────────────────────────────
# The repo's one promise about $HOME is that it holds a single symlink,
# ~/.zshrc, and nothing else. Runtime state belongs in cache/.
#
# This MUST be probed from a clean environment. Running `zsh -i` from an
# already-configured shell inherits the exported variables, so Oh My Zsh
# takes its "already set" branch and the bug disappears — which is
# exactly how a 170 KB compdump ended up in $HOME unnoticed.
section "7. \$HOME stays clean (probed from a clean environment)"
clean_probe() {
  env -i HOME="$HOME" PATH="$PATH" TERM="${TERM:-xterm}" \
    zsh -c "export ZSH_PROFILE_DIR='$PROFILE_DIR'
            source '$PROFILE_DIR/modules/00-env.zsh'
            print -r -- \"\${$1}\"" 2>/dev/null
}

# compinit runs inside module 10, so anything it needs must be exported
# by module 00 — checked before Oh My Zsh has had a chance to load.
compdump="$(clean_probe ZSH_COMPDUMP)"
if [[ -z "$compdump" ]]; then
  fail "ZSH_COMPDUMP unset before OMZ loads — compinit will dump into \$HOME"
elif [[ "$compdump" == "$PROFILE_DIR"/cache/* ]]; then
  pass "ZSH_COMPDUMP points into cache/ before OMZ loads"
else
  fail "ZSH_COMPDUMP points outside cache/: $compdump"
fi

histfile="$(clean_probe HISTFILE)"
if [[ "$histfile" == "$PROFILE_DIR"/cache/* ]]; then
  pass "HISTFILE points into cache/"
else
  fail "HISTFILE points outside cache/: $histfile"
fi

# Debian and Ubuntu run a bare `compinit` from /etc/zsh/zshrc, which is
# sourced BEFORE ~/.zshrc and so cannot see anything this repo sets. It
# writes its own dump to ${ZDOTDIR:-$HOME}/.zcompdump — a second copy,
# in $HOME, that none of the config above can prevent.
#
# This is outside the repo's control: the documented opt-out is
# `skip_global_compinit=1`, which has to be set in ~/.zshenv, and this
# repo deliberately installs only ~/.zshrc. Reported as a warning so the
# duplicate is visible rather than mysterious.
if [[ -r /etc/zsh/zshrc ]] && grep -qE '^\s*compinit\s*$' /etc/zsh/zshrc 2>/dev/null; then
  if [[ -n "${skip_global_compinit:-}" ]]; then
    pass "global compinit disabled via skip_global_compinit"
  else
    warn "/etc/zsh/zshrc runs a bare compinit before ~/.zshrc, writing a duplicate dump to \${ZDOTDIR:-\$HOME}/.zcompdump (see docs/RUNBOOK.md)"
  fi
else
  pass "no global compinit competing with this config"
fi

# Clean up the copy this script's own ZDOTDIR runs provoke, so it does
# not masquerade as repo state in git status.
rm -f "$PROFILE_DIR"/.zcompdump "$PROFILE_DIR"/.zcompdump.zwc

# ── Summary ────────────────────────────────────────────────────────
printf '\n────────────────────────────────────────\n'
summary="$pass_count passed"
(( warn_count > 0 )) && summary="$summary, $warn_count warned"
if (( fail_count == 0 )); then
  printf '\033[1;32m%s, 0 failed\033[0m\n' "$summary"
  exit 0
else
  printf '\033[1;31m%s, %d FAILED\033[0m\n' "$summary" "$fail_count"
  exit 1
fi
