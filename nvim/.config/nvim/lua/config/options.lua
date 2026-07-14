-- Loaded automatically before lazy.nvim starts.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

local opt = vim.opt
local g = vim.g

-- ── Python (the lang.python extra reads these) ───────────────────────
-- basedpyright is a community fork of pyright with stricter, richer analysis.
g.lazyvim_python_lsp = "basedpyright"
-- Use the modern native `ruff` server (the old `ruff_lsp` is deprecated).
g.lazyvim_python_ruff = "ruff"

-- ── Newcomer-friendly editor behaviour ───────────────────────────────
-- Keep the mouse available as a fallback while vim motions become muscle memory.
opt.mouse = "a"
-- Share the macOS system clipboard, so y/p work with other apps.
opt.clipboard = "unnamedplus"
-- Relative line numbers make motions like 5j / 3k obvious. If the shifting
-- numbers feel disorienting at first, set this to false.
opt.relativenumber = true
opt.number = true
-- A faint ruler at column 100 — handy for long DFM XML / Python lines.
opt.colorcolumn = "100"
-- Ask to save instead of erroring when you close a modified buffer.
opt.confirm = true
-- Treat dash-joined words as one word for w/e/b motions (nice for kebab-case).
opt.iskeyword:append("-")
