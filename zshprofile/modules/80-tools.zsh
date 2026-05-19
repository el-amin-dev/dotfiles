# ════════════════════════════════════════════════════════════════════
#  80-tools — external tool init hooks (the ONLY real startup cost)
#  Each eval "$(tool init)" spawns ONE subprocess at launch. We keep
#  the list minimal, guard every tool, and run each exactly once.
#  Loads LATE: tools here may depend on completion/keybindings above.
# ════════════════════════════════════════════════════════════════════

# ── zoxide: smarter cd (learns your most-used dirs) ────────────────
# Replaces 'cd' habit with frecency jumping. 'z proj' → best match.
# --cmd cd makes 'cd' itself smart while keeping plain cd behavior.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd)"
  # Now: 'cd foo' fuzzy-jumps if no literal ./foo; 'cdi' = interactive.
fi

# ── fzf: key-bindings (Ctrl-R / Ctrl-T / Alt-C) + completion ───────
# The OMZ 'fzf' plugin (10-omz) already wires these on Ubuntu's
# apt-installed fzf. We add the official integration too, but ONLY
# if the plugin path didn't already define the widget — avoids
# double-binding and a redundant subprocess.
if (( $+commands[fzf] )); then
  # zsh 5.9+ ships: `fzf --zsh` prints bindings+completion in one shot
  if fzf --zsh &>/dev/null; then
    source <(fzf --zsh)
  else
    # Fallback for older fzf: source Ubuntu's packaged scripts if present
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] \
      && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] \
      && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# ── zsh-autosuggestions runtime tuning ─────────────────────────────
# Plugin is LOADED by OMZ (10-omz). These only tweak behavior — no
# subprocess, no cost. Set AFTER the plugin so they take effect.
if (( $+functions[_zsh_autosuggest_start] )); then
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)   # suggest from both
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'          # dim grey ghost text
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20              # don't suggest on huge input
  ZSH_AUTOSUGGEST_MANUAL_REBIND=1                 # speed: skip auto rebind
fi

# ── eza/bat have no init hook — they're pure binaries ──────────────
# (Their behavior is controlled by aliases in 60 + env vars in 00.
#  Listed here only so the absence is intentional, not forgotten.)

# ── btop / ripgrep / fd / tmux: no shell init needed ───────────────
# These are invoked on demand; nothing to source at startup. Noted
# so this file is a complete map of "what hooks in vs what doesn't".
