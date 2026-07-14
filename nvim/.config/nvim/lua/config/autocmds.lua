-- Loaded on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- ── Log-analysis commands (Claude maintains the Lua; you just use them) ──
--
--   :LogFilter {pattern}     -> scratch buffer of ONLY lines matching pattern
--   :LogFilterOut {pattern}  -> scratch buffer with matching lines REMOVED
--   :LogTail [file]          -> live `tail -f` in a terminal split
--
-- Patterns use Vim regex (so \v very-magic, \c case-insensitive, etc. work).
-- The original buffer is never modified. Run :LogFilter again *inside* a
-- scratch buffer to narrow further.

local function log_filter(pattern, keep)
  if not pattern or pattern == "" then
    vim.notify("Provide a pattern, e.g. :LogFilter ERROR", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local out = {}
  for _, line in ipairs(lines) do
    local matched = vim.fn.match(line, pattern) >= 0
    if matched == keep then
      out[#out + 1] = line
    end
  end

  vim.cmd("vnew")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
  vim.bo[buf].filetype = "log" -- so log-highlight colors it
  local label = ("[log %s: %s] %d/%d lines"):format(keep and "keep" or "drop", pattern, #out, #lines)
  pcall(vim.api.nvim_buf_set_name, buf, label .. " " .. tostring(vim.uv.hrtime()))
end

vim.api.nvim_create_user_command("LogFilter", function(o)
  log_filter(o.args, true)
end, { nargs = "+", desc = "Scratch buffer of lines matching {pattern}" })

vim.api.nvim_create_user_command("LogFilterOut", function(o)
  log_filter(o.args, false)
end, { nargs = "+", desc = "Scratch buffer with lines matching {pattern} removed" })

vim.api.nvim_create_user_command("LogTail", function(o)
  local file = (o.args ~= "" and o.args) or vim.fn.expand("%:p")
  if file == "" then
    vim.notify("No file to tail", vim.log.levels.WARN)
    return
  end
  vim.cmd("botright split")
  vim.cmd("terminal tail -f " .. vim.fn.fnameescape(file))
  vim.cmd("startinsert")
end, { nargs = "?", complete = "file", desc = "tail -f a log file in a terminal split" })
