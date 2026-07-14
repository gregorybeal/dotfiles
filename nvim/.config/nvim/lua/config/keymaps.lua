-- Loaded on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

local map = vim.keymap.set

-- Move by *visual* line when a line wraps, but keep counts literal so 5j
-- still jumps 5 real lines. Helps a lot with long wrapped XML/log lines.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Stay centered when half-paging and when jumping through search matches.
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next match (centered)" })
map("n", "N", "Nzzzv", { desc = "Prev match (centered)" })

-- NOTE: not mapping <leader>w directly — in LazyVim that is the "windows"
-- which-key group. Save with <C-s> (a LazyVim default) instead.
