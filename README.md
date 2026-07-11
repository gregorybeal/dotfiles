# dotfiles

Personal config for shell, tmux, git, SSH, terminals, and VS Code. Managed with [GNU Stow](https://www.gnu.org/software/stow/). Works on Mac, Linux, and WSL. (Native Windows is no longer supported — use WSL.)

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
make setup-local    # (re-)create machine-local config (git identity, jira-cli config)
make brew           # update Mac apps from Brewfile
```

**Edit a config file directly** (it's just a symlink back into this repo):
```bash
$EDITOR ~/.tmux.conf   # or ~/.gitconfig, ~/.config/starship.toml, etc.
                        # editing the symlink target edits the file in this repo directly
```

## How it works

Each top-level directory is a **Stow package** whose contents mirror `$HOME`. `stow <package>` (run from this directory) symlinks everything inside `<package>/` into the matching path under `$HOME`. For example, `git/.gitconfig` becomes a symlink at `~/.gitconfig`. Everything you see under `~/.config/...` (or `~/.zshrc`, `~/.gitconfig`, etc.) for a stowed tool is a symlink pointing back into this repo — edit it in place, `git commit`, done.

**zsh deliberately isn't under `~/.config/zsh`:** zsh reads exactly one `.zshenv` automatically, resolved via `$ZDOTDIR`-or-`$HOME` *before* that resolution can be redirected — so pointing `ZDOTDIR` at `~/.config/zsh` from within `~/.zshenv` doesn't make zsh go back and re-read a second `.zshenv` from there; it silently never runs. Rather than work around that, `~/.zshenv` and `~/.zshrc` just live where zsh already looks for them by default, same as every other tool in this repo. The supporting files (`plugins.zsh`, `bindings.zsh`, etc.) live in a plain `~/.zsh/` and are `source`d explicitly from `.zshrc`.

**Adopting an existing machine:** Stow refuses to symlink over a real (non-symlink) file that's already there — and it's all-or-nothing per invocation, so *one* conflict (e.g. Ubuntu's default `~/.bashrc`, or a `~/.config/ghostty/config` you set up before adopting this repo) blocks *every* package, not just the conflicting one. `make stow` runs `scripts/adopt-conflicts.sh` first, which detects exactly that case and moves the conflicting real files to `~/.dotfiles-backup/<timestamp>/` (never deletes) before stowing — so `make stow` / `./bootstrap.sh` works the same whether the machine is brand new or already has its own dotfiles.

Adding a new package: create a directory named after the tool, lay out files inside it exactly as they should appear relative to `$HOME` (e.g. `mytool/.config/mytool/config`), then add it to `CORE_PACKAGES` (or `MAC_PACKAGES` for Mac-only tools) in the `Makefile` and run `make stow`.

**Directories Stow doesn't create:** Stow creates whatever directory structure is needed to host the files it's symlinking (e.g. `~/.config/atuin/` gets created automatically because `config.toml` lives there) — but it has no reason to create directories that don't contain a stowed file. A few tools need such directories at runtime for cache/state/sockets they generate themselves (zsh's history file and completion dump, SSH's control sockets). `make dirs` creates those; `make stow` depends on it, so a plain `make stow` (or `./bootstrap.sh`) always covers it. If you ever see zsh history not persisting or SSH connection-sharing not kicking in, run `make dirs` (or check `make doctor`, which verifies all of them exist).

## Layout

```
dotfiles/
├── zsh/                        → ~/.zshenv, ~/.zshrc, ~/.zsh/
├── bash/                       → ~/.bashrc
├── aliases/                    → ~/.aliases.sh          (shared bash + zsh)
├── git/                        → ~/.gitconfig            (identity lives in ~/.gitconfig.local, not here)
├── ssh/                        → ~/.ssh/config
├── tmux/                       → ~/.tmux.conf
├── starship/                   → ~/.config/starship.toml
├── ghostty/                    → ~/.config/ghostty/config
├── atuin/                      → ~/.config/atuin/config.toml
├── btop/                       → ~/.config/btop/btop.conf
├── nvim/                       → ~/.config/nvim/init.lua
├── powershell/                 → ~/.config/powershell/Microsoft.PowerShell_profile.ps1  (pwsh on Mac/Linux/WSL)
├── karabiner/        (Mac only) → ~/.config/karabiner/karabiner.json
├── keyboardcowboy/   (Mac only) → ~/.config/keyboardcowboy/config.json
├── 1password/        (Mac only) → ~/.config/1Password/ssh/agent.toml
│
├── jira/config.example          template copied to ~/.config/.jira/.config.yml by setup-local.sh (not stowed)
├── scripts/
│   ├── setup-local.sh            creates ~/.gitconfig.local and the jira-cli config
│   ├── doctor.sh                  health check (run via `make doctor`)
│   ├── adopt-conflicts.sh         backs up pre-existing real files before `stow` runs (run via `make stow`)
│   └── gen_ssh_registers.py       generates ~/.ssh/conf.d/registers from store_registers.db (run manually — see --help)
├── linux/packages.sh            installs dev tools on Ubuntu/Debian (apt)
├── mac/Brewfile                 installs dev tools + GUI apps on Mac (brew bundle)
├── mac/macos-defaults.sh        applies macOS system preferences
├── mac/enable-touchid-sudo.sh   enables Touch ID for sudo (run via `make touchid`)
├── mac/frtsx-launch.sh          global-hotkey launcher for the frtsx register picker (Ghostty window)
├── mac/alfred/                  Alfred → Royal TSX register/store workflows (see its README)
├── mac/royaltsx/                RoyalJSON dynamic-folder generator for Royal TSX (see its README)
│
├── bootstrap.sh                  new machine setup — Mac + WSL/Linux
└── Makefile                      short commands for common ops
```

The register tooling (fzf pickers `fssh`/`fvnc`/`frtsx`/…, the Alfred workflows,
and the Royal TSX dynamic folder) all share one inventory: the ssh config block
generated by `scripts/gen_ssh_registers.py`, decorated from the inventory
database. The shell side lives in `zsh/.zsh/local-tools.zsh`.

## Machine-specific / secret files (never committed, gitignored)

- `~/.gitconfig.local` — **required**: `[user] name / email / signingkey`. Created by `make setup-local` (prompts on first run).
- `~/.zshrc.local` — extra zsh config (work credentials, machine-specific PATH, etc.)
- `~/.bashrc.local` — extra bash config
- `~/.ssh/config.local` — extra SSH config, included automatically
- `~/.secrets` — env vars / tokens (sourced by both zsh + bash)

## tmux keybindings

The **prefix is `` ` ``** (backtick, remapped from `C-b`). Press it twice to type a literal backtick. Sessions auto-save and restore across reboots (resurrect + continuum), and the left of the status bar shows a `PREFIX` / `COPY` / `Sync` indicator when those modes are active.

**Panes**

| Key | Action |
|-----|--------|
| `` ` `` `\|` / `` ` `` `-` | Split right / split down (inherits current dir) |
| `` ` `` `h` `j` `k` `l` | Move between panes (vim directions) |
| `Ctrl`+`h` `j` `k` `l` | Move between panes **and** nvim splits (no prefix — vim-tmux-navigator) |
| `` ` `` `H` `J` `K` `L` | Resize pane (repeatable) |
| `` ` `` `S` | Toggle synchronized input to **all** panes |
| `` ` `` `f` / `` ` `` `C-f` | Toggle floating pane (floax) / its menu |

**Windows**

| Key | Action |
|-----|--------|
| `` ` `` `c` | New window (inherits current dir) |
| `Alt`+`h` / `Alt`+`l` | Previous / next window (no prefix) |

**Popups & pickers**

| Key | Action |
|-----|--------|
| `` ` `` `g` | Floating scratch shell in the current dir |
| `` ` `` `T` | **sesh** session picker over zoxide dirs + live sessions *(Mac: needs `sesh`)* |
| `` ` `` `Tab` | **extrakto** — fuzzy-grab paths / URLs / words off the screen |
| `` ` `` `u` | fzf over URLs visible in the pane, open one |
| `` ` `` `F` | **tmux-fzf** — fuzzy menu over sessions / windows / panes / commands |
| `` ` `` `m` | **tmux-menus** — popup command menu |
| `` ` `` `P` | **1Password** item picker *(Mac: needs the `op` CLI)* |

**Copy mode (vi-style)**

| Key | Action |
|-----|--------|
| `` ` `` `[` | Enter copy mode |
| `v` / `Ctrl`+`v` | Begin selection / toggle rectangle selection |
| `y` or `Enter` | Copy to system clipboard (OS-aware; falls back to OSC 52 over SSH) |
| Mouse drag | Select and copy |

**Misc**

| Key | Action |
|-----|--------|
| `` ` `` `r` | Reload `~/.tmux.conf` |
| `` ` `` `I` / `U` / `Alt`+`u` | TPM: install / update / remove plugins |
