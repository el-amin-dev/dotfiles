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
# Order matters for two entries: autosuggestions must come before
# syntax-highlighting, and syntax-highlighting must be LAST because it
# wraps the ZLE widgets every other plugin has already registered.
plugins=(
  git                       # git aliases + branch helpers
  sudo                      # press Esc twice to prefix the line with sudo
  docker                    # docker completion + aliases
  docker-compose            # compose completion
  kubectl                   # kubectl completion
  aws                       # AWS CLI completion + profile helpers
  gh                        # GitHub CLI completion
  fzf                       # fzf keybindings + completion
  command-not-found         # suggest the package providing a missing command
  extract                   # `extract` handles any archive format
  zsh-autosuggestions       # history-based inline suggestions  (cloned)
  zsh-syntax-highlighting   # command syntax colouring — MUST be last (cloned)
)

# ── Deliberately NOT loaded ────────────────────────────────────────
#   colored-man-pages   Redundant here, and not free. It exports a set
#                       of LESS_TERMCAP_* variables and wraps `man` in a
#                       function that re-executes it through `env` with
#                       PAGER forced to less. Man pages in this config
#                       are already rendered by bat via $MANPAGER
#                       (00-env.zsh), which takes precedence over PAGER
#                       — so the termcap colours are never used and the
#                       wrapper adds a subprocess for no benefit.
#
#   sudo (note)         Loaded above specifically because NO_BANG_HIST
#                       is set in 20-options.zsh, which disables `!!`.
#                       Esc-Esc replaces the `sudo !!` reflex.

# ── Load Oh My Zsh ─────────────────────────────────────────────────
source "$ZSH/oh-my-zsh.sh"
