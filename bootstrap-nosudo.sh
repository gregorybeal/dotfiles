#!/usr/bin/env bash
# Bootstrap dotfiles on a Linux box without sudo access.
# Installs everything possible into ~/.local/ and ~/, skips what needs root.

set -e

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"

echo "========================================"
echo " dotfiles bootstrap (no-sudo)"
echo "========================================"
echo ""

# Quick capability scan
echo "What's already available:"
for tool in bash zsh tmux screen git curl wget fzf bat fd rg jq vim ssh; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool (will try to install or skip)"
    fi
done
echo ""

mkdir -p "$LOCAL_BIN"

# Ensure ~/.local/bin in PATH for this session
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *) export PATH="$LOCAL_BIN:$PATH" ;;
esac

# --- helper: download a release binary ---
fetch_binary() {
    local name="$1" url="$2" archive_path="$3"
    if command -v "$name" >/dev/null 2>&1; then
        echo "  ✓ $name already installed"
        return
    fi
    echo "  Installing $name..."
    local tmp
    tmp=$(mktemp -d)
    (
        cd "$tmp"
        curl -fsSL -O "$url"
        local archive
        archive=$(ls)
        case "$archive" in
            *.tar.gz|*.tgz) tar xzf "$archive" ;;
            *.tar.xz)       tar xJf "$archive" ;;
            *)              ;;  # raw binary
        esac
        if [ -n "$archive_path" ]; then
            cp "$archive_path" "$LOCAL_BIN/$name"
        else
            # Assume the downloaded file IS the binary
            cp "$archive" "$LOCAL_BIN/$name"
        fi
        chmod +x "$LOCAL_BIN/$name"
    )
    rm -rf "$tmp"
    echo "  ✓ $name installed to $LOCAL_BIN/"
}

# ----------------------------------------
# Step 1: fzf
# ----------------------------------------

echo "[1/5] fzf"
if [ ! -d "$HOME/.fzf" ] && ! command -v fzf >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf"/install --all --no-bash --no-fish 2>/dev/null || \
        "$HOME/.fzf"/install --all
else
    echo "  ✓ fzf already present"
fi
echo ""

# ----------------------------------------
# Step 2: ripgrep, bat, fd, jq (modern CLI binaries)
# ----------------------------------------

echo "[2/5] Modern CLI tools (userspace binaries)"

fetch_binary "rg" \
    "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz" \
    "ripgrep-14.1.1-x86_64-unknown-linux-musl/rg"

fetch_binary "bat" \
    "https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-x86_64-unknown-linux-musl.tar.gz" \
    "bat-v0.24.0-x86_64-unknown-linux-musl/bat"

fetch_binary "fd" \
    "https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz" \
    "fd-v10.1.0-x86_64-unknown-linux-musl/fd"

if ! command -v jq >/dev/null 2>&1; then
    echo "  Installing jq..."
    curl -fsSL -o "$LOCAL_BIN/jq" \
        https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
    chmod +x "$LOCAL_BIN/jq"
    echo "  ✓ jq installed"
else
    echo "  ✓ jq already installed"
fi

# Starship — userspace install
if ! command -v starship >/dev/null 2>&1; then
    echo "  Installing Starship to $LOCAL_BIN..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$LOCAL_BIN"
    echo "  ✓ starship installed"
else
    echo "  ✓ starship already installed"
fi

# uv — Python toolchain (userspace install)
if ! command -v uv >/dev/null 2>&1; then
    echo "  Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$LOCAL_BIN" sh
    echo "  ✓ uv installed"
else
    echo "  ✓ uv already installed"
fi
echo ""

# ----------------------------------------
# Step 3: Oh My Zsh + plugins (only if zsh exists)
# ----------------------------------------

echo "[3/5] Oh My Zsh (requires zsh)"
if ! command -v zsh >/dev/null 2>&1; then
    echo "  ⚠ zsh not installed and you don't have sudo."
    echo "    Ask your admin: 'sudo apt install zsh'"
    echo "    Skipping Oh My Zsh — bash will be used instead."
else
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "  Installing Oh My Zsh..."
        RUNZSH=no CHSH=no sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "  ✓ Oh My Zsh already installed."
    fi

    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions \
            "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi

    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting \
            "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi

    echo "  NOTE: cannot 'chsh -s zsh' without sudo. To use zsh as your login shell:"
    echo "        either ask the admin, OR add 'exec zsh' to ~/.bash_profile"
fi
echo ""

# ----------------------------------------
# Step 4: TPM (only if tmux exists)
# ----------------------------------------

echo "[4/5] TPM (requires tmux)"
if ! command -v tmux >/dev/null 2>&1; then
    echo "  ⚠ tmux not installed. Either ask admin ('sudo apt install tmux')"
    echo "    or fall back to 'screen' if available."
    if command -v screen >/dev/null 2>&1; then
        echo "    Note: 'screen' is available — it covers the session-persistence use case."
    fi
else
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        echo "  ✓ TPM cloned. After first tmux session, press prefix + I to install plugins."
    else
        echo "  ✓ TPM already installed."
    fi
fi
echo ""

# ----------------------------------------
# Step 5: Run the linker
# ----------------------------------------

echo "[5/5] Linking configs"
# Use the minimal SSH config (no jump box / no registers) by default.
# Override with: DOTFILES_SSH_VARIANT=wsl ./bootstrap-nosudo.sh
DOTFILES_SSH_VARIANT="${DOTFILES_SSH_VARIANT:-minimal}" \
    "$DOTFILES/install.sh"

echo ""
echo "========================================"
echo " Bootstrap complete (no-sudo edition)"
echo "========================================"
echo ""
echo "  Notes:"
echo "  - Userspace binaries live in $LOCAL_BIN"
echo "  - Make sure $LOCAL_BIN is in your PATH (it is in the dotfiles .bashrc/.zshrc)"
echo "  - If zsh isn't installed, you'll fall back to bash (still gets dotfile niceties)"
echo "  - If tmux isn't installed, try 'screen' for session persistence"
echo "  - Authenticate to GitHub: gh auth login  (only if gh is available)"
echo ""
