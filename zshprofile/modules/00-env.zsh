# ════════════════════════════════════════════════════════════════════
#  00-env — environment variables, repo-local paths, PATH.
#  Loads FIRST: every other module may depend on what is set here.
# ════════════════════════════════════════════════════════════════════

# ── Anchor: the profile directory ──────────────────────────────────
# $ZSH_PROFILE_DIR is exported by the root .zshrc. Every path below is
# derived from it, which is what keeps the config portable and stops
# anything from scattering into $HOME.

# ── Oh My Zsh lives INSIDE the repo, not in ~/.oh-my-zsh ───────────
export ZSH="$ZSH_PROFILE_DIR/external/oh-my-zsh"

# ── Self-cloned plugins ────────────────────────────────────────────
export ZSH_CUSTOM_PLUGINS="$ZSH_PROFILE_DIR/external/plugins"

# ── Keep zsh runtime state in the repo's cache/ (git-ignored) ──────
export ZSH_CACHE_DIR="$ZSH_PROFILE_DIR/cache"
export HISTFILE="$ZSH_CACHE_DIR/zsh_history"
# The completion dump goes here too — see 40-completion.zsh.

# ── Resolve real binary names for renamed tools ────────────────────
# Debian and Ubuntu ship fd as `fdfind` and bat as `batcat`. The
# aliases in 60-aliases.zsh cover typing those names interactively, but
# aliases are a shell-level convenience and do NOT exist for anything
# executed outside this shell — and several things here are:
#
#   • $FZF_DEFAULT_COMMAND / $FZF_ALT_C_COMMAND — fzf runs these itself
#   • fzf --preview strings                     — run via `sh -c`
#   • $MANPAGER                                 — run via `sh -c`
#
# Every one of those silently degraded when it referenced `fd` or `bat`
# on a Debian-family machine: fzf fell back to its slower built-in
# directory walker, and the file previews in the fzf pickers rendered
# empty. Resolving the real binary name once, here, is what makes those
# integrations work on every distro.
#
# Both are exported so subshells and preview commands can use them.
export ZSH_FD_BIN=""
export ZSH_BAT_BIN=""
() {
  local b
  for b in fd fdfind;   do (( $+commands[$b] )) && { ZSH_FD_BIN="$b";  break }; done
  for b in bat batcat;  do (( $+commands[$b] )) && { ZSH_BAT_BIN="$b"; break }; done
}

# ── Default tools ──────────────────────────────────────────────────
export EDITOR="vim"
export VISUAL="vim"
export PAGER="less"

# less: raw colour sequences through, smart-case search, verbose prompt.
export LESS='-R -i -M'

# ── AWS CLI: never open a pager for command output ─────────────────
# The AWS CLI v2 pipes everything through a pager by default, which
# turns a one-line `aws sts get-caller-identity` into a full-screen
# interaction. Empty value = print straight to stdout.
export AWS_PAGER=""

# ── bat: the in-repo config file is the single source of truth ─────
# All bat behaviour (plain style, no pager, theme, syntax mappings)
# lives in config/bat.conf. Exporting BAT_CONFIG_PATH means every bat
# invocation obeys it — direct calls and the previews inside the fzf
# pickers alike. One config, consistent everywhere, and $HOME stays
# clean because the file lives in the repo.
export BAT_CONFIG_PATH="$ZSH_PROFILE_DIR/config/bat.conf"

# ── man pages rendered through bat ─────────────────────────────────
# Two things matter here and both were bugs worth documenting:
#
#  1. MANPAGER is executed by `sh`, NOT by this interactive zsh, so it
#     cannot use the `bat` alias from 60-aliases.zsh. On Debian and
#     Ubuntu the binary is `batcat`, so a hardcoded `bat` would leave
#     `man` broken. The real binary name is resolved here instead.
#
#  2. config/bat.conf sets --paging=never, which is right for viewing a
#     file but wrong for a man page — it would dump the whole page and
#     leave nothing to scroll. --paging=always is forced back on.
if [[ -n "$ZSH_BAT_BIN" ]]; then
  export MANPAGER="sh -c 'col -bx | $ZSH_BAT_BIN --language=man --style=plain --paging=always'"
  export MANROFFOPT="-c"
fi
# No bat installed → man keeps its own pager, untouched.

# ── fzf defaults ───────────────────────────────────────────────────
# fd is the file source when available: it is fast and it respects
# .gitignore. $ZSH_FD_BIN (not the bare name) is required here because
# fzf executes these commands itself, without this shell's aliases.
if [[ -n "$ZSH_FD_BIN" ]]; then
  export FZF_DEFAULT_COMMAND="$ZSH_FD_BIN --type f --hidden --follow --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="$ZSH_FD_BIN --type d --hidden --follow --exclude .git"
fi
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --info=inline'

# ── Locale ─────────────────────────────────────────────────────────
# Only provide a UTF-8 default when the system has not set one. This
# config is used on other people's machines: forcing en_US would
# silently change their date, number and sort formats.
#
# LC_ALL is deliberately NOT set. It overrides every other LC_* value
# unconditionally and breaks on any machine where the named locale has
# not been generated. LANG is the correct, overridable lever.
if [[ -z "${LANG:-}" ]]; then
  export LANG="en_US.UTF-8"
fi

# ── PATH: prepend user-local bin directories ───────────────────────
# `typeset -U path` keeps the array unique, so re-sourcing this file
# (or `exec zsh`) can never stack up duplicate entries. Always extend
# the `path` array rather than assigning to PATH directly, or that
# de-duplication is bypassed.
typeset -U path
path=(
  "$HOME/.local/bin"      # pipx, user-level pip installs
  "$HOME/bin"             # personal scripts
  $path                   # system defaults, kept last
)
export PATH
