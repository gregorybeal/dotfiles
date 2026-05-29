# Dotfiles Makefile — short commands for common operations.
# Run `make help` to see what's available.

DOTFILES := $(shell pwd)
OS := $(shell uname -s)

.DEFAULT_GOAL := help

.PHONY: help
help:  ## Show this help
	@echo ""
	@echo "  dotfiles — make targets"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""

.PHONY: install
install:  ## Link configs to ~/ (interactive: asks about SSH variant)
	@./install.sh

.PHONY: install-minimal
install-minimal:  ## Link configs using minimal SSH variant (no jump box)
	@DOTFILES_SSH_VARIANT=minimal ./install.sh

.PHONY: bootstrap
bootstrap:  ## Full setup on new machine (installs tools + links configs)
ifeq ($(OS),Darwin)
	@./bootstrap.sh
else
	@./bootstrap.sh
endif

.PHONY: bootstrap-nosudo
bootstrap-nosudo:  ## Full setup on restricted Linux box (no sudo)
	@./bootstrap-nosudo.sh

.PHONY: brew
brew:  ## Install/update all Mac apps from Brewfile (Mac only)
ifeq ($(OS),Darwin)
	@brew bundle --file=mac/Brewfile
else
	@echo "brew bundle only runs on Mac"
endif

.PHONY: brew-check
brew-check:  ## Show what's in Brewfile but not installed (Mac only)
ifeq ($(OS),Darwin)
	@brew bundle check --file=mac/Brewfile --verbose
else
	@echo "brew bundle only runs on Mac"
endif

.PHONY: brew-cleanup
brew-cleanup:  ## Remove brew packages NOT in Brewfile (DANGEROUS — dry-run first)
ifeq ($(OS),Darwin)
	@echo "Dry run — these would be removed:"
	@brew bundle cleanup --file=mac/Brewfile
	@echo ""
	@echo "Run 'brew bundle cleanup --file=mac/Brewfile --force' to actually remove."
else
	@echo "brew bundle only runs on Mac"
endif

.PHONY: macos-defaults
macos-defaults:  ## Apply macOS system preferences (Mac only)
ifeq ($(OS),Darwin)
	@./mac/macos-defaults.sh
else
	@echo "macos-defaults only runs on Mac"
endif

.PHONY: doctor
doctor:  ## Health check the dotfiles setup
	@./scripts/doctor.sh

.PHONY: update
update:  ## Pull latest from git and re-link
	@git pull
	@./install.sh

.PHONY: reg-refresh
reg-refresh:  ## Refresh register inventory CSV from SQLite
	@uv run reg-tool/refresh.py

.PHONY: vscode-ext
vscode-ext:  ## Install all VS Code extensions
	@cat vscode/extensions.txt | grep -vE '^\s*(#|$$)' | \
		xargs -I {} code --install-extension {} --force
