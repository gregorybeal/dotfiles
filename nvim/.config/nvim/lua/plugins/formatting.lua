return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sh = { "shfmt" },
        bash = { "shfmt" },
        zsh = { "shfmt" },
      },
      formatters = {
        shfmt = {
          -- 2-space indent, indent switch cases, binary ops at line start.
          prepend_args = { "-i", "2", "-ci", "-bn" },
        },
      },
    },
  },
}
