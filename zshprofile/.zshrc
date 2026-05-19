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
#
# NOTE: use an `if` block, NOT `[ -r ... ] && source ...`.
# With `&&`, a MISSING local.zsh makes the test fail, the &&
# short-circuits, and the whole line exits 1 — which becomes the
# shell's startup exit status and shows as "✘1" on the first prompt.
# An `if` block evaluates to 0 when the condition is false, so a
# missing local.zsh leaves a clean exit status.
if [ -r "$ZSH_PROFILE_DIR/local/local.zsh" ]; then
  source "$ZSH_PROFILE_DIR/local/local.zsh"
fi

# Belt-and-suspenders: guarantee .zshrc ALWAYS ends with exit 0,
# regardless of whatever the last sourced module's last command
# returned. Prevents a stray non-zero status from decorating the
# very first prompt of every new terminal.
true
