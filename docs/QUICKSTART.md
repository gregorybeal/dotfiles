# New Machine Setup

Exact commands to run when setting up a new machine. All scripts are idempotent — safe to re-run.

---

## Mac

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone the repo (adjust path to your preference)
mkdir -p ~/Git && git clone https://github.com/gregorybeal/dotfiles ~/Git/dotfiles

# 3. Bootstrap — installs chezmoi, applies dotfiles, and runs Brewfile
cd ~/Git/dotfiles && ./bootstrap.sh

# 4. Authenticate GitHub
gh auth login

# 5. Verify everything looks healthy
make doctor
```

---

## Linux / Ubuntu (with sudo)

```bash
# 1. Clone the repo
mkdir -p ~/Git && git clone https://github.com/gregorybeal/dotfiles ~/Git/dotfiles

# 2. Bootstrap — installs chezmoi, applies dotfiles, and installs apt packages
cd ~/Git/dotfiles && ./bootstrap.sh

# 3. Authenticate GitHub
gh auth login

# 4. Verify everything looks healthy
make doctor
```

---

## Linux (no sudo / restricted)

```bash
# 1. Clone the repo
mkdir -p ~/Git && git clone https://github.com/gregorybeal/dotfiles ~/Git/dotfiles

# 2. Bootstrap — installs chezmoi to ~/.local/bin, applies dotfiles
cd ~/Git/dotfiles && ./bootstrap-nosudo.sh

# 3. Add ~/.local/bin to PATH if not already there
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc

# 4. Authenticate GitHub (if gh is available)
gh auth login
```

---

## Windows (PowerShell)

```powershell
# 1. Clone the repo (adjust path to your preference)
mkdir "$env:USERPROFILE\GitHub\personal" -Force
git clone https://github.com/gregorybeal/dotfiles "$env:USERPROFILE\GitHub\personal\dotfiles"

# 2. Bootstrap — installs chezmoi, applies dotfiles, copies PowerShell profile
cd "$env:USERPROFILE\GitHub\personal\dotfiles"
.\bootstrap.ps1

# 3. Authenticate GitHub
gh auth login

# 4. Restart PowerShell, then verify
make doctor
```

---

## After bootstrap (all platforms)

```bash
# Reload your shell
exec zsh          # or exec bash

# If you use 1Password for secrets (jiratui, etc.)
# — make sure the 1Password desktop app is running and you're signed in
# — then re-apply to populate secrets from 1Password
chezmoi apply

# Pull the latest dotfiles changes from GitHub
chezmoi update    # or: make update

# Edit a dotfile (opens source file in $EDITOR, then deploy with chezmoi apply)
chezmoi edit ~/.zshrc
chezmoi apply
```

---

## One-liner (skip cloning — lets chezmoi clone for you)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply github.com/gregorybeal/dotfiles
```

> Note: This clones to `~/.local/share/chezmoi` instead of your preferred `~/Git/dotfiles` path. Use the full bootstrap steps above if you want the repo at a specific location.
