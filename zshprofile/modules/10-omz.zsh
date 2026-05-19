# ════════════════════════════════════════════════════════════════════
#  10-omz — Oh My Zsh bootstrap + Spaceship theme + plugin list
#  Depends on: 00-env ($ZSH, $ZSH_CUSTOM_PLUGINS must be set)
# ════════════════════════════════════════════════════════════════════

# ── Guard: if OMZ isn't cloned yet, warn and skip (don't crash) ────
if [[ ! -d "$ZSH" ]]; then
  print -P "%F{yellow}⚠ Oh My Zsh not found at \$ZSH. Run install.sh.%f"
  return
fi

# ── ZSH_CUSTOM must point at OMZ's REAL custom dir ─────────────────
# install.sh clones Spaceship into  $ZSH/custom/themes/spaceship-prompt
# and symlinks  $ZSH/custom/themes/spaceship.zsh-theme.
# OMZ resolves themes from  $ZSH_CUSTOM/themes/  — so ZSH_CUSTOM MUST
# be $ZSH/custom (NOT external/). This line is the theme-not-found fix.
ZSH_CUSTOM="$ZSH/custom"

# ── Self-heal: link our cloned plugins into $ZSH_CUSTOM/plugins ────
# Our plugins live in external/plugins (git-ignored, cloned by
# install.sh). OMZ looks for custom plugins in $ZSH_CUSTOM/plugins.
# We symlink them in once (idempotent: -sfn, skipped if already
# correct). Near-zero cost, and makes a fresh clone "just work"
# without editing install.sh.
() {
  local src dst name
  for src in "$ZSH_CUSTOM_PLUGINS"/*(N/); do
    name="${src:t}"
    dst="$ZSH_CUSTOM/plugins/$name"
    [[ -L "$dst" && "$dst:A" == "$src:A" ]] && continue
    ln -sfn "$src" "$dst"
  done
}

# ── Theme: Spaceship ───────────────────────────────────────────────
ZSH_THEME="spaceship"

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
