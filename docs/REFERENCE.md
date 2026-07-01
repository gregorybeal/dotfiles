# Reference

What this repo installs, where things get linked, and how to use the toolkit.

## What gets installed (bootstrap)

### Common to all platforms

- zsh / PowerShell 7
- tmux / psmux
- git
- **gh CLI**
- **Starship** (cross-shell prompt)
- **uv** (Python toolchain)
- fzf, bat, fd, ripgrep, jq, zoxide
- VS Code + extensions

### Mac additions

- Homebrew (via Brewfile)
- eza, yq, tldr, htop, btop
- GUI apps: Ghostty, iTerm2, Chrome, Firefox, Zoom, Teams, Outlook, 1Password, Raycast,, Alt-Tab, VS Code, Docker, GitHub Desktop, Bruno, TablePlus,  DBeaver-Community, MS Remote Desktop, Royal TSX, VNC Viewer, VLC, Stats
- Nerd Fonts: FiraCode, JetBrains Mono, Cascadia Code
- Mac App Store: Xcode, TestFlight
- uv-managed tools: ruff, httpie, glances, ipython, yt-dlp

### Windows additions

- Windows Terminal, PowerShell 7
- PSReadLine, Terminal-Icons, posh-git modules
- ssh-agent service enabled
- FiraCode Nerd Font

### Mac + WSL additions

- Oh My Zsh + zsh-autosuggestions + zsh-syntax-highlighting
- TPM (tmux plugin manager)

## What gets deployed

Managed by chezmoi (`chezmoi apply`). Templated files (`.tmpl`) are rendered at apply time; symlinked files (`symlink_`) point back into the repo so GUI apps write directly to the source.

