-- ~/.config/nvim/init.lua — stowed from ~/dotfiles/nvim

-- Vanilla Neovim leaves MsgArea (the ':' command-line / message area)
-- uncoloured — it has no explicit background, so it falls through to the
-- terminal's true default colours. tmux's window-style/window-active-style
-- (see tmux/.tmux.conf) substitute a fixed dark background for anything a
-- program leaves at "default", and if the terminal's actual default
-- foreground happens to be dark too (e.g. Ghostty switched to its light
-- theme), MsgArea's text renders dark-on-dark and disappears. Link it to
-- Normal so it always has an explicit, opaque background.
local function fix_msg_area()
  vim.api.nvim_set_hl(0, "MsgArea", { link = "Normal" })
end

fix_msg_area()
vim.api.nvim_create_autocmd("ColorScheme", { callback = fix_msg_area })
