#!/usr/bin/env bash
# Bootstrap dotfiles on Mac or WSL.
# Idempotent — safe to re-run.
#
# Tolerant of individual link failures: continues past errors and reports
# them at the end. Set DEBUG=1 to see verbose output.

# Deliberately NOT using `set -e` — we want to continue past individual
# link/chmod failures, not bail on the first one. Steps later in the
# script must still run even if earlier ones had issues.

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"
LINK_ERRORS=()

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

    if [ ! -e "$src" ]; then
        echo "  [skip] source missing: $src"
        LINK_ERRORS+=("missing source: $src")
        return 1
    fi

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "  [ok]   $dst (already linked)"
        return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        echo "  [bak]  $dst -> $dst.backup"
        if ! mv "$dst" "$dst.backup"; then
            LINK_ERRORS+=("could not back up: $dst")
            return 1
        fi
    fi
    mkdir -p "$(dirname "$dst")"
    if ln -s "$src" "$dst"; then
        echo "  [link] $dst"
    else
        LINK_ERRORS+=("could not link: $dst")
        return 1
    fi
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

# Determine which SSH config variant to use.
# Priority: 1) env var override, 2) interactive prompt, 3) default (unix)
SSH_VARIANT="${DOTFILES_SSH_VARIANT:-}"

if [ -z "$SSH_VARIANT" ]; then
    # Default for Mac/Linux/WSL is 'unix' (single shared config)
    DEFAULT_VARIANT="unix"

    # Only prompt if stdin is a terminal (interactive run)
    if [ -t 0 ]; then
        echo ""
        echo "  Which SSH config variant?"
        echo "    1) unix     — full config (jump box + registers) [default]"
        echo "    2) minimal  — bare bones, no corp network refs"
        echo ""
        printf "  Choice [1]: "
        read -r choice
        case "$choice" in
            2|minimal|m|M) SSH_VARIANT="minimal" ;;
            *)             SSH_VARIANT="$DEFAULT_VARIANT" ;;
        esac
    else
        SSH_VARIANT="$DEFAULT_VARIANT"
    fi
fi

SSH_SOURCE="$DOTFILES/ssh/config.$SSH_VARIANT"
if [ ! -f "$SSH_SOURCE" ]; then
    echo "  [warn] ssh/config.$SSH_VARIANT not found — falling back to config.unix"
    SSH_SOURCE="$DOTFILES/ssh/config.unix"
fi
echo "  Using $SSH_SOURCE"
link "$SSH_SOURCE" "$HOME/.ssh/config"

# Lock down permissions on SSH configs (best-effort; ignore failures)
for cfg in "$DOTFILES"/ssh/config.*; do
    [ -f "$cfg" ] && chmod 600 "$cfg" 2>/dev/null
done

# --- reg-tool ---
echo "reg-tool:"
mkdir -p "$HOME/.config/reg-tool"
link "$DOTFILES/reg-tool/reg.sh"      "$HOME/.config/reg-tool/reg.sh"
link "$DOTFILES/reg-tool/refresh.py"  "$HOME/.config/reg-tool/refresh.py"
[ -f "$DOTFILES/reg-tool/refresh.py" ] && chmod +x "$DOTFILES/reg-tool/refresh.py" 2>/dev/null

if [ ! -f "$HOME/.config/reg-tool/config" ]; then
    cp "$DOTFILES/reg-tool/config.example" "$HOME/.config/reg-tool/config" 2>/dev/null && \
        echo "  [new]  ~/.config/reg-tool/config (edit this to set jumpbox + paths)"
else
    echo "  [keep] ~/.config/reg-tool/config (already exists)"
fi

# --- ghostty terminal (Mac/Linux config path) ---
if [ -d "$DOTFILES/ghostty" ]; then
    echo "Ghostty config:"
    mkdir -p "$HOME/.config/ghostty"
    link "$DOTFILES/ghostty/config" "$HOME/.config/ghostty/config"
fi

# --- vscode snippets ---
if [ -d "$DOTFILES/vscode/snippets" ]; then
    echo "VS Code snippets:"
    case "$PLATFORM" in
        mac)        VSCODE_USER="$HOME/Library/Application Support/Code/User" ;;
        wsl|linux)  VSCODE_USER="$HOME/.config/Code/User" ;;
    esac
    if [ -n "$VSCODE_USER" ]; then
        mkdir -p "$VSCODE_USER/snippets"
        for snippet in "$DOTFILES/vscode/snippets"/*.json; do
            [ -f "$snippet" ] && link "$snippet" "$VSCODE_USER/snippets/$(basename "$snippet")"
        done
    fi
fi

# --- scripts directory: make sure helpers are executable ---
chmod +x "$DOTFILES/scripts"/*.sh 2>/dev/null || true

echo ""
echo "Done."

# Print summary of any link failures
if [ ${#LINK_ERRORS[@]} -gt 0 ]; then
    echo ""
    echo "  ⚠ ${#LINK_ERRORS[@]} link(s) had issues:"
    for err in "${LINK_ERRORS[@]}"; do
        echo "      - $err"
    done
fi

echo ""
echo "Next steps:"
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
