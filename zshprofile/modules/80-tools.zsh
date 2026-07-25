# ════════════════════════════════════════════════════════════════════
#  80-tools — external tool integration.
#
#  This is where the only real startup cost lives: each `eval "$(tool
#  init)"` spawns a subprocess. The list is kept minimal, every tool is
#  guarded, and each one is initialised exactly once.
#
#  zoxide is NOT here — it must be the very last thing the shell loads.
#  See modules/95-zoxide.zsh for why.
# ════════════════════════════════════════════════════════════════════

# ── fzf: key bindings (Ctrl-R / Ctrl-T / Alt-C) + completion ───────
# The Oh My Zsh `fzf` plugin (10-omz.zsh) already wires these up when
# fzf was installed from a distro package. Sourcing the official
# integration on top of that would re-bind every widget and spawn a
# redundant subprocess, so it is only done when the plugin path did NOT
# already register fzf's history widget.
#
# `fzf-history-widget` is the canonical function name defined by fzf's
# own key-bindings script, which makes it a reliable "already loaded"
# probe. This check is what the module header used to only claim.
if (( $+commands[fzf] )) && (( ! $+functions[fzf-history-widget] )); then
  if fzf --zsh >/dev/null 2>&1; then
    # fzf 0.48+ prints bindings and completion together.
    source <(fzf --zsh)
  else
    # Older fzf: source the distro-packaged scripts if they exist.
    [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] \
      && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -r /usr/share/doc/fzf/examples/completion.zsh ]] \
      && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ── zsh-autosuggestions runtime tuning ─────────────────────────────
# The plugin itself is loaded by Oh My Zsh (10-omz.zsh). These are
# variable assignments only — no subprocess, no measurable cost — and
# they must come AFTER the plugin to take effect.
if (( $+functions[_zsh_autosuggest_start] )); then
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)   # suggest from both sources
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'          # dim grey suggestion text
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20              # skip suggesting on long input
  ZSH_AUTOSUGGEST_MANUAL_REBIND=1                 # faster: no automatic rebinding
fi

# ── Tools that need no shell integration ───────────────────────────
# eza, bat, ripgrep, fd, btop and tmux are plain binaries: their
# behaviour comes from the aliases in 60-aliases.zsh and the
# environment in 00-env.zsh. Listed here so their absence from this
# file reads as intentional rather than forgotten.
