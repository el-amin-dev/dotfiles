# ════════════════════════════════════════════════════════════════════
#  90-spaceship — prompt configuration. Loads after the theme itself,
#  which Oh My Zsh sources at module 10 via $ZSH_THEME.
#
#  This is NOT the last module. 95-zoxide.zsh deliberately loads after
#  it, because zoxide registers a chpwd hook and a prompt framework that
#  rebuilds $chpwd_functions would drop it (ADR-004). Anything added
#  here must not assume it runs last.
#
#  LAYOUT — the separator divides the command that JUST RAN from the
#  one about to be typed:
#
#    <output of the previous command>
#    ✘ 1 · took 10.8s          ← FOOTER: describes the command ABOVE it
#    ──────────────────────    full-width dim separator
#    09:47 PM in dotfiles on  main [!?]   ← context for the command BELOW
#    venv:~/projects/api       ← own line, only when a venv is active
#    ➜  <you type here>
#
#  The footer is the point of this layout. An exit code and a duration
#  describe the command that just finished, so printing them below the
#  separator — grouped with the new prompt — reads as though they
#  described the command you are about to type. They belong with its
#  output. See _prompt_footer.
#
#  Every line is CONDITIONAL except the rule and the context line: a
#  fast, successful command prints no footer at all, and no virtualenv
#  means no venv line. Nothing renders as a blank placeholder.
#
#  Sections are chosen on measured cost — see the note above
#  PROMPT_ORDER. git runs async so its ~26 ms never blocks input.
# ════════════════════════════════════════════════════════════════════

# ── Async + multi-line ─────────────────────────────────────────────
SPACESHIP_PROMPT_ASYNC=true
SPACESHIP_PROMPT_SEPARATE_LINE=true
# No leading blank: _prompt_footer already draws the separator directly
# above, and a newline here would push the context line away from the
# rule it belongs to.
SPACESHIP_PROMPT_ADD_NEWLINE=false

# ════════════════════════════════════════════════════════════════════
#  Previous-command footer + separator
#
#  Drawn from precmd, printed directly, rather than as Spaceship
#  sections. That is deliberate and it is what makes the layout clean:
#
#  Spaceship's `line_sep` emits a newline unconditionally. It does NOT
#  collapse when the sections around it render nothing, so building this
#  out of sections leaves a stray blank line on every prompt where the
#  command succeeded quickly — which is most of them. Printing from
#  precmd means "no footer" costs exactly zero lines.
#
#  It also keeps this independent of Spaceship's internals: the elapsed
#  time and exit status are tracked here, not read out of the theme's
#  private variables.
# ════════════════════════════════════════════════════════════════════
zmodload zsh/datetime          # provides $EPOCHREALTIME

typeset -g  _prompt_status=0   # exit status of the last command
typeset -gF _prompt_start=0    # when it started (0 = nothing ran)
typeset -gF _prompt_elapsed=0  # how long it took, seconds

# Human-readable duration: 1.4s / 2m 05s / 1h 03m
_prompt_duration() {
  local -F s=$1
  local -i t=$(( s ))
  if   (( t < 60 ));   then printf '%.1fs' $s
  elif (( t < 3600 )); then printf '%dm %02ds' $(( t / 60 ))   $(( t % 60 ))
  else                      printf '%dh %02dm' $(( t / 3600 )) $(( (t % 3600) / 60 ))
  fi
}

_prompt_preexec() { _prompt_start=$EPOCHREALTIME }

# MUST run before any other precmd hook, or $? is already clobbered by
# whichever hook ran first. Registration order is enforced below.
_prompt_capture() {
  _prompt_status=$?
  if (( _prompt_start > 0 )); then
    _prompt_elapsed=$(( EPOCHREALTIME - _prompt_start ))
    _prompt_start=0
  else
    _prompt_elapsed=0        # fresh prompt, or Enter on an empty line
  fi
  return 0
}

