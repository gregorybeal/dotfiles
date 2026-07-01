# dotfiles

Personal config for shell, tmux/psmux, git, SSH, terminals, VS Code, and the `reg-tool` register management toolkit. Managed with [chezmoi](https://chezmoi.io). Works on Mac, WSL, Linux, and Windows.

## Quick start

**On a brand new machine (Mac or WSL/Linux):**
```bash
# One-liner (installs chezmoi + applies everything):
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply github.com/gregorybeal/dotfiles
```

**Or if you've already cloned the repo:**
```bash
cd ~/code/personal/dotfiles
./bootstrap.sh
```

**Windows** (PowerShell):
```powershell
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
make apply         # re-apply dotfiles (chezmoi apply)
make diff          # preview what would change
make update        # pull latest + re-apply (chezmoi update)
make doctor        # health check
make brew          # update Mac apps from Brewfile
```

**Edit a managed dotfile:**
```bash
chezmoi edit ~/.zshrc      # opens source file in $EDITOR
chezmoi apply              # deploy the edit
```

## First-time prompts

On first run, chezmoi will ask:
- **Git user name** and **email** — used in `~/.gitconfig`
- **Git SSH signing key** — optional; leave blank to skip commit signing
- **SSH config variant** — `unix` (full, with jump box) or `minimal` (bare bones); auto-set to `windows` on Windows

Answers are saved to `~/.config/chezmoi/chezmoi.toml` and never re-prompted.

## Layout

```
dotfiles/
├── .chezmoi.toml.tmpl          first-run config (git name/email, SSH variant)
├── .chezmoiignore              platform-specific file filtering
├── .chezmoitemplates/          shared template fragments (PowerShell profile)
│
├── dot_zshrc.tmpl              → ~/.zshrc
├── dot_bashrc.tmpl             → ~/.bashrc
├── dot_aliases.sh              → ~/.aliases.sh
├── dot_tmux.conf               → ~/.tmux.conf
├── dot_gitconfig.tmpl          → ~/.gitconfig
│
├── dot_ssh/
│   └── config.tmpl             → ~/.ssh/config  (variant selected at init)
│
├── dot_config/
│   ├── starship.toml           → ~/.config/starship.toml
│   ├── ghostty/config          → ~/.config/ghostty/config
│   ├── powershell/             → ~/.config/powershell/$PROFILE  (Mac/Linux)
│   ├── reg-tool/               → ~/.config/reg-tool/ (reg.sh, refresh.py)
│   ├── 1Password/ssh/          → ~/.config/1Password/ssh/agent.toml  (symlink)
│   ├── atuin/                  → ~/.config/atuin/config.toml  (symlink)
│   ├── btop/                   → ~/.config/btop/btop.conf  (symlink)
│   ├── karabiner/              → ~/.config/karabiner/karabiner.json  (symlink)
│   └── keyboardcowboy/         → ~/.config/keyboardcowboy/config.json  (symlink)
│
├── Documents/PowerShell/       → ~/Documents/PowerShell/$PROFILE (Windows only)
│
├── run_deploy-vscode.sh.tmpl   copies vscode/ settings to platform path on apply
├── run_once_init-reg-tool-config.*  creates ~/.config/reg-tool/config on first run
│
├── 1Password/                  agent.toml (symlink source — GUI-written)
├── atuin/                      config.toml (symlink source — GUI-written)
├── btop/                       btop.conf (symlink source — GUI-written)
├── karabiner/                  karabiner.json (symlink source — GUI-written)
├── keyboardcowboy/             config.json (symlink source — GUI-written)
├── vscode/                     settings.json, keybindings.json, snippets/
├── windows-terminal/           settings.json (deployed via run script on Windows)
├── mac/                        Brewfile + macos-defaults.sh
├── reg-tool/                   config.example, reg.ps1
├── scripts/                    doctor.sh, gen_ssh_registers.py
├── docs/                       detailed setup & reference docs
│
├── bootstrap.sh                new machine setup — Mac + WSL/Linux
├── bootstrap.ps1               new machine setup — Windows
├── bootstrap-nosudo.sh         restricted Linux (no sudo)
└── Makefile                    short commands for common ops
```

## Machine-specific overrides

These files are gitignored and sourced automatically:
- `~/.zshrc.local` — extra zsh config (work credentials, machine-specific PATH, etc.)
- `~/.bashrc.local` — extra bash config
- `~/.gitconfig.local` — git identity overrides, per-repo settings
- `~/.secrets` — env vars / tokens (sourced by both zsh + bash)
- `~/.ssh/config.local` — extra SSH config (minimal variant includes this automatically)

## Full docs

- **[docs/SETUP.md](docs/SETUP.md)** — first-time setup walkthrough, gh auth, multi-account, machine-specific overrides
- **[docs/REFERENCE.md](docs/REFERENCE.md)** — what gets installed, per-OS notes, gh CLI cheatsheet, reg-tool reference, troubleshooting
