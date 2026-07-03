# dotfiles

Personal config for shell, tmux, git, SSH, terminals, VS Code, and the `reg-tool` register management toolkit. Managed with [GNU Stow](https://www.gnu.org/software/stow/). Works on Mac, Linux, and WSL. (Native Windows is no longer supported — use WSL.)

## Quick start

**On a brand new machine (Mac or WSL/Linux):**
```bash
git clone https://github.com/gregorybeal/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap.sh
```

After bootstrap, restart your shell and run:
```bash
gh auth login        # GitHub HTTPS auth — yes to "authenticate git"
make doctor           # verify everything's healthy
```

## Daily commands

```bash
make help          # show all targets
make stow           # (re-)symlink all packages into $HOME — idempotent
make unstow          # remove all package symlinks from $HOME
make update         # git pull + re-stow
make doctor          # health check
make setup-local    # (re-)create machine-local config (git identity, reg-tool config)
make brew           # update Mac apps from Brewfile
```

**Edit a config file directly** (it's just a symlink back into this repo):
```bash
$EDITOR ~/.tmux.conf   # or ~/.gitconfig, ~/.config/starship.toml, etc.
                        # editing the symlink target edits the file in this repo directly
```

## How it works

Each top-level directory is a **Stow package** whose contents mirror `$HOME`. `stow <package>` (run from this directory) symlinks everything inside `<package>/` into the matching path under `$HOME`. For example, `zsh/.config/zsh/.zshrc` becomes a symlink at `~/.config/zsh/.zshrc`. Everything you see under `~/.config/...` for a stowed tool is a symlink pointing back into this repo — edit it in place, `git commit`, done.

Adding a new package: create a directory named after the tool, lay out files inside it exactly as they should appear relative to `$HOME` (e.g. `mytool/.config/mytool/config`), then add it to `CORE_PACKAGES` (or `MAC_PACKAGES` for Mac-only tools) in the `Makefile` and run `make stow`.

**Directories Stow doesn't create:** Stow creates whatever directory structure is needed to host the files it's symlinking (e.g. `~/.config/reg-tool/` gets created automatically because `reg.sh` lives there) — but it has no reason to create directories that don't contain a stowed file. A few tools need such directories at runtime for cache/state/sockets they generate themselves (zsh's history file and completion dump, SSH's control sockets). `make dirs` creates those; `make stow` depends on it, so a plain `make stow` (or `./bootstrap.sh`) always covers it. If you ever see zsh history not persisting or SSH connection-sharing not kicking in, run `make dirs` (or check `make doctor`, which verifies all of them exist).

## Layout

```
dotfiles/
├── zsh/                        → ~/.zshenv, ~/.config/zsh/
├── bash/                       → ~/.bashrc
├── aliases/                    → ~/.aliases.sh          (shared bash + zsh)
├── git/                        → ~/.gitconfig            (identity lives in ~/.gitconfig.local, not here)
├── ssh/                        → ~/.ssh/config
├── tmux/                       → ~/.tmux.conf
├── starship/                   → ~/.config/starship.toml
├── ghostty/                    → ~/.config/ghostty/config
├── atuin/                      → ~/.config/atuin/config.toml
├── btop/                       → ~/.config/btop/btop.conf
├── reg-tool/                   → ~/.config/reg-tool/{reg.sh,refresh.py}
│   └── config.example              (not deployed — copied to ~/.config/reg-tool/config by setup-local.sh)
├── vscode/                     → ~/.config/Code/User/{settings.json,keybindings.json,snippets/}
│   └── extensions.txt              (not deployed — read by `make vscode-ext`)
├── powershell/                 → ~/.config/powershell/Microsoft.PowerShell_profile.ps1  (pwsh on Mac/Linux/WSL)
├── karabiner/        (Mac only) → ~/.config/karabiner/karabiner.json
├── keyboardcowboy/   (Mac only) → ~/.config/keyboardcowboy/config.json
├── 1password/        (Mac only) → ~/.config/1Password/ssh/agent.toml
│
├── scripts/
│   ├── setup-local.sh           creates ~/.gitconfig.local and ~/.config/reg-tool/config
│   └── doctor.sh                 health check (run via `make doctor`)
├── linux/packages.sh            installs dev tools on Ubuntu/Debian (apt)
├── mac/Brewfile                 installs dev tools + GUI apps on Mac (brew bundle)
├── mac/macos-defaults.sh        applies macOS system preferences
│
├── bootstrap.sh                  new machine setup — Mac + WSL/Linux
└── Makefile                      short commands for common ops
```

## Machine-specific / secret files (never committed, gitignored)

- `~/.gitconfig.local` — **required**: `[user] name / email / signingkey`. Created by `make setup-local` (prompts on first run).
- `~/.config/reg-tool/config` — jumpbox, SQLite paths. Created from `reg-tool/config.example` by `make setup-local`.
- `~/.zshrc.local` — extra zsh config (work credentials, machine-specific PATH, etc.)
- `~/.bashrc.local` — extra bash config
- `~/.ssh/config.local` — extra SSH config, included automatically
- `~/.secrets` — env vars / tokens (sourced by both zsh + bash)

## Chezmoi predecessor

This repo replaced a [chezmoi](https://chezmoi.io)-managed setup (still present, untouched, at `~/.local/share/chezmoi` on machines that had it — kept as a historical reference, not actively used). Chezmoi's templating (per-machine git identity, OS-conditional files) has no Stow equivalent; see `~/.gitconfig.local` above for how that's handled instead.