# Footer describing the command that just finished, then the rule.
# Emits the footer line only when there is something worth saying.
_prompt_footer() {
  local -a bits
  # Failure first — it is the thing you need to notice.
  (( _prompt_status != 0 )) \
    && bits+=( "%B%F{white}✘ ${_prompt_status}%f%b%F{240}" )
  (( _prompt_elapsed >= ${SPACESHIP_EXEC_TIME_ELAPSED:-5} )) \
    && bits+=( "took $(_prompt_duration $_prompt_elapsed)" )

  (( ${#bits} )) && print -rP -- "%F{240}${(j: · :)bits}%f"

  # Full-width rule, re-measured every prompt so it tracks resizes.
  # The width must be resolved into a plain integer BEFORE the (l:...)
  # pad expansion — zsh rejects a nested ${..} in the length position.
  #
  # `${COLUMNS:-80}` alone is not enough: :- substitutes only when the
  # variable is unset or empty, and COLUMNS is 0 whenever there is no
  # tty (a piped or captured shell). A width of 0 renders an EMPTY rule
  # rather than falling back, so the floor is checked explicitly.
  local -i w=${COLUMNS:-80}
  (( w < 20 )) && w=80
  print -rP -- "%F{240}${(l:$w::─:)}%f"
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _prompt_preexec
add-zsh-hook precmd  _prompt_capture
add-zsh-hook precmd  _prompt_footer
# Force _prompt_capture to the front: Oh My Zsh and Spaceship registered
# their own precmd hooks back at module 10, and any of them running
# first would reset $? before it is read.
precmd_functions=( _prompt_capture ${precmd_functions:#_prompt_capture} )

# ── Custom section: yellow venv path, from ~, no /.venv suffix ─────
# Emits ONLY when a virtualenv is active ($VIRTUAL_ENV set).
# Strips a trailing /.venv (or /venv, /env) and rewrites $HOME → ~, so
# the line names the PROJECT rather than repeating ".venv" every time.
#
# This is also why spaceship's own `python` section is switched off: the
# interpreter version costs ~48 ms a prompt, while the thing actually
# worth knowing — which environment is active — is free to compute here.
spaceship_venvpath() {
  [[ -n "$VIRTUAL_ENV" ]] || return
  local p="${VIRTUAL_ENV}"
  p="${p%/.venv}"; p="${p%/venv}"; p="${p%/env}"
  p="${p/#$HOME/~}"
  # Leading newline is part of the content, so this section brings its
  # own line only when it has something to show. See PROMPT_ORDER.
  spaceship::section --color yellow $'\n'"venv:${p}"
}

# ── Prompt order (the layout) ──────────────────────────────────────
#
# The separator, exec_time and exit_code are NOT here — they belong to
# the previous command and are printed by _prompt_footer above.
#
# There is exactly one `line_sep`. An unconditional break around
# venvpath would leave a blank line on every prompt without a
# virtualenv, so venvpath supplies its own leading newline instead and
# simply renders nothing when inactive.
# Reads as a sentence:  <time>  in <dir>  on <branch>  <infra>
#
# ── The speed trade-off, measured, not guessed ─────────────────────
# Spaceship sections are NOT free when they have nothing to show. Each
# one still searches the directory tree and usually spawns a process
# just to decide it should stay silent. Measured per prompt in an
# ORDINARY directory — no manifests, nothing to display:
#
#     package  270 ms      golang    80 ms      docker  75 ms
#     python    49 ms      node      48 ms      battery 37 ms
#     git       26 ms      rust      15 ms
#     kubectl  1.7 ms      dir      1.7 ms      aws    0.1 ms
#
# Enabling the lot costs ~600 ms of work on EVERY prompt, in every
# directory, to render nothing. Async hides the latency but still burns
# the CPU and spawns the processes.
#
# So: keep what is free or essential, drop what is expensive and
# marginal. Everything kept below totals ~30 ms, and git — the only
# real cost left — is genuinely worth it and runs async.
#
# Deliberately NOT enabled, with the reason:
#   package   270 ms to show a version number nobody reads at a glance
#   golang    not part of this stack
#   rust      not part of this stack
#   node       48 ms for a version; the branch and directory matter more
#   python     48 ms for a version — and `venvpath` below already shows
#              the ACTIVE VIRTUALENV, which is the part that matters,
#              for free
#   docker     75 ms, and it queries the daemon: when dockerd is down or
#              slow this blocks the prompt outright
#   battery    the desktop already has an indicator
# Re-enable any of them by adding the name here and flipping its
# *_SHOW below, knowing the price.
SPACESHIP_PROMPT_ORDER=(
  time           # ~0 ms  timestamp (12hr, seconds) — starts the line
  user           # ~0 ms  only over SSH — who you are on a remote box
  host           # ~0 ms  only over SSH — which box
  dir            #  2 ms  current directory
  git            # 26 ms  branch + working-tree status (async)
  kubectl        #  2 ms  only when a kube context is active
  aws            # ~0 ms  reads $AWS_PROFILE — no process spawned
  venvpath       # ~0 ms  own line, yellow — NOTHING when no venv
  line_sep       # ── the only break: → the input line ──
  jobs           # ~0 ms  background jobs indicator
  char           #        the ➜ prompt character
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
# TRUNC_REPO keeps the path anchored at the repo root rather than
# showing three arbitrary components from /, so the location reads
# relative to the project you are actually in.
SPACESHIP_DIR_PREFIX="in "
SPACESHIP_DIR_TRUNC=3
SPACESHIP_DIR_TRUNC_REPO=true
SPACESHIP_DIR_COLOR="cyan"

# ── Git ────────────────────────────────────────────────────────────
# Every status flag is enabled and given a distinct symbol, so the
# bracket reads as a compact summary of the working tree at a glance.
# Grouped deliberately: what is committed-and-unpushed, then what is
# staged, then what is not.
SPACESHIP_GIT_SHOW=true
SPACESHIP_GIT_PREFIX="on "
SPACESHIP_GIT_BRANCH_SHOW=true
SPACESHIP_GIT_BRANCH_COLOR="magenta"

SPACESHIP_GIT_STATUS_SHOW=true
SPACESHIP_GIT_STATUS_COLOR="red"
SPACESHIP_GIT_STATUS_PREFIX=" ["
SPACESHIP_GIT_STATUS_SUFFIX="]"

SPACESHIP_GIT_STATUS_AHEAD="⇡"        # local commits not pushed
SPACESHIP_GIT_STATUS_BEHIND="⇣"       # remote commits not pulled
SPACESHIP_GIT_STATUS_DIVERGED="⇕"     # both — history has forked
SPACESHIP_GIT_STATUS_STASHED="≡"      # something is stashed
SPACESHIP_GIT_STATUS_ADDED="+"        # staged, new file
SPACESHIP_GIT_STATUS_MODIFIED="!"     # tracked file changed
SPACESHIP_GIT_STATUS_RENAMED="»"      # staged, renamed
SPACESHIP_GIT_STATUS_DELETED="✘"      # staged, deleted
SPACESHIP_GIT_STATUS_UNTRACKED="?"    # not tracked at all
SPACESHIP_GIT_STATUS_UNMERGED="═"     # conflict, needs resolving

SPACESHIP_PYTHON_PREFIX="py "
SPACESHIP_PYTHON_COLOR="yellow"
SPACESHIP_PYTHON_SYMBOL=""

# ── Runtime versions: OFF, on cost grounds ─────────────────────────
# Each of these spends 15–270 ms per prompt, in every directory, mostly
# to decide it has nothing to show. See the note above PROMPT_ORDER for
# the measurements. Config kept so re-enabling is a one-word change.
SPACESHIP_NODE_SHOW=false
SPACESHIP_NODE_PREFIX="via "
SPACESHIP_NODE_COLOR="green"
SPACESHIP_NODE_SYMBOL=""
SPACESHIP_GOLANG_SHOW=false
SPACESHIP_GOLANG_PREFIX="via "
SPACESHIP_GOLANG_COLOR="cyan"
SPACESHIP_GOLANG_SYMBOL=""
SPACESHIP_RUST_SHOW=false
SPACESHIP_RUST_PREFIX="via "
SPACESHIP_RUST_COLOR="red"
SPACESHIP_RUST_SYMBOL=""
SPACESHIP_PYTHON_SHOW=false     # venvpath covers the useful half, free

# ── Project version: OFF — 270 ms, the single most expensive ───────
SPACESHIP_PACKAGE_SHOW=false

# ── Docker: OFF — 75 ms, and it queries the daemon ─────────────────
# When dockerd is stopped or slow, that query blocks the prompt itself.
# A shell that hangs because Docker is down is not a trade worth making.
SPACESHIP_DOCKER_SHOW=false
SPACESHIP_DOCKER_PREFIX="on "
SPACESHIP_DOCKER_COLOR="blue"
SPACESHIP_DOCKER_SYMBOL="🐳 "

# ── Infrastructure that IS nearly free ─────────────────────────────
# kubectl reads a config file (~2 ms); aws just reads $AWS_PROFILE.
# Both are exactly what you want visible before running something
# against the wrong cluster or account.
SPACESHIP_KUBECTL_SHOW=true
SPACESHIP_KUBECTL_PREFIX="at "
SPACESHIP_KUBECTL_COLOR="cyan"
SPACESHIP_KUBECTL_SYMBOL="☸ "
SPACESHIP_KUBECTL_VERSION_SHOW=false
SPACESHIP_AWS_SHOW=true
SPACESHIP_AWS_PREFIX="using "
SPACESHIP_AWS_COLOR="208"
SPACESHIP_AWS_SYMBOL="☁ "

# ── Identity: only when it is NOT obvious, i.e. over SSH ───────────
# Locally this is noise; on a remote box it is the thing you most want
# to be sure of before running something destructive.
SPACESHIP_USER_SHOW=needed
SPACESHIP_USER_COLOR="yellow"
SPACESHIP_HOST_SHOW=needed
SPACESHIP_HOST_PREFIX="at "
SPACESHIP_HOST_COLOR="green"

# ── Battery: silent unless it actually needs attention ─────────────
# `true` = only below the threshold or while charging. `charged` would
# show it permanently, which is exactly the noise this avoids.
SPACESHIP_BATTERY_SHOW=false
SPACESHIP_BATTERY_THRESHOLD=25

# ── Background jobs ────────────────────────────────────────────────
SPACESHIP_JOBS_SHOW=true
SPACESHIP_JOBS_COLOR="blue"
SPACESHIP_JOBS_SYMBOL="✦ "

# ── Exec time / exit code: rendered by _prompt_footer, not by ────────
# ── Spaceship, so both sections are switched off here. ───────────────
# $SPACESHIP_EXEC_TIME_ELAPSED is still read by the footer as the
# threshold below which a duration is not worth reporting.
SPACESHIP_EXEC_TIME_SHOW=false
SPACESHIP_EXEC_TIME_ELAPSED=5
SPACESHIP_EXIT_CODE_SHOW=false
# Leaving these on also produced a double cross — "✘ ✘1" — because the
# prefix below carried a ✘ of its own on top of Spaceship's symbol.

# ── Prompt char: green ok / white on failure (calm) ────────────────
SPACESHIP_CHAR_SYMBOL="➜ "
SPACESHIP_CHAR_COLOR_SUCCESS="green"
SPACESHIP_CHAR_COLOR_FAILURE="white"
