#!/usr/bin/env bash
# linux/packages.sh — install dev tools on Ubuntu/Debian/WSL: a small apt base,
# then linux/Brewfile if Homebrew is installed (apt + upstream installers if not).
# Run with: ./linux/packages.sh
# Or:       make linux-packages
# Idempotent — safe to re-run.
set -e

echo "Installing Linux packages..."
echo ""

IS_WSL=0
grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=1

# Pick up Linuxbrew even when the calling shell hasn't loaded it yet (e.g. the
# first bootstrap, before the stowed .bashrc/.zshenv have ever been sourced).
if ! command -v brew >/dev/null 2>&1; then
    for b in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
        [ -x "$b" ] && { eval "$("$b" shellenv)"; break; }
    done
fi

# ─────────────────────────────────────────────────────────────
#  APT base — always from apt, even when Homebrew is present
#  (see linux/Brewfile for why each of these stays on apt)
# ─────────────────────────────────────────────────────────────
sudo apt-get update -qq

sudo apt-get install -y \
    zsh stow git curl wget unzip build-essential procps file \
    openssh-client sshfs mtr socat

# wslu provides wslview (open URLs/files in Windows); not in every release's
# default image, so don't let its absence abort the run.
if [ "$IS_WSL" = 1 ]; then
    sudo apt-get install -y wslu || echo "  wslu unavailable — falling back to explorer.exe for open/BROWSER"
fi

# ─────────────────────────────────────────────────────────────
#  CLI tools — Homebrew when present (matches the Mac's versions),
#  otherwise apt + the upstream installers below
# ─────────────────────────────────────────────────────────────
if command -v brew >/dev/null 2>&1; then
    echo "Installing CLI tools from linux/Brewfile..."
    brew bundle --verbose --file="$(dirname "$0")/Brewfile" \
        || echo "brew bundle hit some errors — run 'make brew' to retry."
    # Homebrew creates share/zsh group-writable, which makes compinit refuse
    # to load completions from it ("insecure directories").
    brew_prefix="$(brew --prefix)"
    chmod g-w,o-w "$brew_prefix/share/zsh" "$brew_prefix/share/zsh/site-functions" 2>/dev/null || true
else
    sudo apt-get install -y \
        `# Shell` \
        tmux \
        `# Core` \
        tree watch \
        `# Modern CLI tools` \
        fzf bat fd-find ripgrep jq htop btop \
        `# Network / SSH` \
        nmap iperf3 sshpass \
        `# Dev` \
        sqlite3 ansible

    # Ubuntu names these differently — add standard symlinks
    [ -f /usr/bin/batcat ]  && sudo ln -sf /usr/bin/batcat  /usr/local/bin/bat 2>/dev/null || true
    [ -f /usr/bin/fdfind ]  && sudo ln -sf /usr/bin/fdfind  /usr/local/bin/fd  2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────
#  gh CLI (GitHub's official apt repo)
# ─────────────────────────────────────────────────────────────
if ! command -v gh >/dev/null 2>&1; then
    echo "Installing gh CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y gh
fi

# ─────────────────────────────────────────────────────────────
#  eza (better ls — has its own apt repo)
# ─────────────────────────────────────────────────────────────
if ! command -v eza >/dev/null 2>&1; then
    echo "Installing eza..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
        | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq && sudo apt-get install -y eza
fi

# ─────────────────────────────────────────────────────────────
#  yq (YAML processor — not in apt)
# ─────────────────────────────────────────────────────────────
if ! command -v yq >/dev/null 2>&1; then
    echo "Installing yq..."
    YQ_VER="$(curl -fsSL https://api.github.com/repos/mikefarah/yq/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)"
    sudo wget -qO /usr/local/bin/yq \
        "https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_amd64"
    sudo chmod +x /usr/local/bin/yq
fi

# ─────────────────────────────────────────────────────────────
#  Starship prompt
# ─────────────────────────────────────────────────────────────
if ! command -v starship >/dev/null 2>&1; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

# ─────────────────────────────────────────────────────────────
#  uv (Python toolchain)
# ─────────────────────────────────────────────────────────────
if ! command -v uv >/dev/null 2>&1; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# ─────────────────────────────────────────────────────────────
#  atuin (shell history sync)
# ─────────────────────────────────────────────────────────────
if ! command -v atuin >/dev/null 2>&1; then
    echo "Installing atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
fi

# ─────────────────────────────────────────────────────────────
#  zoxide (smarter cd)
# ─────────────────────────────────────────────────────────────
if ! command -v zoxide >/dev/null 2>&1; then
    echo "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
fi

# ─────────────────────────────────────────────────────────────
#  WSL: Windows-side helpers (installed with winget, on the Windows PATH)
#    npiperelay — relays the 1Password SSH agent into WSL (zsh/.zsh/ssh-agent.zsh)
#    win32yank  — UTF-8-safe clipboard for tmux, nvim, pbcopy/pbpaste
# ─────────────────────────────────────────────────────────────
if [ "$IS_WSL" = 1 ] && command -v winget.exe >/dev/null 2>&1; then
    for pkg in npiperelay:albertony.npiperelay win32yank:equalsraf.win32yank; do
        exe="${pkg%%:*}.exe" id="${pkg#*:}"
        if ! command -v "$exe" >/dev/null 2>&1; then
            echo "Installing $id (Windows, via winget)..."
            # winget.exe complains about a \\wsl$ working directory — run from C:.
            (cd /mnt/c && winget.exe install --id "$id" -e --silent \
                --accept-source-agreements --accept-package-agreements) \
                || echo "  winget install $id failed — install it from Windows"
        fi
    done
    echo "  (new winget installs reach WSL's PATH after restarting Windows Terminal)"
fi

# ─────────────────────────────────────────────────────────────
#  TPM (tmux plugin manager)
# ─────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Installing TPM..."
    git clone --depth=1 https://github.com/tmux-plugins/tpm \
        "$HOME/.tmux/plugins/tpm"
fi

# ─────────────────────────────────────────────────────────────
#  uv-managed Python tools
# ─────────────────────────────────────────────────────────────
if command -v uv >/dev/null 2>&1; then
    echo "Installing uv tools..."
    uv tool install ruff    2>/dev/null || true
    uv tool install httpie  2>/dev/null || true
    uv tool install glances 2>/dev/null || true
    uv tool install ipython 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────
#  Set zsh as default shell
# ─────────────────────────────────────────────────────────────
if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "Setting zsh as default shell..."
    chsh -s "$(command -v zsh)"
fi

echo ""
echo "Done! Restart your shell (or: exec zsh)"
