# ════════════════════════════════════════════════════════════════════
#  50-keybindings — how your keyboard interacts with the line
#  Loads AFTER OMZ so our binds override plugin defaults.
#  Zero startup cost: bindkey is pure in-memory registration.
# ════════════════════════════════════════════════════════════════════

# ── Editing mode: emacs (predictable, works everywhere) ────────────
# Even vim users usually keep the COMMAND LINE in emacs mode — Ctrl-A/E
# muscle memory is universal. Vim is still your $EDITOR for real files.
bindkey -e

# ── History search bound to ↑ / ↓ — type a prefix, arrow filters ──
# 'ls<Up>' cycles only past commands starting with 'ls'. Huge recall win.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search     # Up arrow
bindkey '^[[B' down-line-or-beginning-search   # Down arrow
bindkey '^P'   up-line-or-beginning-search     # Ctrl-P (same, ergonomic)
bindkey '^N'   down-line-or-beginning-search   # Ctrl-N

# ── Word-wise movement (Ctrl/Alt + ←/→) ────────────────────────────
bindkey '^[[1;5C' forward-word                 # Ctrl-Right
bindkey '^[[1;5D' backward-word                 # Ctrl-Left
bindkey '^[[1;3C' forward-word                 # Alt-Right (terminal-dependent)
bindkey '^[[1;3D' backward-word                 # Alt-Left

# ── Home / End / Delete (fix across terminals) ─────────────────────
bindkey '^[[H'  beginning-of-line               # Home
bindkey '^[[F'  end-of-line                     # End
bindkey '^[[1~' beginning-of-line               # Home (alt seq)
bindkey '^[[4~' end-of-line                     # End  (alt seq)
bindkey '^[[3~' delete-char                     # Delete

# ── Edit the current command line in $EDITOR (vim) ─────────────────
# Press Ctrl-X Ctrl-E → opens the line in vim, save+quit runs it.
# Lifesaver for long/multiline commands.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ── Smarter line killing ───────────────────────────────────────────
bindkey '^U' backward-kill-line                 # Ctrl-U: kill to line start
                                                # (not whole line — saner)

# ── Accept autosuggestion ──────────────────────────────────────────
# zsh-autosuggestions uses → / End by default; add Ctrl-Space as a
# dedicated, conflict-free "accept the ghost text" key.
bindkey '^ ' autosuggest-accept

# ── fzf history widget (Ctrl-R) ────────────────────────────────────
# The fzf OMZ plugin already binds Ctrl-R → fuzzy history. We leave it.
# Documented here so you know Ctrl-R is fzf, not the zsh default.
