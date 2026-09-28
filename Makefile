# Dotfiles Makefile — short commands for common operations.
# Run `make help` to see what's available.

DOTFILES := $(shell pwd)
OS := $(shell uname -s)
WSL := $(shell grep -qi microsoft /proc/version 2>/dev/null && echo 1)

CORE_PACKAGES := zsh bash aliases git ssh tmux nvim starship ghostty atuin btop powershell
MAC_PACKAGES  := karabiner keyboardcowboy 1password

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Show this help
	@echo ""
	@echo "  dotfiles — make targets"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: bootstrap
bootstrap:  ## Full setup on new machine (installs Stow + stows + installs packages)
	@./bootstrap.sh

.PHONY: dirs
dirs:  ## Create runtime data dirs Stow doesn't manage (zsh cache/state, ssh sockets)
	@mkdir -p "$(HOME)/.local/state/zsh"
	@mkdir -p "$(HOME)/.cache/zsh"
	@mkdir -p "$(HOME)/.ssh/sockets"
	@chmod 700 "$(HOME)/.ssh/sockets"

.PHONY: stow
stow: dirs  ## Symlink all packages for this OS into $$HOME (idempotent)
	@./scripts/adopt-conflicts.sh $(CORE_PACKAGES)
	@stow -v $(CORE_PACKAGES)
ifeq ($(OS),Darwin)
	@./scripts/adopt-conflicts.sh $(MAC_PACKAGES)
	@stow -v $(MAC_PACKAGES)
endif

.PHONY: unstow
unstow:  ## Remove all package symlinks from $$HOME
	@stow -D -v $(CORE_PACKAGES)
ifeq ($(OS),Darwin)
	@stow -D -v $(MAC_PACKAGES)
endif

.PHONY: setup-local
setup-local:  ## Create machine-local config (git identity, jira-cli config)
	@./scripts/setup-local.sh

.PHONY: linux-packages
linux-packages:  ## Install Linux packages — Ubuntu/Debian with sudo (idempotent)
	@./linux/packages.sh

.PHONY: brew
brew:  ## Install/update from mac/Brewfile, or linux/Brewfile on Linux/WSL (continues past failures)
ifeq ($(OS),Darwin)
	@echo "Caching sudo credentials (single prompt for all cask installs)..."
	@sudo -v
	@( while true; do sudo -n true; sleep 60; kill -0 $$$$ 2>/dev/null || exit; done ) & \
		KEEPALIVE_PID=$$!; \
		brew bundle --verbose --file=mac/Brewfile || { \
			echo ""; \
			echo "⚠ brew bundle hit errors. Retrying each item individually..."; \
			echo ""; \
			grep -vE '^\s*(#|$$)' mac/Brewfile | while IFS= read -r line; do \
				case "$$line" in \
					tap\ *) name=$$(echo "$$line" | sed -E 's/^tap[[:space:]]+"([^"]+)".*/\1/'); brew tap "$$name" 2>/dev/null || echo "  ✗ tap: $$name" ;; \
					brew\ *) name=$$(echo "$$line" | sed -E 's/^brew[[:space:]]+"([^"]+)".*/\1/'); brew install "$$name" 2>/dev/null || echo "  ✗ brew: $$name" ;; \
					cask\ *) name=$$(echo "$$line" | sed -E 's/^cask[[:space:]]+"([^"]+)".*/\1/'); brew install --cask "$$name" 2>/dev/null || echo "  ✗ cask: $$name" ;; \
					mas\ *) id=$$(echo "$$line" | sed -E 's/.*id:[[:space:]]*([0-9]+).*/\1/'); mas install "$$id" 2>/dev/null || echo "  ✗ mas: $$id" ;; \
					uv\ *) name=$$(echo "$$line" | sed -E 's/^uv[[:space:]]+"([^"]+)".*/\1/'); uv tool install "$$name" 2>/dev/null || echo "  ✗ uv: $$name" ;; \
				esac; \
			done; \
		}; \
		kill $$KEEPALIVE_PID 2>/dev/null || true
else
	@command -v brew >/dev/null 2>&1 || { echo "Homebrew not installed — see https://brew.sh"; exit 1; }
	@brew bundle --verbose --file=linux/Brewfile || echo "⚠ brew bundle hit errors — see output above"
endif

.PHONY: brew-check
brew-check:  ## Show what's in this OS's Brewfile but not installed
ifeq ($(OS),Darwin)
	@brew bundle check --file=mac/Brewfile --verbose
else
	@brew bundle check --file=linux/Brewfile --verbose
endif

.PHONY: wt
wt:  ## Merge windows-terminal/settings.json into Windows Terminal (WSL only; DRY=1 to preview)
ifeq ($(WSL),1)
	@./windows-terminal/sync.py $(if $(DRY),--dry-run)
else
	@echo "wt only runs under WSL"
endif

.PHONY: macos-defaults
macos-defaults:  ## Apply macOS system preferences (Mac only)
ifeq ($(OS),Darwin)
	@./mac/macos-defaults.sh
else
	@echo "macos-defaults only runs on Mac"
endif

.PHONY: touchid
touchid:  ## Enable Touch ID for sudo — works in Ghostty + tmux (Mac only)
ifeq ($(OS),Darwin)
	@./mac/enable-touchid-sudo.sh
else
	@echo "touchid only applies to macOS"
endif

.PHONY: doctor
doctor:  ## Health check the dotfiles setup
	@./scripts/doctor.sh

.PHONY: update
update:  ## Pull latest changes and re-stow
	@git pull
	@$(MAKE) stow


