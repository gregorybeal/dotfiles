#!/usr/bin/env bash
# Bootstrap dotfiles on Mac or WSL/Linux using GNU Stow.
# Idempotent — safe to re-run.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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
        echo "Unsupported OS: $OS — this dotfiles repo is Mac/Linux/WSL only (see README)."
        exit 1
        ;;
esac

echo "Platform: $PLATFORM"
echo ""

# --- Install Homebrew (Mac only) ---
if [ "$PLATFORM" = "mac" ] && ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
fi

# --- Install Stow ---
if ! command -v stow >/dev/null 2>&1; then
    echo "Installing GNU Stow..."
    if [ "$PLATFORM" = "mac" ]; then
        brew install stow
    else
        sudo apt-get update -qq && sudo apt-get install -y stow
    fi
fi

# --- Stow all packages ---
echo ""
echo "Stowing dotfiles from $SCRIPT_DIR..."
cd "$SCRIPT_DIR"
make stow

# --- Machine-local config (git identity, reg-tool config) ---
echo ""
./scripts/setup-local.sh

# --- Mac: install packages from Brewfile ---
if [ "$PLATFORM" = "mac" ]; then
    echo ""
    echo "Installing Mac packages from Brewfile..."
    brew bundle --verbose --file="$SCRIPT_DIR/mac/Brewfile" || echo "brew bundle hit some errors — run 'make brew' to retry."
fi

# --- Linux: install packages ---
if [ "$PLATFORM" = "linux" ] || [ "$PLATFORM" = "wsl" ]; then
    LINUX_PACKAGES="$SCRIPT_DIR/linux/packages.sh"
    if [ -f "$LINUX_PACKAGES" ]; then
        echo ""
        bash "$LINUX_PACKAGES" || echo "linux/packages.sh hit some errors — run 'make linux-packages' to retry."
    fi
fi

echo ""
echo "Done! Next steps:"
echo "  1. Restart your shell (or: exec zsh)"
echo "  2. gh auth login"
echo "  3. Edit ~/.config/reg-tool/config with your jumpbox and SQLite paths"
echo "  4. make doctor  — verify everything's healthy"
