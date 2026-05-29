# dotfiles

Personal config for shell, tmux/psmux, git, SSH, terminals, VS Code, and the `reg-tool` register management toolkit. Works on Mac, WSL, Linux, and Windows.

## Quick start

**Mac or WSL/Linux:**
```bash
git clone https://github.com/gregorybeal/dotfiles.git ~/code/personal/dotfiles
cd ~/code/personal/dotfiles
./bootstrap.sh
```

**Windows** (elevated PowerShell):
```powershell
git clone https://github.com/gregorybeal/dotfiles.git $env:USERPROFILE\GitHub\personal\dotfiles
cd $env:USERPROFILE\GitHub\personal\dotfiles
.\bootstrap.ps1
```

**Restricted Linux (no sudo):**
```bash
./bootstrap-nosudo.sh
```

After bootstrap, restart your shell and run:
```bash
gh auth login        # GitHub HTTPS auth — yes to "authenticate git"
make doctor          # verify everything's healthy
```

## Daily commands

```bash
make help          # show all targets
make doctor        # health check
make brew          # update Mac apps from Brewfile
make update        # git pull + relink
```

## Layout

```
dotfiles/
├── shell/                  zsh + bash configs, aliases
├── tmux/                   .tmux.conf (works with psmux too)
├── starship/               cross-shell prompt
├── git/                    .gitconfig with gh credential helper
├── ssh/                    config.unix + config.windows + config.minimal
├── powershell/             $PROFILE
├── vscode/                 settings, keybindings, extensions, snippets
├── ghostty/                Ghostty terminal config
├── windows-terminal/       Windows Terminal settings.json
├── mac/                    Brewfile + macos-defaults.sh
├── reg-tool/               register fzf/tunnel/tmux toolkit
├── scripts/                helpers (doctor health check)
├── docs/                   detailed setup & reference docs
├── bootstrap.sh            full setup — Mac + WSL
├── bootstrap.ps1           full setup — Windows
├── bootstrap-nosudo.sh     restricted Linux setup
├── install.sh              link configs — Mac/WSL/Linux
├── install.ps1             link configs — Windows
└── Makefile                short commands for common ops
```

## Full docs

- **[docs/SETUP.md](docs/SETUP.md)** — first-time setup walkthrough, gh auth, multi-account, machine-specific overrides
- **[docs/REFERENCE.md](docs/REFERENCE.md)** — what gets installed, what gets linked, per-OS notes, gh CLI cheatsheet, reg-tool reference, troubleshooting
