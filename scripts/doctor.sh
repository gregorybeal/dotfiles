#!/usr/bin/env bash
# doctor.sh — verify dotfiles setup is healthy on this machine.
# Reports what's working, what's missing, what needs attention.

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
OS="$(uname -s)"

# Colors (if terminal supports it)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    DIM='\033[2m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' DIM='' NC=''
fi

# Track findings
PASS=0
WARN=0
FAIL=0

ok()    { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS+1)); }
warn()  { echo -e "  ${YELLOW}⚠${NC} $*"; WARN=$((WARN+1)); }
fail()  { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL+1)); }
info()  { echo -e "  ${DIM}ⓘ${NC} $*"; }

section() {
    echo ""
    echo -e "${BLUE}▸ $1${NC}"
}

# ─────────────────────────────────────────────────────────────
#  Resolve a symlink to its canonical path — portable across GNU
#  readlink (Linux, supports -f) and BSD readlink (macOS, doesn't).
# ─────────────────────────────────────────────────────────────

resolve_path() {
    if command -v greadlink >/dev/null 2>&1; then
        greadlink -f "$1" 2>/dev/null
    elif readlink -f "$1" >/dev/null 2>&1; then
        readlink -f "$1" 2>/dev/null
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$1" 2>/dev/null
    else
        readlink "$1" 2>/dev/null
    fi
}

# ─────────────────────────────────────────────────────────────
#  Check: a target is a symlink resolving into this Stow repo
# ─────────────────────────────────────────────────────────────

