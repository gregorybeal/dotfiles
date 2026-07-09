#!/usr/bin/env bash
# linux/packages.sh — install dev tools on Ubuntu/Debian with sudo.
# Run with: ./linux/packages.sh
# Or:       make linux-packages
# Idempotent — safe to re-run.
set -e

echo "Installing Linux packages..."
echo ""

# ─────────────────────────────────────────────────────────────
#  APT packages
# ─────────────────────────────────────────────────────────────
sudo apt-get update -qq

sudo apt-get install -y \
    `# Shell` \
    zsh tmux stow \
    `# Core` \
    git curl wget tree watch build-essential \
    `# Modern CLI tools` \
    fzf bat fd-find ripgrep jq htop btop \
    `# Network / SSH` \
    openssh-client mtr nmap iperf3 sshpass sshfs \
    `# Dev` \
    sqlite3 ansible

# Ubuntu names these differently — add standard symlinks
[ -f /usr/bin/batcat ]  && sudo ln -sf /usr/bin/batcat  /usr/local/bin/bat 2>/dev/null || true
[ -f /usr/bin/fdfind ]  && sudo ln -sf /usr/bin/fdfind  /usr/local/bin/fd  2>/dev/null || true

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
