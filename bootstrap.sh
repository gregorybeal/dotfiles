#!/usr/bin/env bash
# Bootstrap dotfiles on Mac or WSL/Linux using chezmoi.
# Idempotent — safe to re-run.
set -e

REPO="github.com/gregorybeal/dotfiles"
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
        echo "Unsupported OS: $OS — use bootstrap.ps1 on Windows."
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

# --- Install chezmoi ---
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi..."
    if command -v brew >/dev/null 2>&1; then
        brew install chezmoi
    else
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# --- Apply dotfiles ---
if [ -f "$SCRIPT_DIR/.chezmoi.toml.tmpl" ]; then
    echo "Applying dotfiles from $SCRIPT_DIR..."
    chezmoi init --source "$SCRIPT_DIR" --apply
    # Symlink the default chezmoi source dir to this repo so that future
    # `chezmoi apply` / `chezmoi diff` / `chezmoi doctor` work without --source.
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

# --- Mac: install packages from Brewfile ---
if [ "$PLATFORM" = "mac" ]; then
    CHEZMOI_SRC="$(chezmoi source-path)"
    BREWFILE="$CHEZMOI_SRC/mac/Brewfile"
    if [ -f "$BREWFILE" ]; then
        echo ""
        echo "Installing Mac packages from Brewfile..."
        brew bundle --file="$BREWFILE" || echo "brew bundle hit some errors — run 'make brew' to retry."
    fi
fi

# --- Linux: install packages ---
if [ "$PLATFORM" = "linux" ]; then
    LINUX_PACKAGES="$SCRIPT_DIR/linux/packages.sh"
    if [ -f "$LINUX_PACKAGES" ]; then
        echo ""
        echo "Installing Linux packages..."
        bash "$LINUX_PACKAGES" || echo "linux/packages.sh hit some errors — run 'make linux-packages' to retry."
    fi
fi

echo ""
echo "Done! Next steps:"
echo "  1. Restart your shell (or: source ~/.zshrc)"
echo "  2. gh auth login"
echo "  3. Edit ~/.config/reg-tool/config with your jumpbox and SQLite paths"
echo "  4. make doctor  — verify everything's healthy"
