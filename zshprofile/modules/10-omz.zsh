# ════════════════════════════════════════════════════════════════════
#  10-omz — Oh My Zsh bootstrap + Spaceship theme + plugin list
#  Depends on: 00-env ($ZSH, $ZSH_CUSTOM_PLUGINS must be set)
# ════════════════════════════════════════════════════════════════════

# ── Guard: if OMZ isn't cloned yet, warn and skip (don't crash) ────
if [[ ! -d "$ZSH" ]]; then
  print -P "%F{yellow}⚠ Oh My Zsh not found at \$ZSH. Run install.sh.%f"
  return
fi

# ── Theme: Spaceship ───────────────────────────────────────────────
# Spaceship is cloned by install.sh into OMZ's custom/themes dir.
ZSH_THEME="spaceship"

# ── Tell OMZ where our self-cloned plugins live ────────────────────
# OMZ looks in $ZSH_CUSTOM/plugins. We point ZSH_CUSTOM at our repo's
# external/ so autosuggestions + syntax-highlighting are found.
ZSH_CUSTOM="$ZSH_PROFILE_DIR/external"

# ── Behavior tweaks ────────────────────────────────────────────────
zstyle ':omz:update' mode disabled      # we manage updates via git/install.sh
DISABLE_MAGIC_FUNCTIONS="true"          # avoid paste slowdowns / URL mangling
DISABLE_UNTRACKED_FILES_DIRTY="true"    # faster git status in huge repos
COMPLETION_WAITING_DOTS="true"          # visual feedback on slow completions

# ── Plugin list ────────────────────────────────────────────────────
# Order matters for two: autosuggestions before syntax-highlighting,
# and syntax-highlighting should be LAST (it wraps the ZLE widgets).
plugins=(
  git                       # tons of git aliases + branch helpers
  docker                    # docker completion + aliases
  docker-compose            # compose completion
  kubectl                   # k8s completion + 'k' alias base
  aws                       # awscli completion (you use AWS only)
  gh                        # GitHub CLI completion
  fzf                       # fzf keybindings + completion
  command-not-found         # suggests apt package for missing cmd
  colored-man-pages         # color man pages (pairs with bat MANPAGER)
  extract                   # 'extract' any archive type
  zsh-autosuggestions       # fish-style history suggestions  (cloned)
  zsh-syntax-highlighting   # command syntax coloring — MUST be last (cloned)
)

# ── Load Oh My Zsh ─────────────────────────────────────────────────
source "$ZSH/oh-my-zsh.sh"
