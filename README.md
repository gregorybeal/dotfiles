# dotfiles

Personal configuration for shell, tmux/psmux, git, SSH, VS Code, Windows Terminal, and the `reg-tool` register management toolkit.

**GitHub workflow**: HTTPS auth via [GitHub CLI (`gh`)](https://cli.github.com/). No GitHub SSH keys needed — `gh` manages auth tokens and acts as git's credential helper automatically.

**SSH**: still used for jump box and POS register access, just not for GitHub.

## What's in here

```
dotfiles/
├── shell/                      # zsh + bash configs, shared aliases
├── tmux/                       # .tmux.conf (works on tmux AND psmux)
├── git/                        # .gitconfig (HTTPS + gh credential helper)
├── ssh/                        # per-OS SSH configs (jump box + registers)
├── powershell/                 # PowerShell $PROFILE
├── vscode/                     # settings, keybindings, extensions list
├── windows-terminal/           # Windows Terminal settings.json
├── reg-tool/                   # register fzf/tunnel/tmux toolkit
├── bootstrap.sh                # full setup (installs tools) — Mac + WSL
├── bootstrap.ps1               # full setup (installs tools) — Windows
├── install.sh                  # just links configs — Mac + WSL
└── install.ps1                 # just links configs — Windows
```

## First-time setup on a new machine

### 1. Clone the repo

Use HTTPS or `gh repo clone` — both work without any SSH config.

**Mac or WSL:**
```bash
git clone https://github.com/gregorybeal/dotfiles.git ~/code/personal/dotfiles
cd ~/code/personal/dotfiles
./bootstrap.sh
```

**Windows** (elevated PowerShell, or with Developer Mode enabled):
```powershell
git clone https://github.com/gregorybeal/dotfiles.git $env:USERPROFILE\GitHub\personal\dotfiles
cd $env:USERPROFILE\GitHub\personal\dotfiles
.\bootstrap.ps1
```

The bootstrap script installs everything (including `gh`), then runs the linker. Takes 5-10 minutes.

### 1b. (Alternative) Restricted Linux box without sudo

For Ubuntu/Linux boxes where you don't have sudo:

```bash
git clone https://github.com/gregorybeal/dotfiles.git ~/code/personal/dotfiles
cd ~/code/personal/dotfiles
./bootstrap-nosudo.sh
```

The no-sudo script:
- Installs `fzf`, `bat`, `fd`, `rg`, `jq` as **userspace binaries** in `~/.local/bin`
- Sets up Oh My Zsh + plugins **if zsh is already installed**
- Sets up TPM **if tmux is already installed**
- Runs `install.sh` to symlink all configs
- Warns about (but doesn't fail on) missing zsh/tmux

You'll still need to ask the admin for `zsh` and `tmux` themselves if they aren't preinstalled. If neither is available, you can fall back to bash (your `.bashrc` still loads with aliases, prompt, etc.) and use `screen` instead of tmux for session persistence — the core "don't lose work when disconnected" feature works in screen with no setup.

To make zsh your shell without sudo (if it's installed but `chsh` requires admin), add `exec zsh` to the end of your `~/.bash_profile`.

### 2. Authenticate gh

After bootstrap finishes, restart your shell and run:

```bash
gh auth login
```

Pick the following options:
- **GitHub.com** (not Enterprise)
- **HTTPS** as the preferred protocol
- **Yes** to authenticate Git with your credentials (this is the magic — `gh` becomes git's credential helper)
- **Login with a web browser** (easiest)

`gh` opens a browser, you paste a one-time code, done. From now on, `git push` to GitHub HTTPS URLs just works — no token prompts, no SSH config.

### 3. Fill in machine-specific bits

- **`~/.gitconfig`** → uncomment the `[user]` block at the top with your name + email
- **`~/.config/reg-tool/config`** → real jump box hostname, SQLite paths
- **SSH config** → real subnets in place of `10.50.*` / `10.60.*` placeholders
- **`~/.ssh/id_*`** → your SSH private key for jump box access (NOT in the repo)

### 4. Try it

```bash
gh auth status          # confirm you're logged in
reg-refresh             # pull register inventory from SQLite
reg                     # fzf-pick a register, run an action
```

## Daily workflow

Make a change you want everywhere:

```bash
cd ~/code/personal/dotfiles
git add -A
git commit -m "tweak: shorter prompt"
git push
```

`gh` handles auth in the background — no prompts. On another machine:

```bash
cd ~/code/personal/dotfiles && git pull
```

Symlinks mean the changes are live immediately — no re-running install.

## gh CLI cheatsheet

Useful day-to-day commands (the aliases.sh / PowerShell profile sets short versions):

| Command | Alias | What it does |
|---|---|---|
| `gh auth login` | — | Authenticate (do this once per machine) |
| `gh auth status` | — | See which accounts are logged in |
| `gh auth switch` | — | Switch active account |
| `gh repo create <name> --private --source=. --push` | — | Create + push a new repo from current folder |
| `gh repo clone owner/repo` | — | Clone with correct auth |
| `gh pr create --fill` | `ghc` | Open a PR from the current branch |
| `gh pr status` | `ghs` | PRs needing your attention |
| `gh pr list` | `ghl` | All open PRs in this repo |
| `gh pr view --web` | `ghv` | Open current PR in browser |
| `gh issue list --assignee @me` | `ghi` | Your open issues |
| `gh ssh-key add ~/.ssh/id_ed25519.pub -t "name"` | — | Register an SSH key (for non-GitHub use) |

## Multi-account on GitHub

If you have work and personal accounts, `gh` handles both:

```bash
gh auth login        # log into personal
gh auth login        # again — log into work
gh auth status       # see both
gh auth switch       # toggle between them
```

For per-folder git identity (commit author email differs between work and personal), uncomment the `includeIf` blocks in `git/.gitconfig` and create matching `~/.gitconfig-work` and `~/.gitconfig-personal` files on each machine (they're gitignored).

Example `~/.gitconfig-work`:
```
[user]
    name = Greg <YourName>
    email = greg@workdomain.com
```

Example `~/.gitconfig-personal`:
```
[user]
    name = Greg <YourName>
    email = greg@personal.com
```

Organize repos under `~/code/work/` and `~/code/personal/` and the right identity gets picked automatically.

## What gets installed (bootstrap)

### Common to all platforms
- zsh / PowerShell 7
- tmux / psmux
- git
- **gh CLI**
- fzf, bat, fd, ripgrep, jq, zoxide
- Python 3
- VS Code + extensions

### Mac additions
- Homebrew
- eza, yq, tldr, htop, btop, sshfs

### Windows additions
- Windows Terminal
- Oh My Posh
- PSReadLine, Terminal-Icons, posh-git modules
- ssh-agent service enabled
- FiraCode Nerd Font

### Mac + WSL additions
- Oh My Zsh + zsh-autosuggestions + zsh-syntax-highlighting
- TPM (tmux plugin manager)

## What gets linked

| File | Mac path | WSL path | Windows path |
|------|----------|----------|--------------|
| `.zshrc` | `~/.zshrc` | `~/.zshrc` | — |
| `.bashrc` | `~/.bashrc` | `~/.bashrc` | — |
| `aliases.sh` | `~/.aliases.sh` | `~/.aliases.sh` | — |
| `.tmux.conf` | `~/.tmux.conf` | `~/.tmux.conf` | `%USERPROFILE%\.tmux.conf` |
| `.gitconfig` | `~/.gitconfig` | `~/.gitconfig` | `%USERPROFILE%\.gitconfig` |
| SSH config | `~/.ssh/config` (mac) | `~/.ssh/config` (wsl) | `%USERPROFILE%\.ssh\config` (no ControlMaster) |
| PowerShell profile | — | — | `$PROFILE` |
| VS Code settings | `~/Library/Application Support/Code/User/` | `~/.config/Code/User/` | `%APPDATA%\Code\User\` |
| Windows Terminal | — | — | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json` |
| reg-tool | `~/.config/reg-tool/` | (same) | `%USERPROFILE%\.config\reg-tool\` |

## What is NOT in this repo

- **GitHub tokens** — `gh` stores these in its own secure config
- **SSH private keys** (for jump box) — copy these manually per machine
- **Secrets, API tokens** — put them in `~/.secrets` (sourced by `.zshrc` if it exists)
- **Generated files** — `~/.config/reg-tool/registers.csv` (regenerable via `reg-refresh`)
- **Machine-specific overrides** — `*.local` files (gitignored)

Per-machine tweaks live in:
- `~/.zshrc.local`
- `~/.bashrc.local`
- `~/.gitconfig.local`
- `~/.ssh/config.local`
- `~/.powershell_profile.local.ps1`

These are auto-sourced if present, and gitignored.

## Per-OS notes

| | Mac | WSL | Windows |
|---|---|---|---|
| Shell | zsh + Oh My Zsh | zsh + Oh My Zsh | PowerShell + Oh My Posh |
| Multiplexer | tmux | tmux | psmux |
| Terminal | iTerm2 / built-in | (from Windows side) | Windows Terminal |
| SSH ControlMaster | yes | yes | **no** (breaks Windows OpenSSH) |
| GitHub auth | HTTPS via gh | HTTPS via gh | HTTPS via gh |
| reg-tool flavor | reg.sh | reg.sh | reg.ps1 |
| Symlinks need admin? | no | no | yes — or enable Developer Mode |

## reg-tool quick reference

After bootstrap and editing `~/.config/reg-tool/config`:

| Command | What it does |
|---|---|
| `reg-refresh` | Rebuild inventory from local SQLite |
| `reg-refresh remote` | Rebuild from SQLite on the jump box |
| `reg` | fzf-pick a register → pick an action (ssh/vnc/rdp/web/log/status) |
| `reg-multi` | Pick many registers, run one command on all of them |
| `reg-store 1234` | Filter the picker to one store |
| `reg-tmux-store 1234` | tmux session with one pane per register at a store |
| `reg-tmux-pair <ip>` | Two-pane tmux: SSH + tail of log |
| `reg-tunnels` | List active SSH tunnels |
| `reg-tunnels-kill` | Close all active tunnels |

## Troubleshooting

**`fatal: protocol 'git@https' is not supported`** — the remote URL is malformed (mixed SSH + HTTPS). Fix with:
```bash
git remote set-url origin https://github.com/gregorybeal/dotfiles.git
```

**`Permission denied (publickey)` on git operations** — you cloned via SSH but don't have an SSH key for GitHub. With this setup, you should be using HTTPS. Run `gh auth login` and convert the remote:
```bash
git remote set-url origin https://github.com/gregorybeal/dotfiles.git
```

**`gh auth login` worked but `git push` still asks for password** — `gh` wasn't set as the credential helper. Re-run:
```bash
gh auth setup-git
```
This explicitly configures git to use `gh`'s credential helper. The `.gitconfig` in this repo already has it pre-configured, so it shouldn't normally be needed.

**`getsockname failed: Not a socket`** — ControlMaster enabled on Windows. The Windows SSH config in this repo doesn't have it. If you see this error, your SSH config probably wasn't linked correctly — re-run `install.ps1`.

**Oh My Zsh missing symbols/icons** — install a Nerd Font and set it as your terminal font. Mac/Windows: bootstrap installs FiraCode automatically. WSL users: install on Windows side (`winget install -e --id DEVCOM.JetBrainsMonoNerdFont`).

**`reg` command not found** — your shell didn't source `reg-tool/reg.sh`. Check `~/.zshrc` is the symlinked one (`ls -la ~/.zshrc` should show it pointing into the dotfiles repo).

**Windows install.ps1 says "symlink creation requires admin"** — run PowerShell as administrator, OR enable Developer Mode (Settings → Privacy & security → For developers → Developer Mode toggle on). Developer Mode is a one-time setting that lets you symlink without admin going forward.

**VS Code extensions didn't install during bootstrap** — `code` CLI wasn't in PATH yet because VS Code was just installed. Close and reopen your shell, then re-run the install script.
