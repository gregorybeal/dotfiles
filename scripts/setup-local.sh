#!/usr/bin/env bash
# scripts/setup-local.sh — create machine-local, untracked config that Stow
# doesn't (and shouldn't) manage. Idempotent — safe to re-run.
set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"

# ─────────────────────────────────────────────────────────────
#  Git identity (~/.gitconfig.local)
# ─────────────────────────────────────────────────────────────

GITCONFIG_LOCAL="$HOME/.gitconfig.local"
if [ ! -f "$GITCONFIG_LOCAL" ]; then
    echo "Setting up git identity ($GITCONFIG_LOCAL)..."
    read -rp "  Git user name: " GIT_NAME
    read -rp "  Git user email: " GIT_EMAIL
    read -rp "  Git SSH signing key (leave blank to skip): " GIT_SIGNINGKEY

    {
        echo "[user]"
        echo "    name  = $GIT_NAME"
        echo "    email = $GIT_EMAIL"
        if [ -n "$GIT_SIGNINGKEY" ]; then
            echo "    signingkey = $GIT_SIGNINGKEY"
        fi
    } > "$GITCONFIG_LOCAL"
    echo "  Wrote $GITCONFIG_LOCAL"
else
    echo "git identity already set up ($GITCONFIG_LOCAL exists) — skipping"
fi

# ─────────────────────────────────────────────────────────────
#  reg-tool config (~/.config/reg-tool/config)
# ─────────────────────────────────────────────────────────────

REG_CONFIG_DIR="$HOME/.config/reg-tool"
REG_CONFIG="$REG_CONFIG_DIR/config"
if [ ! -f "$REG_CONFIG" ]; then
    mkdir -p "$REG_CONFIG_DIR"
    cp "$DOTFILES/reg-tool/config.example" "$REG_CONFIG"
    chmod 600 "$REG_CONFIG"
    echo "[reg-tool] Created $REG_CONFIG — edit it to set your jumpbox and SQLite paths."
else
    echo "reg-tool config already present ($REG_CONFIG) — skipping"
fi

# ─────────────────────────────────────────────────────────────
#  jira-cli config (~/.config/.jira/.config.yml)
#  Kept out of the (public) repo — it holds your Jira URL + login.
# ─────────────────────────────────────────────────────────────

JIRA_CONFIG_DIR="$HOME/.config/.jira"
JIRA_CONFIG="$JIRA_CONFIG_DIR/.config.yml"
if [ ! -f "$JIRA_CONFIG" ]; then
    mkdir -p "$JIRA_CONFIG_DIR"
    cp "$DOTFILES/jira/config.example" "$JIRA_CONFIG"
    chmod 600 "$JIRA_CONFIG"
    echo "[jira-cli] Created $JIRA_CONFIG — edit server/login/project, or run 'jira init'"
    echo "           to auto-generate it. Set 'export JIRA_API_TOKEN=...' in ~/.secrets."
else
    echo "jira-cli config already present ($JIRA_CONFIG) — skipping"
fi

echo ""
echo "Done."
