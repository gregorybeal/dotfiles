#!/usr/bin/env bash
# Full bootstrap — installs all prerequisite tools, then runs install.sh.
# Idempotent: safe to re-run on an already-set-up machine.
#
# Mac:  installs Homebrew + tools + Oh My Zsh + fonts
# WSL:  apt install + Oh My Zsh + fonts (in Windows, separately)

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
        echo "Unsupported OS: $OS — use bootstrap.ps1 on Windows."
        exit 1
        ;;
esac

echo "========================================"
echo " dotfiles bootstrap"
echo " platform: $PLATFORM"
echo "========================================"
echo ""

# ----------------------------------------
# Step 1: Package manager + base tools
# ----------------------------------------

if [ "$PLATFORM" = "mac" ]; then
    echo "[1/5] Homebrew + tools"
    if ! command -v brew >/dev/null 2>&1; then
        echo "  Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for this session (Apple Silicon)
        if [ -d /opt/homebrew/bin ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        echo "  Homebrew already installed."
    fi

    brew update
    brew install \
        zsh \
        tmux \
        git \
        gh \
        starship \
        fzf \
        bat \
        eza \
        fd \
        ripgrep \
        zoxide \
        jq \
        yq \
        tldr \
        htop \
        btop \
        wget \
        python3 \
        sshfs

    # fzf shell integration
    $(brew --prefix)/opt/fzf/install --all --no-bash --no-fish

else
    # WSL/Linux
    echo "[1/5] apt + tools"
    sudo apt update
    sudo apt install -y \
        zsh \
        tmux \
        git \
        curl \
        wget \
        fzf \
        bat \
        fd-find \
        ripgrep \
        jq \
        python3 \
        python3-pip \
        sshfs \
        htop

    # gh CLI — not always in default apt, install from GitHub's apt repo
    if ! command -v gh >/dev/null 2>&1; then
        echo "  Installing gh CLI..."
        (type -p wget >/dev/null || sudo apt install wget -y) \
            && sudo mkdir -p -m 755 /etc/apt/keyrings \
            && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
            && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
            && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
            && sudo apt update \
            && sudo apt install gh -y
    fi

    # Starship prompt — official installer, drops binary in /usr/local/bin
    if ! command -v starship >/dev/null 2>&1; then
        echo "  Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi

    # Install eza if available (newer ubuntus)
    if ! command -v eza >/dev/null 2>&1; then
        echo "  eza not in apt — skipping (install manually if wanted)"
    fi
fi

echo ""

# ----------------------------------------
# Step 2: Oh My Zsh + plugins
# ----------------------------------------

echo "[2/5] Oh My Zsh + zsh plugins"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "  Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
    echo "  Oh My Zsh already installed."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "  Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "  Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

echo ""

# ----------------------------------------
# Step 3: TPM (tmux plugin manager)
# ----------------------------------------

echo "[3/5] TPM (tmux plugins)"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "  Cloning TPM..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    echo "  After first tmux session, press prefix + I to install plugins."
else
    echo "  TPM already installed."
fi

echo ""

# ----------------------------------------
# Step 4: Fonts
# ----------------------------------------

echo "[4/5] Nerd Fonts (FiraCode)"

if [ "$PLATFORM" = "mac" ]; then
    if ! ls ~/Library/Fonts/FiraCode* 2>/dev/null | grep -q .; then
        brew tap homebrew/cask-fonts 2>/dev/null || true
        brew install --cask font-fira-code-nerd-font || \
            echo "  Font install failed — install manually from nerdfonts.com"
    else
        echo "  FiraCode Nerd Font already present."
    fi
else
    # WSL — fonts need to be installed on the WINDOWS side for Windows Terminal
    echo "  NOTE: On WSL, install Nerd Fonts in Windows, not here."
    echo "        Run on Windows: winget install -e --id DEVCOM.JetBrainsMonoNerdFont"
    echo "        Or download FiraCode from https://www.nerdfonts.com/"
fi

echo ""

# ----------------------------------------
# Step 5: VS Code extensions (if code in PATH)
# ----------------------------------------

echo "[5/5] VS Code extensions"

if command -v code >/dev/null 2>&1; then
    if [ -f "$DOTFILES/vscode/extensions.txt" ]; then
        echo "  Installing VS Code extensions..."
        grep -vE '^\s*(#|$)' "$DOTFILES/vscode/extensions.txt" | while read -r ext; do
            code --install-extension "$ext" --force >/dev/null 2>&1 && \
                echo "    + $ext" || \
                echo "    ! failed: $ext"
        done

        # Link VS Code settings
        case "$PLATFORM" in
            mac)
                VSCODE_DIR="$HOME/Library/Application Support/Code/User"
                ;;
            wsl|linux)
                VSCODE_DIR="$HOME/.config/Code/User"
                ;;
        esac

        if [ -d "$VSCODE_DIR" ] || mkdir -p "$VSCODE_DIR"; then
            [ -f "$VSCODE_DIR/settings.json" ] && [ ! -L "$VSCODE_DIR/settings.json" ] && \
                mv "$VSCODE_DIR/settings.json" "$VSCODE_DIR/settings.json.backup"
            ln -sf "$DOTFILES/vscode/settings.json" "$VSCODE_DIR/settings.json"
            echo "  Linked: $VSCODE_DIR/settings.json"

            [ -f "$VSCODE_DIR/keybindings.json" ] && [ ! -L "$VSCODE_DIR/keybindings.json" ] && \
                mv "$VSCODE_DIR/keybindings.json" "$VSCODE_DIR/keybindings.json.backup"
            ln -sf "$DOTFILES/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
            echo "  Linked: $VSCODE_DIR/keybindings.json"
        fi
    fi
else
    echo "  VS Code (code CLI) not found in PATH — skipping."
    echo "  In VS Code: Cmd/Ctrl+Shift+P -> 'Shell Command: Install code command'"
fi

echo ""

# ----------------------------------------
# Final: run the linker
# ----------------------------------------

echo "========================================"
echo " Running install.sh to link configs"
echo "========================================"
"$DOTFILES/install.sh"

echo ""
echo "========================================"
echo " Bootstrap complete!"
echo "========================================"
echo ""
echo "  Next:"
echo "  1. chsh -s \$(which zsh)  # if zsh isn't your default shell yet"
echo "  2. Restart your terminal"
echo "  3. Inside tmux, press prefix+I to install TPM plugins"
echo "  4. Authenticate with GitHub:  gh auth login"
echo "       (pick HTTPS, then 'Yes' to authenticate git)"
echo "  5. Edit ~/.config/reg-tool/config"
echo "  6. Run: reg-refresh"
echo ""
