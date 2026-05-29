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
#  Check: symlinks point at the dotfiles repo
# ─────────────────────────────────────────────────────────────

check_link() {
    local target="$1" expected_prefix="$2"
    if [ -L "$target" ]; then
        local actual
        actual=$(readlink "$target")
        case "$actual" in
            *"$expected_prefix"*) ok "$target → $actual" ;;
            *) warn "$target is a symlink, but points to $actual (expected $expected_prefix)" ;;
        esac
    elif [ -e "$target" ]; then
        warn "$target exists but isn't a symlink (was install.sh run?)"
    else
        fail "$target is missing"
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
section "Dotfile symlinks"
# ─────────────────────────────────────────────────────────────

check_link "$HOME/.zshrc" "dotfiles/shell"
check_link "$HOME/.bashrc" "dotfiles/shell"
check_link "$HOME/.aliases.sh" "dotfiles/shell"
check_link "$HOME/.tmux.conf" "dotfiles/tmux"
check_link "$HOME/.gitconfig" "dotfiles/git"
check_link "$HOME/.ssh/config" "dotfiles/ssh"
check_link "$HOME/.config/starship.toml" "dotfiles/starship"
check_link "$HOME/.config/reg-tool/reg.sh" "dotfiles/reg-tool"

# ─────────────────────────────────────────────────────────────
section "Core CLI tools"
# ─────────────────────────────────────────────────────────────

check_cmd git "version control"
check_cmd gh "GitHub CLI"
check_cmd ssh "SSH client"
check_cmd tmux "terminal multiplexer"
check_cmd starship "prompt"

# ─────────────────────────────────────────────────────────────
section "Modern CLI tools"
# ─────────────────────────────────────────────────────────────

check_cmd fzf "fuzzy finder"
check_cmd rg "ripgrep"
check_cmd bat "cat replacement"
check_cmd fd "find replacement"
check_cmd jq "JSON processor"
check_cmd uv "Python toolchain"

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

if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "Oh My Zsh installed"
else
    info "Oh My Zsh not installed (skip if you don't use zsh)"
fi

# ─────────────────────────────────────────────────────────────
section "SSH"
# ─────────────────────────────────────────────────────────────

if [ -d "$HOME/.ssh/sockets" ]; then
    ok "~/.ssh/sockets directory exists (ControlMaster)"
else
    info "~/.ssh/sockets missing (only needed if ControlMaster enabled)"
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
    warn "reg-tool config missing — copy from config.example and edit"
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