check_stow() {
    local target="$1" package="$2"
    # Stow symlinks at the highest level it safely can — sometimes that's
    # the file itself, sometimes an ancestor directory (e.g. .config/atuin
    # as a whole, if nothing else lives there). Either is correctly
    # stowed, so check whether the path *resolves* into this repo at all,
    # not just whether the exact target is itself a symlink.
    if [ -e "$target" ] || [ -L "$target" ]; then
        local resolved
        resolved="$(resolve_path "$target")"
        case "$resolved" in
            "$DOTFILES/$package"/*|"$DOTFILES/$package") ok "$target → ~/dotfiles/$package/..." ;;
            *) warn "$target exists, but doesn't resolve into ~/dotfiles/$package (got $resolved) — run: cd ~/dotfiles && stow $package" ;;
        esac
    else
        info "$target is missing — run: cd ~/dotfiles && stow $package"
    fi
}

# ─────────────────────────────────────────────────────────────
#  Check: command is available
# ─────────────────────────────────────────────────────────────

check_cmd() {
    local cmd="$1" purpose="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd ($purpose)"
    else
        warn "$cmd not installed — $purpose"
    fi
}

# ─────────────────────────────────────────────────────────────
#  Header
# ─────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo " dotfiles doctor"
echo "═══════════════════════════════════════════════════════"
echo "  Host: $(hostname)"
echo "  OS:   $OS"
echo "  Repo: $DOTFILES"

# ─────────────────────────────────────────────────────────────
section "Stow packages"
# ─────────────────────────────────────────────────────────────

check_stow "$HOME/.zshenv" "zsh"
check_stow "$HOME/.zshrc" "zsh"
check_stow "$HOME/.zsh" "zsh"
check_stow "$HOME/.bashrc" "bash"
check_stow "$HOME/.aliases.sh" "aliases"
check_stow "$HOME/.gitconfig" "git"
check_stow "$HOME/.ssh/config" "ssh"
check_stow "$HOME/.tmux.conf" "tmux"
check_stow "$HOME/.config/starship.toml" "starship"
check_stow "$HOME/.config/ghostty/config" "ghostty"
check_stow "$HOME/.config/atuin/config.toml" "atuin"
check_stow "$HOME/.config/btop/btop.conf" "btop"
check_stow "$HOME/.config/reg-tool/reg.sh" "reg-tool"
check_stow "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1" "powershell"

if [ "$OS" = "Darwin" ]; then
    check_stow "$HOME/.config/karabiner/karabiner.json" "karabiner"
    check_stow "$HOME/.config/keyboardcowboy/config.json" "keyboardcowboy"
    check_stow "$HOME/.config/1Password/ssh/agent.toml" "1password"
fi

# ─────────────────────────────────────────────────────────────
section "Core CLI tools"
# ─────────────────────────────────────────────────────────────

check_cmd git "version control"
check_cmd gh "GitHub CLI"
check_cmd ssh "SSH client"
check_cmd tmux "terminal multiplexer"
check_cmd starship "prompt"
check_cmd stow "GNU Stow (dotfiles deployment)"

# ─────────────────────────────────────────────────────────────
section "Modern CLI tools"
# ─────────────────────────────────────────────────────────────

check_cmd fzf "fuzzy finder"
check_cmd rg "ripgrep"
check_cmd bat "cat replacement"
check_cmd fd "find replacement"
check_cmd jq "JSON processor"
check_cmd uv "Python toolchain"
check_cmd atuin "shell history — Ctrl-R"

# ─────────────────────────────────────────────────────────────
section "Shell"
# ─────────────────────────────────────────────────────────────

if [ -n "$ZSH_VERSION" ]; then
    ok "Running zsh ($ZSH_VERSION)"
elif [ -n "$BASH_VERSION" ]; then
    info "Running bash ($BASH_VERSION) — zsh recommended"
else
    warn "Unknown shell"
fi

if [ -d "$HOME/.local/share/zinit" ]; then
    ok "zinit/zsh plugins installed"
else
    info "zinit not installed yet (self-installs on first zsh launch)"
fi

if [ -d "$HOME/.local/state/zsh" ]; then
    ok "~/.local/state/zsh exists (zsh history)"
else
    warn "~/.local/state/zsh missing — HISTFILE can't be written. Run: make dirs"
fi

if [ -d "$HOME/.cache/zsh" ]; then
    ok "~/.cache/zsh exists (completion cache)"
else
    warn "~/.cache/zsh missing — compinit dump can't be cached. Run: make dirs"
fi

# ─────────────────────────────────────────────────────────────
section "SSH"
# ─────────────────────────────────────────────────────────────

if [ -d "$HOME/.ssh/sockets" ]; then
    ok "~/.ssh/sockets directory exists (ControlMaster)"
else
    warn "~/.ssh/sockets missing — ControlMaster is enabled in ssh/.ssh/config and needs this. Run: make dirs"
fi

if [ -f "$HOME/.ssh/id_ed25519" ] || [ -f "$HOME/.ssh/id_rsa" ]; then
    ok "SSH private key present"
else
    warn "No SSH private key found (generate with: ssh-keygen -t ed25519)"
fi

if ssh-add -l >/dev/null 2>&1; then
    KEY_COUNT=$(ssh-add -l | wc -l | tr -d ' ')
    ok "ssh-agent running with $KEY_COUNT key(s) loaded"
else
    warn "ssh-agent has no keys loaded (or isn't running)"
fi

# ─────────────────────────────────────────────────────────────
section "GitHub auth (gh)"
# ─────────────────────────────────────────────────────────────

if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        ACCT=$(gh api user --jq .login 2>/dev/null || echo "unknown")
        ok "gh authenticated as $ACCT"
    else
        warn "gh installed but not authenticated — run: gh auth login"
    fi
fi

# ─────────────────────────────────────────────────────────────
section "Git identity"
# ─────────────────────────────────────────────────────────────

if [ -f "$HOME/.gitconfig.local" ]; then
    ok "~/.gitconfig.local present"
else
    warn "~/.gitconfig.local missing — run: ./scripts/setup-local.sh"
fi

# ─────────────────────────────────────────────────────────────
section "tmux"
# ─────────────────────────────────────────────────────────────

if command -v tmux >/dev/null 2>&1; then
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        ok "TPM (tmux plugin manager) installed"
    else
        warn "TPM not installed — git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
    fi
fi

# ─────────────────────────────────────────────────────────────
section "reg-tool"
# ─────────────────────────────────────────────────────────────

if [ -f "$HOME/.config/reg-tool/config" ]; then
    ok "reg-tool config present"
else
    warn "reg-tool config missing — run: ./scripts/setup-local.sh"
fi

if [ -f "$HOME/.config/reg-tool/registers.csv" ]; then
    COUNT=$(grep -cvE '^\s*(#|$)' "$HOME/.config/reg-tool/registers.csv" || echo 0)
    ok "registers.csv present ($COUNT registers)"
else
    info "registers.csv not generated yet — run: reg-refresh"
fi

# ─────────────────────────────────────────────────────────────
section "Dotfiles repo state"
# ─────────────────────────────────────────────────────────────

if [ -d "$DOTFILES/.git" ]; then
    cd "$DOTFILES"
    if git diff-index --quiet HEAD 2>/dev/null; then
        ok "Working tree clean"
    else
        warn "Uncommitted changes in dotfiles repo"
        git status --short | sed 's/^/      /'
    fi

    LOCAL=$(git rev-parse @ 2>/dev/null)
    REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        warn "Local repo is out of sync with remote — run: git pull"
    elif [ -n "$REMOTE" ]; then
        ok "In sync with remote"
    fi
fi

# ─────────────────────────────────────────────────────────────
#  Summary
# ─────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo -e " Summary: ${GREEN}${PASS} ok${NC}, ${YELLOW}${WARN} warnings${NC}, ${RED}${FAIL} failures${NC}"
echo "═══════════════════════════════════════════════════════"
echo ""

[ $FAIL -gt 0 ] && exit 1
exit 0
