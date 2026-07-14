# Neovim config (LazyVim-based)

A batteries-included Neovim setup built on **LazyVim**, tuned for Python, Lua,
Shell, YAML/Ansible, and XML — and matched to your existing Ghostty + tmux +
Catppuccin environment.

You picked LazyVim as the base, so most of the heavy lifting (LSP, completion,
fuzzy finding, git, formatting) is already wired and maintained upstream. The
files in this repo are the **thin layer of customization on top**: the languages
you care about, an XML server for your DFM work, a log-analysis layer, tmux-aware
navigation, gentler defaults for someone new to modal editing, and your
Catppuccin theme.

---

## 1. Prerequisites

You already have most of these (Ghostty, fzf, ripgrep). Fill any gaps with brew:

```sh
brew install neovim ripgrep fd lazygit fzf
# A Nerd Font for the icons (skip if you already use one in Ghostty/Yazi):
brew install --cask font-jetbrains-mono-nerd-font
# Java runtime — required ONLY for the XML language server (lemminx):
brew install openjdk
# Node — several LSP servers (basedpyright, yamlls, dockerls) are node-based.
# Skip if you already have node/nvm.
brew install node
```

Then set Ghostty to a Nerd Font (`font-family = JetBrainsMono Nerd Font` in
`~/.config/ghostty/config`) so icons render.

> Ansible support also expects `ansible` + `ansible-lint` available. You already
> have ansible from `pos-ansible`; if `ansible-lint` is missing, `pipx install
> ansible-lint` or let Mason install it.

## 2. Install

Back up anything that's already there, then drop this config in:

```sh
# Back up an existing config + state (safe even if they don't exist)
mv ~/.config/nvim{,.bak} 2>/dev/null || true
mv ~/.local/share/nvim{,.bak} 2>/dev/null || true

# Copy this folder into place
cp -R ./nvim ~/.config/nvim

# Launch — first start clones lazy.nvim and installs everything
nvim
```

On first launch lazy.nvim bootstraps itself and pulls every plugin (watch the
progress popup). When it settles:

