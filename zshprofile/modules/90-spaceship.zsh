# ════════════════════════════════════════════════════════════════════
#  90-spaceship — prompt config. LOADS LAST (must come AFTER the theme;
#  Spaceship options only take effect when set after OMZ loaded it).
#
#  SPEED PRINCIPLE (from Spaceship docs): the prompt order ALSO decides
#  which sections load. Sections you omit are never loaded. So we list
#  ONLY your stack: dir, git, node, python, docker, kubectl, aws.
#  Async is on by default → slow git status runs off the main thread.
# ════════════════════════════════════════════════════════════════════

# ── Async on (default, but pinned explicitly for clarity) ──────────
SPACESHIP_PROMPT_ASYNC=true

# ── Two-line prompt, blank line between commands (readable) ────────
SPACESHIP_PROMPT_ADD_NEWLINE=true
SPACESHIP_PROMPT_SEPARATE_LINE=true

# ── LEAN ORDER — the #1 prompt-speed lever. Only your stack. ───────
# Everything not listed (ruby/go/php/rust/java/azure/gcp/terraform/…)
# is NEVER loaded → faster prompt, less clutter.
SPACESHIP_PROMPT_ORDER=(
  dir            # current directory
  git            # branch + dirty status (async)
  node           # Node version — only shows in JS/Svelte projects
  python         # Python version — only shows in FastAPI projects
  docker         # Docker context — only in dirs with Dockerfile
  kubectl        # k8s context — only when kubeconfig active
  aws            # AWS profile — only when AWS_PROFILE set
  venv           # active virtualenv (FastAPI .venv)
  exec_time      # how long the last command took
  line_sep       # ← line break: everything above on line 1
  jobs           # background jobs indicator
  exit_code      # non-zero exit shown explicitly
  char           # the prompt character (➜)
)
# Right side kept empty — less rendering, cleaner.
SPACESHIP_RPROMPT_ORDER=()

# ── Directory: short, fast, repo-aware ─────────────────────────────
SPACESHIP_DIR_TRUNC=3                 # show at most 3 trailing path parts
SPACESHIP_DIR_TRUNC_REPO=true         # inside a repo: show path from repo root
SPACESHIP_DIR_COLOR="cyan"

# ── Git: the section you care about most ───────────────────────────
SPACESHIP_GIT_PREFIX="on "
SPACESHIP_GIT_BRANCH_COLOR="magenta"
SPACESHIP_GIT_STATUS_COLOR="red"
SPACESHIP_GIT_STATUS_PREFIX=" ["
SPACESHIP_GIT_STATUS_SUFFIX="]"
# (git status is async by default — never blocks your typing)

# ── Node / Python / venv: version only in relevant project dirs ────
SPACESHIP_NODE_PREFIX="node "
SPACESHIP_NODE_COLOR="green"
SPACESHIP_PYTHON_PREFIX="py "
SPACESHIP_PYTHON_COLOR="yellow"
SPACESHIP_PYTHON_SYMBOL=""            # drop the symbol, keep it lean
SPACESHIP_VENV_COLOR="blue"
SPACESHIP_VENV_GENERIC_NAMES=(.venv venv env)

# ── Docker / Kubernetes / AWS: context awareness for your workflow ─
SPACESHIP_DOCKER_PREFIX="on "
SPACESHIP_DOCKER_COLOR="blue"
SPACESHIP_DOCKER_SYMBOL="🐳 "
SPACESHIP_KUBECTL_SHOW=true
SPACESHIP_KUBECTL_PREFIX="at "
SPACESHIP_KUBECTL_COLOR="cyan"
SPACESHIP_KUBECTL_VERSION_SHOW=false  # context only, skip version (faster)
SPACESHIP_AWS_PREFIX="using "
SPACESHIP_AWS_COLOR="208"             # AWS orange (256-color code)
SPACESHIP_AWS_SYMBOL="☁ "

# ── Exec time: only flag genuinely slow commands ───────────────────
SPACESHIP_EXEC_TIME_SHOW=true
SPACESHIP_EXEC_TIME_ELAPSED=5         # only show if cmd took >5s
SPACESHIP_EXEC_TIME_COLOR="240"       # dim grey, non-distracting

# ── Exit code: make failures impossible to miss ────────────────────
SPACESHIP_EXIT_CODE_SHOW=true
SPACESHIP_EXIT_CODE_PREFIX="✘ "
SPACESHIP_EXIT_CODE_COLOR="red"

# ── Prompt char: green normally, red after a failed command ────────
SPACESHIP_CHAR_SYMBOL="➜ "
SPACESHIP_CHAR_COLOR_SUCCESS="green"
SPACESHIP_CHAR_COLOR_FAILURE="red"
