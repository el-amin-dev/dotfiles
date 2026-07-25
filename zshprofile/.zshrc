# ════════════════════════════════════════════════════════════════════
#  ROOT ZSHRC — loader ONLY. All real configuration lives in modules/
#
#  ~/.zshrc is a symlink to this file, created by install.sh.
#
#  Nothing else belongs in this file. Machine-specific settings go in
#  local/local.zsh (git-ignored); everything else belongs in a numbered
#  module. Keeping the loader empty is what makes the module order the
#  single source of truth for "when does X happen".
# ════════════════════════════════════════════════════════════════════

# Absolute path to this profile, resolving the symlink so the config
# works no matter where ~/.zshrc points from.
export ZSH_PROFILE_DIR="${${(%):-%x}:A:h}"

# Load every module in modules/ in numeric order (00 → 99).
# Each file owns one concern; load order is encoded in the filename
# prefix, so this loop never needs editing when modules are added.
# The (N) qualifier makes a no-match glob expand to nothing instead of
# leaving the literal pattern in place.
for _zsh_module in "$ZSH_PROFILE_DIR"/modules/[0-9]*.zsh(N); do
  [[ -r "$_zsh_module" ]] && source "$_zsh_module"
done
unset _zsh_module

# Machine-specific overrides, loaded LAST so they win over every module.
# This file is git-ignored — it never leaves this machine.
#
# NOTE: use an `if` block, NOT `[[ -r ... ]] && source ...`.
# With `&&`, a MISSING local.zsh makes the test fail, the && short-
# circuits, and the whole line exits 1 — which becomes the shell's
# startup exit status and shows as "✘ 1" on the very first prompt.
# An `if` block evaluates to 0 when the condition is false, so a
# missing local.zsh leaves a clean exit status.
if [[ -r "$ZSH_PROFILE_DIR/local/local.zsh" ]]; then
  source "$ZSH_PROFILE_DIR/local/local.zsh"
fi

# Guarantee .zshrc always ends with exit status 0, whatever the last
# sourced module happened to return. Without this, a stray non-zero
# status decorates the first prompt of every new terminal.
true