| File                        | Mac path                                     | WSL/Linux path           | Windows path                                  |
| --------------------------- | -------------------------------------------- | ------------------------ | --------------------------------------------- |
| `.zshrc`                  | `~/.zshrc`                                 | `~/.zshrc`             | —                                            |
| `.bashrc`                 | `~/.bashrc`                                | `~/.bashrc`            | —                                            |
| `aliases.sh`              | `~/.aliases.sh`                            | `~/.aliases.sh`        | —                                            |
| `.tmux.conf`              | `~/.tmux.conf`                             | `~/.tmux.conf`         | `%USERPROFILE%\.tmux.conf`                  |
| Starship                    | `~/.config/starship.toml`                  | (same)                   | `%USERPROFILE%\.config\starship.toml`       |
| `.gitconfig`              | `~/.gitconfig`                             | (same)                   | `%USERPROFILE%\.gitconfig`                  |
| SSH config                  | `~/.ssh/config` (unix)                     | `~/.ssh/config` (unix) | `%USERPROFILE%\.ssh\config` (windows)       |
| Ghostty                     | `~/.config/ghostty/config`                 | (same)                   | —                                            |
| PowerShell profile          | —                                           | —                       | `$PROFILE`                                  |
| VS Code settings            | `~/Library/Application Support/Code/User/` | `~/.config/Code/User/` | `%APPDATA%\Code\User\`                      |
| reg-tool                    | `~/.config/reg-tool/`                      | (same)                   | `%USERPROFILE%\.config\reg-tool\`           |
| 1Password agent *(symlink)* | `~/.config/1Password/ssh/agent.toml`       | —                       | —                                            |
| Karabiner *(symlink)*       | `~/.config/karabiner/karabiner.json`       | —                       | —                                            |
| Keyboard Cowboy *(symlink)* | `~/.config/keyboardcowboy/config.json`     | —                       | —                                            |
| atuin *(symlink)*           | `~/.config/atuin/config.toml`              | (same)                   | —                                            |
| btop *(symlink)*            | `~/.config/btop/btop.conf`                 | (same)                   | —                                            |

## What is NOT in this repo

- **GitHub tokens** — `gh` stores these in its own secure config
- **SSH private keys** — copy manually per machine
- **Secrets / API tokens** — put in `~/.secrets` (sourced if it exists)
- **Generated files** — `reg-tool/registers.csv` (regenerable via `reg-refresh`)
- **Machine-specific** — `*.local` files (gitignored)

## Per-OS notes

|                          | Mac                             | WSL                 | Windows                               |
| ------------------------ | ------------------------------- | ------------------- | ------------------------------------- |
| Shell                    | zsh + Oh My Zsh                 | zsh + Oh My Zsh     | PowerShell + Starship                 |
| Multiplexer              | tmux                            | tmux                | psmux                                 |
| Terminal                 | Ghostty / iTerm2 / Terminal.app | (from Windows side) | Windows Terminal                      |
| SSH ControlMaster        | yes                             | yes                 | **no** (breaks Windows OpenSSH) |
| SSH Keychain integration | yes (macOS Keychain)            | n/a                 | n/a                                   |
| GitHub auth              | HTTPS via gh                    | HTTPS via gh        | HTTPS via gh                          |
| reg-tool flavor          | reg.sh                          | reg.sh              | reg.ps1                               |
| Symlinks need admin?     | no                              | no                  | yes — or enable Developer Mode       |

## Makefile targets

```bash
make help              # show all targets
make apply             # deploy dotfiles (chezmoi apply)
make diff              # preview what would change before applying
make bootstrap         # full setup on new machine (Mac/Linux)
make bootstrap-nosudo  # full setup on restricted Linux box
make doctor            # health check the setup
make brew              # install everything from Brewfile (Mac)
make linux-packages    # install packages on Ubuntu/Debian (Linux)
make brew-check        # show what's in Brewfile but not installed (Mac)
make brew-cleanup      # show brew packages not in Brewfile (dry-run)
make macos-defaults    # apply macOS preferences (Mac)
make update            # git pull + re-apply (chezmoi update)
make reg-refresh       # rebuild register inventory
make vscode-ext        # install all VS Code extensions
```

## gh CLI cheatsheet

| Command                                               | Alias   | What it does                                 |
| ----------------------------------------------------- | ------- | -------------------------------------------- |
| `gh auth login`                                     | —      | Authenticate (do this once per machine)      |
| `gh auth status`                                    | —      | See which accounts are logged in             |
| `gh auth switch`                                    | —      | Switch active account                        |
| `gh repo create <name> --private --source=. --push` | —      | Create + push a new repo from current folder |
| `gh repo clone owner/repo`                          | —      | Clone with correct auth                      |
| `gh pr create --fill`                               | `ghc` | Open a PR from the current branch            |
| `gh pr status`                                      | `ghs` | PRs needing your attention                   |
| `gh pr list`                                        | `ghl` | All open PRs in this repo                    |
| `gh pr view --web`                                  | `ghv` | Open current PR in browser                   |
| `gh issue list --assignee @me`                      | `ghi` | Your open issues                             |
| `gh ssh-key add ~/.ssh/id_ed25519.pub -t "name"`    | —      | Register an SSH key                          |

## reg-tool reference

After bootstrap and editing `~/.config/reg-tool/config`:

| Command                 | What it does                                                       |
| ----------------------- | ------------------------------------------------------------------ |
| `reg-refresh`         | Rebuild inventory from local SQLite                                |
| `reg-refresh remote`  | Rebuild from SQLite on the jump box                                |
| `reg`                 | fzf-pick a register → pick an action (ssh/vnc/rdp/web/log/status) |
| `reg-multi`           | Pick many registers, run one command on all                        |
| `reg-store 1234`      | Filter the picker to one store                                     |
| `reg-tmux-store 1234` | tmux session with one pane per register                            |
| `reg-tmux-pair <ip>`  | Two-pane tmux: SSH + tail of log                                   |
| `reg-tunnels`         | List active SSH tunnels                                            |
| `reg-tunnels-kill`    | Close all active tunnels                                           |

## Adding new GUI apps

Edit `mac/Brewfile`:

```ruby
cask "new-app-name"
```

Find the cask name: `brew search new-app` or `brew info --cask new-app`. Then `make brew` installs it.

## Troubleshooting

**`fatal: protocol 'git@https' is not supported`** — the remote URL is malformed (mixed SSH + HTTPS):

```bash
git remote set-url origin https://github.com/gregorybeal/dotfiles.git
```

**`Permission denied (publickey)` on GitHub git operations** — you cloned via SSH but don't have an SSH key for GitHub. With this setup, you should be using HTTPS:

```bash
gh auth login
git remote set-url origin https://github.com/gregorybeal/dotfiles.git
```

**`gh auth login` worked but `git push` still asks for password** — `gh` wasn't set as the credential helper:

```bash
gh auth setup-git
```

**`getsockname failed: Not a socket`** — ControlMaster enabled on Windows. Set `sshVariant = "windows"` in `~/.config/chezmoi/chezmoi.toml` and re-run `chezmoi apply`.

**Oh My Zsh prompt has missing symbols/icons** — install a Nerd Font and set it as your terminal font.

**`reg` command not found** — your shell didn't source `reg-tool/reg.sh`. Check that `~/.config/reg-tool/reg.sh` exists and that your `.zshrc` is applied (`chezmoi apply`).

**Windows `bootstrap.ps1` says "symlink creation requires admin"** — run PowerShell as administrator, OR enable Developer Mode (Settings → Privacy & security → For developers → Developer Mode).

**VS Code extensions didn't install** — `code` CLI wasn't in PATH yet because VS Code was just installed. Close + reopen shell, then `make vscode-ext`.

**`chezmoi apply` errors on jiratui config** — 1Password isn't signed in or `op` CLI isn't available. All other files still apply fine; run `chezmoi apply` again after signing in to 1Password.
