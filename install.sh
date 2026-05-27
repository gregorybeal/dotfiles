#!/usr/bin/env bash
# Bootstrap dotfiles on Mac or WSL.
# Idempotent — safe to re-run.

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

case "$OS" in
    Darwin) PLATFORM="mac" ;;
    Linux)
        if grep -qi microsoft /proc/version 2>/dev/null; then
            PLATFORM="wsl"
        else
            PLATFORM="linux"
        fi
        ;;
    *)
        echo "Unsupported OS: $OS — use install.ps1 on Windows."
        exit 1
        ;;
esac

echo "Platform detected: $PLATFORM"
echo "Dotfiles root:     $DOTFILES"
echo ""

# --- helper: link a file, backing up any existing target ---
link() {
    local src="$1" dst="$2"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "  [ok]   $dst (already linked)"
        return
    fi
    if [ -e "$dst" ]; then
        echo "  [bak]  $dst -> $dst.backup"
        mv "$dst" "$dst.backup"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "  [link] $dst"
}

# --- shell ---
echo "Shell configs:"
link "$DOTFILES/shell/.zshrc"  "$HOME/.zshrc"
link "$DOTFILES/shell/.bashrc" "$HOME/.bashrc"
link "$DOTFILES/shell/aliases.sh" "$HOME/.aliases.sh"

# --- tmux ---
echo "tmux config:"
link "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"

# --- starship ---
echo "Starship config:"
mkdir -p "$HOME/.config"
link "$DOTFILES/starship/starship.toml" "$HOME/.config/starship.toml"

# --- git ---
echo "git config:"
link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

# --- ssh ---
echo "SSH config:"
mkdir -p "$HOME/.ssh/sockets"
chmod 700 "$HOME/.ssh/sockets"
if [ "$PLATFORM" = "mac" ]; then
    link "$DOTFILES/ssh/config.mac" "$HOME/.ssh/config"
else
    link "$DOTFILES/ssh/config.wsl" "$HOME/.ssh/config"
fi
chmod 600 "$DOTFILES/ssh/config.mac" "$DOTFILES/ssh/config.wsl" 2>/dev/null || true

# --- reg-tool ---
echo "reg-tool:"
mkdir -p "$HOME/.config/reg-tool"
link "$DOTFILES/reg-tool/reg.sh"      "$HOME/.config/reg-tool/reg.sh"
link "$DOTFILES/reg-tool/refresh.py"  "$HOME/.config/reg-tool/refresh.py"
chmod +x "$DOTFILES/reg-tool/refresh.py"

if [ ! -f "$HOME/.config/reg-tool/config" ]; then
    cp "$DOTFILES/reg-tool/config.example" "$HOME/.config/reg-tool/config"
    echo "  [new]  ~/.config/reg-tool/config (edit this to set jumpbox + paths)"
else
    echo "  [keep] ~/.config/reg-tool/config (already exists)"
fi

echo ""
echo "Done. Next steps:"
echo ""
echo "  1. Open a new shell (or: source ~/.zshrc)"
echo "  2. Authenticate with GitHub:  gh auth login"
echo "     (pick HTTPS, then 'Yes' to authenticate git)"
echo "  3. Edit ~/.config/reg-tool/config with your jump box + SQLite paths"
echo "  4. Run: reg-refresh"
echo "  5. Try: reg"
echo ""

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Oh My Zsh not detected. Install it with:"
    echo "  sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    echo ""
fi
