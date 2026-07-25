# ════════════════════════════════════════════════════════════════════
#  90-spaceship — prompt configuration. Loads after the theme itself,
#  which Oh My Zsh sources at module 10 via $ZSH_THEME.
#
#  This is NOT the last module. 95-zoxide.zsh deliberately loads after
#  it, because zoxide registers a chpwd hook and a prompt framework that
#  rebuilds $chpwd_functions would drop it (ADR-004). Anything added
#  here must not assume it runs last.
#
#  LAYOUT (four lines; line 3 is conditional):
#    line 1 (always)    : ──────── full-width dim separator
#    line 2 (always)    : TIME  dir  git  python  exec_time
#    line 3 (venv only) : venv:<path-from-~>  (yellow; absent if no venv)
#    line 4 (always)    : exit_code(bold white)  ➜
#
#  docker / kubectl / aws kept in ORDER but hidden via *_SHOW=false
#  (flip to true to re-enable). Async on → git status off main thread.
# ════════════════════════════════════════════════════════════════════

# ── Async + multi-line ─────────────────────────────────────────────
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_PROMPT_SEPARATE_LINE=true

# ── Custom section: full-width separator (line 1) ──────────────────
# Spaceship has no "horizontal rule" section, so we define one.
# Repeats ─ across the FULL terminal width ($COLUMNS), edge to edge,
# re-adjusting automatically when you resize. Dim grey (color 240).
#
# NOTE: the width MUST be resolved into a plain variable BEFORE the
# (l:...) left-pad expansion — zsh rejects a nested ${..} inside the
# pad-length position ("bad substitution"). That was the earlier bug.
spaceship_sepline() {
  local -i w=${COLUMNS:-80}            # resolve width first (plain int)
  local line="${(l:$w::─:)}"          # now pad: repeat ─ exactly w times
  spaceship::section --color 240 "$line"
}

# ── Custom section: yellow venv path, from ~, no /.venv suffix ─────
# Emits ONLY when a virtualenv is active ($VIRTUAL_ENV set).
# Strips trailing /.venv (or /venv, /env) and rewrites $HOME → ~.
# When no venv: prints nothing → surrounding line_sep collapses,
# so that line disappears entirely (no empty line).
spaceship_venvpath() {
  [[ -n "$VIRTUAL_ENV" ]] || return
  local p="${VIRTUAL_ENV}"
  p="${p%/.venv}"; p="${p%/venv}"; p="${p%/env}"
  p="${p/#$HOME/~}"
  spaceship::section --color yellow "venv:${p}"
}

# ── Prompt order (the layout) ──────────────────────────────────────
SPACESHIP_PROMPT_ORDER=(
  sepline        # line 1: ──────── full-width separator
  line_sep       # ── break → end of line 1 ──
  time           # line 2: timestamp (12hr, seconds) — START of line
  dir            # line 2: current directory
  git            # line 2: branch + status (async)
  python         # line 2: Python version (Python projects only)
  docker         # (hidden — SHOW=false below; kept for easy re-enable)
  kubectl        # (hidden — SHOW=false below)
  aws            # (hidden — SHOW=false below)
  exec_time      # line 2: duration, only if last cmd > 5s
  line_sep       # ── break → end of line 2 ──
  venvpath       # line 3: yellow venv path; NOTHING if no venv
  line_sep       # ── break → end of line 3 (collapses if venvpath empty)
  jobs           # line 4: background jobs indicator
  exit_code      # line 4: last exit code (bold white)
  char           # line 4: the ➜ prompt character
)
SPACESHIP_RPROMPT_ORDER=()

# ── Time: 12-hour, with seconds, at the very start of line 2 ───────
SPACESHIP_TIME_SHOW=true
SPACESHIP_TIME_12HR=true              # 12-hour clock (AM/PM)
SPACESHIP_TIME_FORMAT='%D{%I:%M:%S %p}'   # e.g. 02:32:05 PM
SPACESHIP_TIME_COLOR="244"           # soft grey — present, not loud
SPACESHIP_TIME_PREFIX=""             # nothing before it (it's first)
SPACESHIP_TIME_SUFFIX=" "            # single space before dir

# ── Directory ──────────────────────────────────────────────────────
SPACESHIP_DIR_TRUNC=3
SPACESHIP_DIR_TRUNC_REPO=true
SPACESHIP_DIR_COLOR="cyan"

# ── Git ────────────────────────────────────────────────────────────
SPACESHIP_GIT_PREFIX="on "
SPACESHIP_GIT_BRANCH_COLOR="magenta"
SPACESHIP_GIT_STATUS_COLOR="red"
SPACESHIP_GIT_STATUS_PREFIX=" ["
SPACESHIP_GIT_STATUS_SUFFIX="]"

# ── Python version (kept — shows in Python projects) ───────────────
SPACESHIP_PYTHON_SHOW=true
SPACESHIP_PYTHON_PREFIX="py "
SPACESHIP_PYTHON_COLOR="yellow"
SPACESHIP_PYTHON_SYMBOL=""

# ── Docker / Kubernetes / AWS: HIDDEN (flip SHOW→true to re-enable) ─
SPACESHIP_DOCKER_SHOW=false
SPACESHIP_DOCKER_PREFIX="on "
SPACESHIP_DOCKER_COLOR="blue"
SPACESHIP_DOCKER_SYMBOL="🐳 "
SPACESHIP_KUBECTL_SHOW=false
SPACESHIP_KUBECTL_PREFIX="at "
SPACESHIP_KUBECTL_COLOR="cyan"
SPACESHIP_KUBECTL_VERSION_SHOW=false
SPACESHIP_AWS_SHOW=false
SPACESHIP_AWS_PREFIX="using "
SPACESHIP_AWS_COLOR="208"
SPACESHIP_AWS_SYMBOL="☁ "

# ── Exec time: only flag genuinely slow commands (>5s) ─────────────
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_ELAPSED=5
SPACESHIP_EXEC_TIME_COLOR="240"

# ── Exit code: shown on failure, BOLD WHITE (calm, not red) ────────
SPACESHIP_EXIT_CODE_SHOW=true
SPACESHIP_EXIT_CODE_PREFIX="%B%F{white}✘ "
SPACESHIP_EXIT_CODE_SUFFIX="%f%b "
SPACESHIP_EXIT_CODE_COLOR="white"

# ── Prompt char: green ok / white on failure (calm) ────────────────
SPACESHIP_CHAR_SYMBOL="➜ "
SPACESHIP_CHAR_COLOR_SUCCESS="green"
SPACESHIP_CHAR_COLOR_FAILURE="white"
