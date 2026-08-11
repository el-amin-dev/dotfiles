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

# Ask zsh for the exact list the loader in .zshrc will iterate over,
# rather than re-deriving it here — otherwise this only tests that a
# sorted list is sorted, which can never fail.
mapfile -t order < <(
  env -i HOME="$HOME" PATH="$PATH" TERM="${TERM:-xterm}" zsh -c \
    "print -l '$PROFILE_DIR'/modules/[0-9]*.zsh(N:t)" 2>/dev/null
)

index_of() {  # echo the position of the module matching $1, or -1
  local pattern="$1" i=0
  for m in "${order[@]}"; do
    [[ "$m" == $pattern ]] && { printf '%s' "$i"; return 0; }
    i=$((i + 1))
  done
  printf '%s' -1
}

if (( ${#order[@]} == 0 )); then
  fail "loader glob matched no modules at all"
else
  pass "loader sees ${#order[@]} modules"
fi

# The rule from ADR-004: zoxide appends a chpwd hook, and a prompt
# framework that rebuilds $chpwd_functions afterwards silently drops it.
# zoxide must therefore be sourced after the prompt.
zoxide_at="$(index_of '*zoxide*')"
prompt_at="$(index_of '9[0-4]-*')"
if (( zoxide_at < 0 )); then
  fail "no zoxide module found in the load order"
elif (( prompt_at < 0 )); then
  pass "zoxide at position $zoxide_at (no prompt module to order against)"
elif (( zoxide_at > prompt_at )); then
  pass "zoxide (${order[$zoxide_at]}) loads after the prompt (${order[$prompt_at]})"
else
  fail "zoxide (${order[$zoxide_at]}) loads BEFORE the prompt (${order[$prompt_at]}) — its chpwd hook will be dropped (ADR-004)"
fi

# ── 4. sh-executed integrations reference a real binary (ADR-003) ──
# These are run by `sh`, NOT by the interactive shell, so they cannot
# use aliases. On Debian/Ubuntu the binaries are fdfind and batcat.
section "4. Alias-free integrations resolve to real binaries"

# Probe from an EMPTY environment, sourcing only 00-env.zsh.
#
# Spawning `zsh -i` from the current shell would inherit its exported
# variables, and 00-env.zsh sets MANPAGER and the FZF_* commands
# *conditionally* — only when the corresponding tool was found. An
# inherited value would therefore satisfy these assertions even if the
# module had skipped them entirely, which is precisely the failure this
# section exists to catch. (ZSH_FD_BIN and ZSH_BAT_BIN are assigned
# unconditionally and would not mask, but there is no reason to keep two
# probing strategies.)
probe() {
  env -i HOME="$HOME" PATH="$PATH" TERM="${TERM:-xterm}" \
    zsh -c "export ZSH_PROFILE_DIR='$PROFILE_DIR'
            source '$PROFILE_DIR/modules/00-env.zsh'
            printf '%s' \"\${$1}\"" 2>/dev/null
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
  elif sh -c 'command -v -- "$1"' _ "$binary" >/dev/null 2>&1; then
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

# fzf --preview strings are the third alias-free context named by ADR-003
# and the easiest to overlook, since they live in 70-functions.zsh rather
# than alongside the other exports. They are ordinary shell variables,
# not exported, so a full interactive load is needed and there is no
# inheritance to mask the result.
for pv in _fzf_file_preview _fzf_pipe_preview; do
  val="$(ZDOTDIR="$PROFILE_DIR" zsh -i -c "printf '%s' \"\${$pv}\"" 2>/dev/null)"
  check_cmd_in "$pv" "$val" "${val%% *}"
done

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

# HIST_FCNTL_LOCK must track the filesystem, not be set unconditionally.
# fcntl() locking over NFS/SMB blocks with no error and no timeout when
# the server's lock manager is unreachable, which hangs the shell before
# it accepts any input. The decision has to match reality on THIS
# machine — the same config is correct on a laptop and fatal on a box
# with a network-mounted home. See ADR-006.
hist_dir="$(probe HISTFILE)"; hist_dir="${hist_dir%/*}"
hist_fs="$(stat -f -c %T "$hist_dir" 2>/dev/null || echo unknown)"
lock_on=no
ZDOTDIR="$PROFILE_DIR" zsh -i -c '[[ -o histfcntllock ]]' 2>/dev/null && lock_on=yes
case "$hist_fs" in
  nfs*|smb*|cifs*|fuse*|afs*|9p*|glusterfs|lustre*|ceph*|unknown) want=no ;;
  *) want=yes ;;
esac
if [[ "$lock_on" == "$want" ]]; then
  if [[ "$want" == yes ]]; then
    pass "HIST_FCNTL_LOCK on, history is on local '$hist_fs'"
  else
    pass "HIST_FCNTL_LOCK correctly OFF, history is on '$hist_fs'"
  fi
else
  fail "HIST_FCNTL_LOCK=$lock_on but history is on '$hist_fs' — locking there can hang the shell at startup"
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

# compinit runs inside module 10, so anything it needs must be exported
# by module 00 — probe() checks the state before Oh My Zsh can load.
compdump="$(probe ZSH_COMPDUMP)"
if [[ -z "$compdump" ]]; then
  fail "ZSH_COMPDUMP unset before OMZ loads — compinit will dump into \$HOME"
elif [[ "$compdump" == "$PROFILE_DIR"/cache/* ]]; then
  pass "ZSH_COMPDUMP points into cache/ before OMZ loads"
else
  fail "ZSH_COMPDUMP points outside cache/: $compdump"
fi

histfile="$(probe HISTFILE)"
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

# ── 8. Prompt footer invariants ────────────────────────────────────
# The footer reports the previous command's exit status, so its capture
# hook has to observe $? before anything else touches it. Oh My Zsh,
# Spaceship and zsh-autosuggestions all register precmd hooks earlier
# (module 10), and any of them running first resets $? to 0 — the
# failure would be silent and total: every command would look
# successful.
section "8. Prompt footer (previous-command reporting)"
first_hook="$(ZDOTDIR="$PROFILE_DIR" zsh -i -c 'print -r -- ${precmd_functions[1]}' 2>/dev/null)"
if [[ "$first_hook" == "_prompt_capture" ]]; then
  pass "_prompt_capture runs first in precmd_functions"
else
  fail "precmd_functions starts with '$first_hook', not _prompt_capture — \$? is clobbered before the footer reads it"
fi

# A width of 0 (no tty) must fall back rather than render an empty rule.
if ZDOTDIR="$PROFILE_DIR" zsh -i -c 'COLUMNS=0; _prompt_footer' 2>/dev/null | grep -q '─'; then
  pass "separator still renders when COLUMNS is 0"
else
  fail "separator renders empty when COLUMNS is 0 (no tty)"
fi

# ── 9. No generated artifacts tracked in git ───────────────────────
# A completion dump was once committed by a `git add -A` because
# nothing ignored it. Generated state is reproducible by definition and
# does not belong in history; ignoring it is not enough if it is already
# tracked, since gitignore does not apply to tracked files.
section "9. Repository hygiene"
if command -v git >/dev/null 2>&1 && git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  # .gitkeep is deliberate: it preserves the directory skeleton through a
  # fresh clone, which is why cache/ and external/ are ignored by content
  # rather than by negation rules.
  tracked_junk="$(git -C "$REPO_DIR" ls-files \
    | grep -vE '(^|/)\.gitkeep$' \
    | grep -E '(^|/)\.?zcompdump|\.zwc$|(^|/)zsh_history$|(^|/)cache/' || true)"
  if [[ -z "$tracked_junk" ]]; then
    pass "no generated dumps, caches or history tracked"
  else
    fail "generated files are tracked: $(printf '%s' "$tracked_junk" | tr '\n' ' ')"
  fi

  # external/ holds cloned third-party repos with their own .git dirs;
  # tracking them produces broken gitlinks in a fresh clone.
  tracked_external="$(git -C "$REPO_DIR" ls-files \
    | grep -vE '(^|/)\.gitkeep$' \
    | grep -E '(^|/)external/(oh-my-zsh|plugins)/' || true)"
  if [[ -z "$tracked_external" ]]; then
    pass "cloned third-party code is not vendored"
  else
    fail "external clones are tracked: $(printf '%s' "$tracked_external" | head -1)"
  fi
else
  pass "not a git checkout — hygiene checks skipped"
fi

# ── 10. Shipped commands ───────────────────────────────────────────
# Anything in bin/ lands on $PATH for every shell, so a syntax error or
# a crash there is felt immediately and everywhere.
section "10. Commands in bin/"
shopt -s nullglob
bins=( "$PROFILE_DIR"/bin/* )
shopt -u nullglob

if (( ${#bins[@]} == 0 )); then
  pass "no shipped commands to check"
fi

# Properties every shipped command must have, whatever it does.
# NOTE: stdin is redirected from /dev/null throughout. `asciify` reads a
# line from stdin when given no text, so a test that leaves stdin
# attached would block instead of failing.
for bin in "${bins[@]}"; do
  name="${bin##*/}"
  [[ -x "$bin" ]] || fail "$name is not executable (it is on \$PATH)"

  interp="$(head -1 "$bin")"
  case "$interp" in
    *bash) checker=(bash -n) ;;
    *zsh)  checker=(zsh -n)  ;;
    *)     checker=() ;;
  esac
  if (( ${#checker[@]} )); then
    if err="$("${checker[@]}" "$bin" 2>&1)"; then
      pass "$name parses"
    else
      fail "$name has a syntax error: $err"
    fi
  fi

  if timeout 20 "$bin" --help </dev/null >/dev/null 2>&1; then
    pass "$name --help works"
  else
    fail "$name --help exited non-zero"
  fi
done

# my-computer is a report: it has rendering modes and must never come
# back empty. Checked specifically rather than assumed of every binary.
mc="$PROFILE_DIR/bin/my-computer"
if [[ -x "$mc" ]]; then
  for mode in "" "--no-color" "--ascii" "--no-color --ascii" "--all" "--no-banner"; do
    if timeout 25 "$mc" $mode </dev/null >/dev/null 2>&1; then
      pass "my-computer runs${mode:+ ${mode}}"
    else
      fail "my-computer exited non-zero${mode:+ with ${mode}}"
    fi
  done

  lines="$(timeout 25 "$mc" --no-color </dev/null 2>/dev/null | grep -c .)"
  if (( lines >= 15 )); then
    pass "my-computer produced $lines lines"
  else
    fail "my-computer produced only $lines lines — expected a full report"
  fi

  if timeout 25 "$mc" --ascii --no-color </dev/null 2>/dev/null \
       | LC_ALL=C grep -q '[^[:print:][:space:]]'; then
    fail "my-computer emits non-ASCII bytes in --ascii mode"
  else
    pass "my-computer is pure ASCII in --ascii mode"
  fi
fi

# asciify is a filter: it renders text it is given, on argv or stdin.
asc="$PROFILE_DIR/bin/asciify"
if [[ -x "$asc" ]]; then
  out="$(timeout 20 "$asc" --trim "HI" </dev/null 2>/dev/null)"
  if [[ "$(printf '%s' "$out" | grep -c .)" == 5 ]]; then
    pass "asciify renders 5 rows from an argument"
  else
    fail "asciify did not render 5 rows"
  fi

  if [[ "$(printf 'HI\n' | timeout 20 "$asc" --trim 2>/dev/null)" == "$out" ]]; then
    pass "asciify reads stdin identically to argv"
  else
    fail "asciify gives different output for stdin and argv"
  fi

  if printf 'AB\n' | timeout 20 "$asc" --char '#' 2>/dev/null \
       | LC_ALL=C grep -q '[^[:print:][:space:]]'; then
    fail "asciify --char '#' still emits multibyte glyphs"
  else
    pass "asciify --char '#' is pure ASCII"
  fi

  # --width is the contract my-computer relies on to decide whether a
  # banner fits: too wide must mean "no output, non-zero", never a
  # wrapped banner.
  if timeout 20 "$asc" --width 10 "TOOWIDE" </dev/null 2>/dev/null | grep -q .; then
    fail "asciify --width printed output that exceeds the limit"
  else
    pass "asciify --width suppresses an oversized render"
  fi

  # Arbitrary input must never crash it — unknown glyphs fall back.
  if timeout 20 "$asc" '~@#$%' </dev/null >/dev/null 2>&1; then
    pass "asciify survives unsupported characters"
  else
    fail "asciify failed on unsupported characters"
  fi

  # --rainbow must colour, must vary between runs, and must never leak a
  # stray variable echo into the art. zsh prints "r=5" when `local r`
  # re-declares a parameter that already holds a value, and that landed
  # in the middle of the banner.
  rb="$(timeout 20 "$asc" --rainbow --trim "AB" </dev/null 2>/dev/null)"
  if printf '%s' "$rb" | grep -q $'\033\[38;5;'; then
    pass "asciify --rainbow emits 256-colour codes"
  else
    fail "asciify --rainbow produced no colour"
  fi
  if printf '%s' "$rb" | grep -qE '^[a-z_]+=' ; then
    fail "asciify leaked a variable assignment into its output"
  else
    pass "asciify emits no stray variable echoes"
  fi
  hues1="$(timeout 20 "$asc" --rainbow "ABCDEFGH" </dev/null 2>/dev/null | grep -o '38;5;[0-9]*' | sort -u | tr -d '\n')"
  hues2="$(timeout 20 "$asc" --rainbow "ABCDEFGH" </dev/null 2>/dev/null | grep -o '38;5;[0-9]*' | sort -u | tr -d '\n')"
  if [[ "$hues1" != "$hues2" ]]; then
    pass "asciify --rainbow re-rolls colours each run"
  else
    fail "asciify --rainbow produced identical colours twice"
  fi
  # Excluded hues are the point: a letter the colour of the background
  # is worse than no colour at all.
  if timeout 20 "$asc" --rainbow --bg dark "ABCDEFGHIJ" </dev/null 2>/dev/null \
       | grep -oE '38;5;(1[6-9]|2[0-9]|3[0-4])\b' | grep -q .; then
    fail "asciify --rainbow used near-black hues on a dark background"
  else
    pass "asciify --rainbow avoids hues close to the background"
  fi
  if [[ -z "$(NO_COLOR=1 timeout 20 "$asc" --rainbow "AB" </dev/null 2>/dev/null | grep -o $'\033')" ]]; then
    pass "asciify --rainbow honours NO_COLOR"
  else
    fail "asciify --rainbow ignored NO_COLOR"
  fi
fi

# The Shell row must name the USER's shell, not this script's
# interpreter. my-computer has a bash shebang, so $BASH_VERSION is
# always set inside it — trusting that reported "bash" to a zsh user.
if [[ -x "$mc" ]] && command -v zsh >/dev/null 2>&1; then
  shellrow="$(zsh -c "'$mc' --no-banner --no-color --width 60 | grep -m1 Shell; :" 2>/dev/null)"
  if [[ "$shellrow" == *zsh* ]]; then
    pass "Shell row reports the calling shell, not the script's interpreter"
  else
    fail "Shell row wrong when invoked from zsh: $(printf '%s' "$shellrow" | tr -s ' ')"
  fi
fi

# Width detection is the basis of the whole layout, and $COLUMNS is NOT
# exported by interactive shells — so a child process must not rely on
# it alone. With COLUMNS unset the report has to find the width some
# other way rather than silently collapsing to the fallback.
if [[ -x "$mc" ]]; then
  if grep -q 'stty size' "$mc" && grep -q 'tput cols' "$mc"; then
    pass "width detection falls back beyond \$COLUMNS"
  else
    fail "width detection relies on \$COLUMNS alone, which children never see"
  fi
fi

# Truncation must not eat a whole field: the identity line drops trailing
# parts instead, and STATUS packs onto more lines.
if [[ -x "$mc" ]]; then
  if timeout 25 "$mc" --no-banner --no-color --width 200 </dev/null 2>/dev/null \
       | grep -qE 'batter…|battery …'; then
    fail "STATUS truncated the battery reading instead of wrapping"
  else
    pass "STATUS wraps rather than truncating"
  fi
fi

# --list exists to be parsed, so the properties that matter are the
# machine-readable ones, not how it looks.
if [[ -x "$mc" ]]; then
  for flag in "-l" "--list"; do
    if timeout 25 "$mc" "$flag" </dev/null >/dev/null 2>&1; then
      pass "my-computer $flag runs"
    else
      fail "my-computer $flag exited non-zero"
    fi
  done

  lout="$(timeout 25 "$mc" --list </dev/null 2>/dev/null)"

  # No frame and no blank lines. The class lists box-drawing glyphs
  # only: '+' and '|' appear in legitimate values such as "+1 more".
  if [[ -n "$lout" ]] && ! printf '%s\n' "$lout" | grep -qE '^[[:space:]]*$|[╭╮╰╯│├┤─]'; then
    pass "--list emits no frame characters or blank lines"
  else
    fail "--list output still contains UI elements or blank lines"
  fi

  # THE parsing contract: key and value separated by 2+ spaces, and
  # neither containing a run of 2+ spaces. A single-space rule would
  # break on mount points, which are keys and can contain spaces.
  if printf '%s\n' "$lout" | grep -qE '^.*[^ ]  +[^ ].*$'; then
    pass "--list separates key and value by 2+ spaces"
  else
    fail "--list has no unambiguous key/value separator"
  fi
  if printf '%s\n' "$lout" | awk -F'  +' 'NF > 2 { bad++ } END { exit !bad }'; then
    fail "--list has a value containing a run of 2+ spaces — splitting is ambiguous"
  else
    pass "--list values contain no ambiguous space runs"
  fi
  # The contract must actually work through the tools it exists for.
  if [[ "$(printf '%s\n' "$lout" | awk -F'  +' '$1=="Kernel"{print $2}')" \
        == "$(uname -r)" ]]; then
    pass "--list round-trips through awk -F'  +'"
  else
    fail "--list did not parse correctly with awk -F'  +'"
  fi

  # Escape codes would land inside values and break cut/awk. This must
  # hold even on a terminal, which is why colour is forced off.
  if command -v script >/dev/null 2>&1; then
    if [[ "$(script -qec "$mc --list" /dev/null 2>/dev/null | grep -c $'\033')" == 0 ]]; then
      pass "--list is escape-free even on a tty"
    else
      fail "--list emitted colour codes on a tty"
    fi
  fi

  # A first field on every line is what makes grep/awk usable.
  bad_lines="$(printf '%s\n' "$lout" | grep -cvE '^[^ ]+ +.+' || true)"
  if [[ "$bad_lines" == 0 ]]; then
    pass "--list every line is key + value"
  else
    fail "--list has $bad_lines malformed line(s)"
  fi

  # Keys must be unique enough to select one: a duplicate key makes
  # `grep '^RAM'` ambiguous.
  dupes="$(printf '%s\n' "$lout" | awk '{print $1}' | sort | uniq -d | tr '\n' ' ')"
  if [[ -z "${dupes// /}" ]]; then
    pass "--list keys are unique"
  else
    fail "--list has duplicate keys: $dupes"
  fi

  # Each value checked against the SHAPE it should have. A key that is
  # present but carrying nonsense is worse than a missing one, because
  # a script will happily consume it — this is what catches a collector
  # that silently starts returning the wrong field.
  #
  #   key : required(1/0) : extended regex the value must match
  check_value() {
    local key=$1 required=$2 want=$3 got
    got="$(printf '%s\n' "$lout" | awk -F'  +' -v k="$key" '$1==k{print $2; exit}')"
    if [[ -z "$got" ]]; then
      if (( required )); then fail "--list is missing the '$key' key"
      else                    pass "--list omits '$key' (not applicable here)"
      fi
      return
    fi
    if printf '%s' "$got" | grep -qE "$want"; then
      pass "--list $key = '$got'"
    else
      fail "--list $key = '$got' does not match /$want/"
    fi
  }

  check_value User      1 '^[^ ]+$'
  check_value Host      1 '^[^ ]+$'
  check_value Arch      1 '^(x86_64|i[36]86|aarch64|armv[67]l|riscv64|ppc64le|s390x)$'
  check_value OS        1 '^.{3,}$'
  check_value Kernel    1 '^[0-9]+\.[0-9]+'
  check_value Uptime    1 '^([0-9]+d )?([0-9]+h )?[0-9]+m$'
  check_value Shell     1 '^(zsh|bash|fish|ksh|mksh|dash|sh|tcsh|csh)( [0-9]|$)'
  check_value Terminal  1 '^[^ ]+$'
  check_value Packages  0 '^[0-9]+ '
  check_value CPU       1 '^.{3,}$'
  check_value Cores     0 '^[0-9]+C · [0-9]+T$'
  check_value Clock     0 '^[0-9]+\.[0-9]( / [0-9]+\.[0-9])? GHz$'
  check_value RAM       1 '^[0-9]{1,3}% [0-9.]+ / [0-9.]+ (KiB|MiB|GiB)$'
  check_value Swap      0 '^[0-9]{1,3}% [0-9.]+ / [0-9.]+ (KiB|MiB|GiB)$'
  check_value /         1 '^[0-9]{1,3}% [0-9.]+ / [0-9.]+ (KiB|MiB|GiB)$'
  check_value IPv4      0 '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  check_value Gateway   0 '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  check_value Signal    0 '^[0-9]{1,3}% · -?[0-9]+ dBm$'
  check_value GSConnect 0 '^.+$'
  check_value Devices   0 '^(0 connected|.+)$'
  check_value load      1 '^[0-9]+\.[0-9]+ [0-9]+\.[0-9]+ [0-9]+\.[0-9]+$'
  check_value procs     1 '^[0-9]+$'
  check_value temp      0 '^[0-9]+(°C|C)$'
  check_value battery   0 '^[0-9]{1,3}%'

  # Default rendering must be untouched by any of this. Matched on the
  # spaced panel title, NOT on a frame glyph: the frame is ASCII in a
  # non-UTF-8 locale, and a bracket expression containing a multibyte
  # character matches individual BYTES under LC_ALL=C, so a glyph-based
  # pattern fails for reasons that have nothing to do with the code.
  # " SYSTEM " appears only in a panel heading.
  #
  # Captured first rather than piped straight into `grep -q`: grep exits
  # the moment it matches, my-computer then dies of SIGPIPE, and with
  # `set -o pipefail` that non-zero status becomes the pipeline's — so
  # the test would report failure precisely when the match SUCCEEDS.
  # The same PIPE_FAIL trap ADR-005 describes for the prompt.
  panel_out="$(timeout 25 "$mc" --no-banner --no-color --width 76 </dev/null 2>/dev/null)"
  if [[ "$panel_out" == *" SYSTEM "* ]]; then
    pass "default mode still renders panels"
  else
    fail "default mode lost its panels"
  fi
fi

# GSConnect must be invisible when it is not installed. A report that
# names software you do not run is noise, and "GSConnect: not installed"
# is the exact line this has to avoid.
if [[ -x "$mc" ]]; then
  gsc_installed=0
  shopt -s nullglob
  gsc_dirs=( "$HOME/.local/share/gnome-shell/extensions/"gsconnect@* \
             /usr/share/gnome-shell/extensions/gsconnect@* )
  shopt -u nullglob
  (( ${#gsc_dirs[@]} )) && gsc_installed=1

  if (( gsc_installed )); then
    if printf '%s\n' "$lout" | grep -qE '^GSConnect  +'; then
      pass "GSConnect is installed and reported"
    else
      fail "GSConnect is installed but absent from --list"
    fi
    # The connected count must always be stated, including when zero.
    if printf '%s\n' "$lout" | grep -qE '^Devices  +'; then
      pass "GSConnect connected devices reported"
    else
      fail "GSConnect reported without a Devices row"
    fi
  else
    pass "GSConnect not installed on this machine — skipping positive checks"
  fi

  # The negative case is the important one, and it is testable
  # regardless: point HOME at an empty directory. This only proves
  # anything when the extension is not installed system-wide too.
  if [[ ! -d /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io ]]; then
    tmp_home="$(mktemp -d)"
    gsc_leak="$(HOME="$tmp_home" timeout 25 "$mc" --list </dev/null 2>/dev/null \
                | grep -ic 'gsconnect' || true)"
    rmdir "$tmp_home" 2>/dev/null || rm -rf "$tmp_home"
    if [[ "$gsc_leak" == 0 ]]; then
      pass "GSConnect is silent when not installed"
    else
      fail "GSConnect mentioned $gsc_leak time(s) despite not being installed"
    fi
  fi
fi

# Speed is a feature here: this runs interactively, on demand. The cost
# is dominated by process creation, because in bash every $(...) forks a
# subshell — building the report through command substitution once cost
# 481 processes and half a second. The guard is on fork COUNT rather
# than wall-clock, which swings with machine load and would make the
# suite flaky.
if [[ -x "$mc" ]] && command -v strace >/dev/null 2>&1; then
  forks="$(strace -f -c -e trace=clone,clone3 "$mc" --width 200 --no-banner </dev/null 2>&1 >/dev/null \
           | awk '/clone/ { n += $4 } END { print n+0 }')"
  if [[ -n "$forks" ]] && (( forks > 0 )) && (( forks <= 150 )); then
    pass "my-computer forks $forks subshells (budget 150)"
  elif (( ${forks:-0} > 150 )); then
    fail "my-computer forks $forks subshells — a \$(...) crept into a render loop"
  else
    pass "fork count not measurable here — skipped"
  fi
fi

# The layout is the feature: it must genuinely reflow, not just survive.
if [[ -x "$mc" ]]; then
  for spec in "50:1" "76:2" "118:3"; do
    wid="${spec%%:*}"; want="${spec#*:}"
    # Count panel top-borders on the busiest row to infer the columns.
    got="$(timeout 25 "$mc" --width "$wid" --no-banner --no-color </dev/null 2>/dev/null \
           | grep -c '^  ╭' || true)"
    rowmax="$(timeout 25 "$mc" --width "$wid" --no-banner --no-color </dev/null 2>/dev/null \
           | grep '╭' | awk '{n=gsub(/╭/,"x"); if (n>m) m=n} END {print m+0}')"
    if [[ "$rowmax" == "$want" ]]; then
      pass "width $wid lays out $want column(s)"
    else
      fail "width $wid produced $rowmax columns, expected $want"
    fi
  done
fi

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
