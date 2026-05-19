# ════════════════════════════════════════════════════════════════════
#  ROOT ZSHRC — loader only. Real config lives in modules/
#  Repo: ~/projects/dotfiles/zshprofile/
#  ~/.zshrc is a symlink to this file (created by install.sh)
# ════════════════════════════════════════════════════════════════════

# Absolute path to this profile, resolving the symlink so it works
# no matter where ~/.zshrc points from.
export ZSH_PROFILE_DIR="${${(%):-%x}:A:h}"

# Load every module in modules/ in numeric order (00 → 90).
# Each file is a single concern; order is encoded in the filename
# prefix so this loader never needs editing when modules change.
for _zsh_module in "$ZSH_PROFILE_DIR"/modules/[0-9]*.zsh; do
  [ -r "$_zsh_module" ] && source "$_zsh_module"
done
unset _zsh_module

# Machine-specific overrides, loaded LAST so they win.
# This file is git-ignored — never leaves this machine.
[ -r "$ZSH_PROFILE_DIR/local/local.zsh" ] && source "$ZSH_PROFILE_DIR/local/local.zsh"
