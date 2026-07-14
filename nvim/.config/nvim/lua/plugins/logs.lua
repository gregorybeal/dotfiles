return {
  -- Syntax highlighting for log files: colors log levels, timestamps, IPs,
  -- hex, MAC addresses, and file paths. Tailored to your filenames below.
  {
    "fei6409/log-highlight.nvim",
    -- Load as soon as any plausible log buffer is read.
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      extension = "log",
      -- Treat these *names* as logs even without a .log extension.
      filename = { "syslog", "messages", "retailErrlog" },
      -- Glob-ish patterns (escape literals with %). Catches rotated/dated logs.
      pattern = {
        "%.log%..*", -- app.log.1, app.log.2025-05-27, etc.
        ".*_log",    -- foo_log
        "%/var%/log%/.*",
      },
      -- Extra tokens to flag, beyond the built-in ERROR/WARN/INFO/DEBUG.
      -- (Case-sensitive.) Tweak freely — just tell me what to add/remove.
      keyword = {
        error = { "Exception", "Traceback", "FATAL", "panic", "Caused by", "stacktrace" },
        warning = { "deprecated", "retrying", "timed out" },
      },
    },
  },

  -- Better quickfix window with an inline preview pane — ideal for stepping
  -- through "all ERRORs across 30 register logs" after a ripgrep sweep.
  { "kevinhwang91/nvim-bqf", ft = "qf", opts = {} },
}
