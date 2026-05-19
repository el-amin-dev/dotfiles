# ════════════════════════════════════════════════════════════════════
#  00-env — environment variables, PATH, XDG, repo-local paths
#  Loads FIRST. Everything else may depend on these.
# ════════════════════════════════════════════════════════════════════

# ── Anchor: the profile dir (exported by root .zshrc) ──────────────
# $ZSH_PROFILE_DIR is already set. We build everything off it so the
# config is 100% portable and nothing scatters into $HOME.

# ── Oh My Zsh lives INSIDE the repo, not in ~/.oh-my-zsh ────────────
export ZSH="$ZSH_PROFILE_DIR/external/oh-my-zsh"

# ── Plugins we clone ourselves live here ───────────────────────────
export ZSH_CUSTOM_PLUGINS="$ZSH_PROFILE_DIR/external/plugins"

# ── Keep zsh runtime junk in the repo's cache/ (git-ignored) ───────
export ZSH_CACHE_DIR="$ZSH_PROFILE_DIR/cache"
export HISTFILE="$ZSH_CACHE_DIR/zsh_history"
# zcompdump (completion cache) also goes to cache/ — see 40-completion

# ── Default tools ──────────────────────────────────────────────────
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"

# ── bat: single source of truth is the in-repo config file ─────────
# All bat behavior (no-pager default, git change gutter, style, theme)
# lives in $ZSH_PROFILE_DIR/config/bat.conf. Pointing BAT_CONFIG_PATH
# here means EVERY bat call obeys it: the `cat` alias, `catt`, and the
# bat previews inside the fzf functions (fe / fco / fcd). One config,
# consistent everywhere, portable, $HOME stays clean.
export BAT_CONFIG_PATH="$ZSH_PROFILE_DIR/config/bat.conf"

# ── man pages rendered through bat (colorized man) ─────────────────
# bat.conf handles paging/style; here we only route man → bat.
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# ── fzf: use fd + nice defaults ────────────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# ── Locale (silence perl/locale warnings, consistent sorting) ──────
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ── PATH: prepend user-local bins. Earlier = higher priority. ──────
# Guard each addition so re-sourcing .zshrc never duplicates entries.
typeset -U path   # zsh: keep $path array unique automatically
path=(
  "$HOME/.local/bin"      # pipx, user pip installs
  "$HOME/bin"             # personal scripts
  $path                   # system defaults, kept last
)
export PATH
