#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  install.sh — bootstrap the zsh profile. Run ONCE.
#  Footprint in $HOME: exactly ONE symlink (~/.zshrc). Nothing else.
#  Idempotent: safe to re-run; skips anything already present.
# ════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Resolve repo paths (works no matter where it's called from) ────
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTERNAL="$PROFILE_DIR/external"
OMZ_DIR="$EXTERNAL/oh-my-zsh"
PLUGINS_DIR="$EXTERNAL/plugins"
THEMES_DIR="$OMZ_DIR/custom/themes"

log()  { printf '\033[1;32m▸ %s\033[0m\n' "$1"; }
skip() { printf '\033[1;33m• %s (already present, skipping)\033[0m\n' "$1"; }

# ── 1. System packages (the modern CLI stack you listed) ───────────
log "Installing system packages via apt…"
sudo apt update -qq
sudo apt install -y \
  zsh git curl unzip \
  fzf zoxide eza bat ripgrep fd-find btop tmux \
  fontconfig
# Ubuntu ships fd as 'fdfind' and bat as 'batcat' — aliases in 60 handle it.

# ── 2. Oh My Zsh → into the repo, NOT ~/.oh-my-zsh ─────────────────
if [[ -d "$OMZ_DIR" ]]; then
  skip "Oh My Zsh"
else
  log "Cloning Oh My Zsh into external/…"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR"
fi
mkdir -p "$THEMES_DIR"

# ── 3. Spaceship theme → OMZ custom themes (inside repo) ───────────
if [[ -d "$THEMES_DIR/spaceship-prompt" ]]; then
  skip "Spaceship"
else
  log "Cloning Spaceship theme…"
  git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git \
    "$THEMES_DIR/spaceship-prompt"
  ln -sf "$THEMES_DIR/spaceship-prompt/spaceship.zsh-theme" \
    "$THEMES_DIR/spaceship.zsh-theme"
fi

# ── 4. Plugins → external/plugins (git-ignored) ────────────────────
clone_plugin() {
  local name="$1" url="$2"
  if [[ -d "$PLUGINS_DIR/$name" ]]; then
    skip "plugin: $name"
  else
    log "Cloning plugin: $name…"
    git clone --depth=1 "$url" "$PLUGINS_DIR/$name"
  fi
}
clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions.git
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git

# ── 5. Nerd Font (Spaceship symbols need it) → XDG font dir ────────
FONT_DIR="$HOME/.local/share/fonts"
if fc-list 2>/dev/null | grep -qi "FiraCode Nerd Font"; then
  skip "FiraCode Nerd Font"
else
  log "Installing FiraCode Nerd Font…"
  mkdir -p "$FONT_DIR"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/FiraCode.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
  unzip -qo "$tmp/FiraCode.zip" -d "$FONT_DIR"
  rm -rf "$tmp"
  fc-cache -f "$FONT_DIR" >/dev/null
  log "Font installed. Set your terminal font to 'FiraCode Nerd Font' manually."
fi

# ── 6. The ONLY thing that touches \$HOME: ~/.zshrc symlink ────────
if [[ -L "$HOME/.zshrc" && "$(readlink "$HOME/.zshrc")" == "$PROFILE_DIR/.zshrc" ]]; then
  skip "~/.zshrc symlink"
else
  if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    log "Backing up existing ~/.zshrc → ~/.zshrc.pre-dotfiles"
    mv "$HOME/.zshrc" "$HOME/.zshrc.pre-dotfiles"
  fi
  log "Linking ~/.zshrc → repo (the one and only \$HOME footprint)…"
  ln -sf "$PROFILE_DIR/.zshrc" "$HOME/.zshrc"
fi

# ── 7. Make zsh the default shell ──────────────────────────────────
if [[ "${SHELL:-}" == *zsh ]]; then
  skip "default shell already zsh"
else
  log "Setting zsh as default shell (you may be prompted for password)…"
  chsh -s "$(command -v zsh)"
  log "Log out/in (or restart terminal) for the shell change to take effect."
fi

log "Done. Open a new terminal — or run: exec zsh"