1. `:LazyHealth` — sanity-check the install and flag missing tools.
2. `:MasonInstall shfmt shellcheck` — the shell formatter + linter (Mason
   auto-installs the LSP servers, but these two CLI tools it doesn't).
3. Restart Neovim.

That's it. Open a `.py` file and you should get completion, diagnostics, and
format-on-save.

## 3. Learning ramp (you're new to modal editing — read this part)

The single best first move: run **`:Tutor`** inside Neovim. It's a 25-minute
built-in interactive lesson and it's the fastest way to stop fighting the editor.

A few orienting facts:

- **Modes.** You start in *Normal* mode (keys are commands, not text). Press `i`
  to *Insert*, `Esc` to go back. `v` enters *Visual* (selection). This feels
  alien for about a week, then it clicks.
- **The leader key is `Space`.** Tap `Space` and **wait** — a `which-key` popup
  shows every command grouped by what it does. This is your map; you don't need
  to memorize anything up front. Lean on it constantly.
- **Don't disable your arrow keys or the mouse.** Both still work here on
  purpose. Ease in; let `hjkl` take over naturally.

Suggested pace:

- **Week 1:** `:Tutor`. Just edit real files. Use `Space` to discover commands.
  Goals: `h j k l`, `i / a / o`, `Esc`, `:w` (save), `dd` (delete line),
  `u` (undo), `/` (search).
- **Week 2:** motions + operators — `w b e` (word), `0 $` (line ends),
  `gg G` (file ends), and combos like `ciw` (change inner word), `dap`
  (delete a paragraph). This grammar is where vim earns its keep.
- **Week 3+:** the IDE layer below — jump to definition, rename, code actions,
  fuzzy finding, lazygit.

## 4. Keymap cheat sheet (LazyVim defaults you'll use early)

All `<leader>` keys are `Space`. Tap `Space` to browse the rest live.

| Keys           | Does                                            |
|----------------|-------------------------------------------------|
| `<C-s>`        | Save file                                       |
| `Space` then wait | Open the which-key command menu              |
| `Space f f`    | Find files (fuzzy)                              |
| `Space /`      | Live grep across the project                    |
| `Space ,`      | Switch between open buffers                     |
| `Space e`      | Toggle the file explorer                        |
| `Space g g`    | Open lazygit                                     |
| `K`            | Hover docs for symbol under cursor              |
| `g d`          | Go to definition                                |
| `g r`          | Find references                                 |
| `Space c a`    | Code action (quick fixes, imports)              |
| `Space c r`    | Rename symbol everywhere                        |
| `Space c f`    | Format file (also runs on save)                 |
| `Space c d`    | Line diagnostics (errors/warnings)              |
| `] d` / `[ d`  | Next / previous diagnostic                      |
| `<C-h/j/k/l>`  | Move between splits **and** tmux panes          |

## 5. tmux integration

The `vim-tmux-navigator` plugin lets `<C-h/j/k/l>` glide between Neovim splits
and tmux panes as if they were one thing. Add the matching half to your
`~/.tmux.conf`:

```tmux
# Smart pane switching with awareness of Neovim splits.
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
  | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'
```

Reload tmux (`tmux source ~/.tmux.conf`) after adding it.

## 6. Per-language notes

- **Python** — `basedpyright` (set in `options.lua`) for analysis + `ruff` for
  lint/format. `Space c v` selects a virtualenv (venv-selector). `Space t t`
  runs the nearest test, `Space t s` shows the test tree (neotest). Strictness
  is set to `"standard"` in `lua/plugins/lsp.lua` — change to `"strict"` when
  you want more.
- **Lua / Shell** — no extra needed; `lua_ls` and `bashls` ship with LazyVim.
  `shellcheck` surfaces shell warnings inline; `shfmt` formats on save
  (2-space, configured in `lua/plugins/formatting.lua`).
- **YAML / Ansible** — `yamlls` auto-detects schemas; the ansible extra adds
  `ansible-language-server` + `ansible-lint`. Playbooks under typical Ansible
  paths get detected automatically.
- **XML** — `lemminx` (needs Java, see prerequisites). Good for Flooid/DFM XML:
  hover, validation, and formatting via the LSP.

## 7. Log analysis

This is tuned for your log-heavy work (PCMS, `retailErrlog`, DFM XML, transaction
tracing). Pull logs down to the Mac and open them here.

- **Highlighting** — `log-highlight.nvim` colors levels, timestamps, IPs, hex,
  and paths. It's wired to recognize `.log`, `*_log`, rotated/dated logs
  (`app.log.1`), and names like `retailErrlog`, `syslog`, `messages`. Extra
  tokens (`Exception`, `Traceback`, `FATAL`, `Caused by`…) are flagged as errors.
  Adjust the keyword/filename lists in `lua/plugins/logs.lua` — just tell me what.
- **Big files** — handled automatically by `snacks.bigfile` (built into LazyVim):
  on large buffers it disables LSP/treesitter/etc. so a 100MB log opens fast.
  Default threshold is ~1.5MB; say the word and I'll change it.
- **Filter a buffer to what matters** (original untouched, re-runnable to narrow):
  - `:LogFilter ERROR` — scratch buffer of only matching lines
  - `:LogFilter \v(ERROR|FATAL)` — Vim regex works (`\v` very-magic, `\c` ignore-case)
  - `:LogFilterOut DEBUG` — strip the noise instead
  - `:LogTail [file]` — live `tail -f` in a terminal split
- **Search across many logs** — `Space s g` live-greps a whole tree (e.g. every
  register's log), `Space s w` greps the word under the cursor. For a quickfix
  sweep, `:grep pattern path/` fills the quickfix and `nvim-bqf` gives an inline
  preview as you step through hits with `] q` / `[ q`.
- **XML / JSON logs** — `lemminx` + JSON schemas give structure; `Space c f`
  pretty-formats a JSON or XML buffer. Want a `:Jq {filter}` command to run a
  selection through `jq`? Say so and I'll add it.

## 8. Extending it

- **Add a plugin:** drop a `.lua` file in `lua/plugins/` returning a spec table.
  lazy.nvim picks it up automatically.
- **Add a language bundle:** run `:LazyExtras`, press `x` on what you want — or
  add an `{ import = "lazyvim.plugins.extras...." }` line to
  `lua/plugins/extras.lua`.
- **Update everything:** `:Lazy sync` (plugins) and `:Mason` (tools).
- **Version it:** `cd ~/.config/nvim && git init` — commit `lazy-lock.json` so
  your plugin versions are reproducible, the same way you pin everything else.

## What's in this repo

```
nvim/
├── init.lua                     bootstraps everything
├── stylua.toml                  formatting for your own Lua
└── lua/
    ├── config/
    │   ├── lazy.lua             lazy.nvim + LazyVim bootstrap (stock)
    │   ├── options.lua          python LSP choice + newcomer-friendly opts
    │   ├── keymaps.lua          a few gentle extra maps
    │   └── autocmds.lua         :LogFilter / :LogFilterOut / :LogTail commands
    └── plugins/
        ├── extras.lua           which LazyVim language/util bundles are on
        ├── lsp.lua              lemminx (XML) + basedpyright tuning
        ├── logs.lua             log highlighting + better quickfix (nvim-bqf)
        ├── formatting.lua       shfmt for shell
        ├── tmux.lua             seamless nvim <-> tmux navigation
        └── colorscheme.lua      Catppuccin Mocha
```
