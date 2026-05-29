# Setup Guide

Detailed walkthrough for setting up a fresh machine.

## Brand-new Mac

```bash
# 1. Install Xcode CLT (needed for git)
xcode-select --install

# 2. Clone dotfiles
git clone https://github.com/gregorybeal/dotfiles.git ~/code/personal/dotfiles
cd ~/code/personal/dotfiles

# 3. Full bootstrap (Homebrew → Brewfile → links → offers macOS defaults)
./bootstrap.sh
```

Total time: ~15 minutes, mostly waiting for brew installs.

After it finishes, restart your shell, then:

```bash
gh auth login                  # GitHub auth — pick HTTPS, "Yes" to authenticate git
$EDITOR ~/.config/reg-tool/config   # set jumpbox hostname + SQLite paths
reg-refresh                    # pull register inventory
make doctor                    # verify
```

## Windows

Run in an **elevated PowerShell** (or with Developer Mode enabled in Settings → Privacy → For developers):

```powershell
git clone https://github.com/gregorybeal/dotfiles.git $env:USERPROFILE\GitHub\personal\dotfiles
cd $env:USERPROFILE\GitHub\personal\dotfiles
.\bootstrap.ps1
```

The script:
- Installs all winget packages (PowerShell 7, Windows Terminal, Git, gh CLI, psmux, fzf, Starship, uv, bat, fd, ripgrep, jq, zoxide, Python, VS Code)
- Installs PowerShell modules (PSReadLine, Terminal-Icons, posh-git)
- Installs FiraCode Nerd Font
- Enables ssh-agent as a service
- Installs VS Code extensions
- Links Windows Terminal settings.json
- Links all configs

After it finishes, close PowerShell and open a new window. Then:

```powershell
gh auth login           # HTTPS, yes to authenticate git
notepad $env:USERPROFILE\.config\reg-tool\config   # set jumpbox + SQLite paths
```

## Restricted Linux box (no sudo)

```bash
git clone https://github.com/gregorybeal/dotfiles.git ~/code/personal/dotfiles
cd ~/code/personal/dotfiles
./bootstrap-nosudo.sh
```

This installs everything possible into `~/.local/bin/`:
- fzf, bat, fd, ripgrep, jq, Starship, uv (userspace binaries)
- Oh My Zsh + plugins (only if zsh is already installed)
- TPM (only if tmux is already installed)

You'll still need to ask your admin for `zsh` and `tmux` if they aren't pre-installed. Without zsh, you fall back to bash. Without tmux, try `screen` for session persistence.

By default, the no-sudo bootstrap uses the **minimal SSH config** (no jump box / register routing) since those boxes typically can't reach the corp network.

To use zsh as your shell without `chsh` (which usually requires sudo), add to `~/.bash_profile`:
```bash
if [ -t 1 ] && command -v zsh >/dev/null 2>&1; then
    exec zsh
fi
```

## GitHub authentication (gh)

After bootstrap, `gh auth login` walks you through:

1. **GitHub.com** (not Enterprise)
2. **HTTPS** as the preferred protocol
3. **Yes** to authenticate Git with your credentials — this is the important one: it makes `gh` git's credential helper, so `git push` works without prompts forever
4. **Login with a web browser** (easiest)

To verify: `gh auth status`

## Multiple GitHub accounts

`gh` handles multiple accounts natively:

```bash
gh auth login        # log into personal
gh auth login        # again — log into work
gh auth status       # see both
gh auth switch       # toggle between them
```

For per-folder commit identity (work email in work repos, personal email in personal repos), uncomment the `includeIf` blocks in `git/.gitconfig` and create matching `~/.gitconfig-work` and `~/.gitconfig-personal` files. Both are gitignored.

Then organize repos under `~/code/work/` and `~/code/personal/` — the right identity gets picked automatically.

## SSH config variants

When running `install.sh` or `install.ps1` interactively, the script asks:

```
Which SSH config variant?
  1) unix     — full config (jump box + registers) [default]
  2) minimal  — bare bones, no corp network refs

Choice [1]:
```

Pick **minimal** on any machine that can't (or shouldn't) reach the corp network — restricted Linux boxes, personal machines, etc.

The `bootstrap-nosudo.sh` defaults to **minimal** automatically.

To skip the prompt (e.g. in automation), set `DOTFILES_SSH_VARIANT` before calling:

```bash
DOTFILES_SSH_VARIANT=minimal ./install.sh
```
```powershell
$env:DOTFILES_SSH_VARIANT = "minimal"; .\install.ps1
```

## Machine-specific overrides

Per-machine tweaks that you don't want in the repo go in these files (all auto-sourced if they exist, all gitignored):

- `~/.zshrc.local` — extra zsh config
- `~/.bashrc.local` — extra bash config
- `~/.gitconfig.local` — per-machine git settings (e.g. work email)
- `~/.ssh/config.local` — per-machine SSH hosts
- `~/.powershell_profile.local.ps1` — extra PowerShell

## What you need to fill in (one-time, per machine)

- **`~/.gitconfig`** — uncomment `[user]` block, add name + email
- **`~/.config/reg-tool/config`** — jump box hostname, SQLite paths
- **`reg-tool/refresh.py`** — tweak the SQL `QUERY` constant if your schema differs
- **SSH configs** — real IP subnets instead of `10.50.*` / `10.60.*` placeholders
- **`~/.ssh/id_*`** — your SSH private keys (NOT in repo, copy manually)
