#!/usr/bin/env bash
# Bootstrap dotfiles on a Linux box without sudo access.
# Installs chezmoi to ~/.local/bin and applies dotfiles.
# Idempotent — safe to re-run.
set -e

REPO="github.com/gregorybeal/dotfiles"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# --- Install chezmoi (no sudo needed) ---
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi to ~/.local/bin..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi

# --- Apply dotfiles ---
if [ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]; then
    echo "Applying dotfiles from $SCRIPT_DIR..."
    chezmoi init --source "$SCRIPT_DIR" --apply
    CHEZMOI_DEFAULT="$HOME/.local/share/chezmoi"
    if [ ! -e "$CHEZMOI_DEFAULT" ]; then
        mkdir -p "$(dirname "$CHEZMOI_DEFAULT")"
        ln -sf "$SCRIPT_DIR" "$CHEZMOI_DEFAULT"
        echo "Linked ~/.local/share/chezmoi -> $SCRIPT_DIR"
    fi
else
    echo "Cloning and applying dotfiles from $REPO..."
    chezmoi init --apply "$REPO"
fi

echo ""
echo "Done! Next steps:"
echo "  1. Add ~/.local/bin to your PATH in ~/.bashrc if not already there"
echo "  2. Restart your shell (or: source ~/.bashrc)"
echo "  3. gh auth login"
echo "  4. Edit ~/.config/reg-tool/config with your jumpbox and SQLite paths"
