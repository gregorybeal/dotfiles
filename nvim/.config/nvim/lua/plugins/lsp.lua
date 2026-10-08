return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- XML language server — great for your Flooid/DFM XML work.
        -- (LazyVim auto-installs servers listed here via Mason.)
        -- NOTE: lemminx needs a Java runtime on your PATH. See the README.
        lemminx = {},

        -- basedpyright: dial strictness to a sane middle ground while you're
        -- new. Bump typeCheckingMode to "strict" later if you want more rigor.
        basedpyright = {
          mason = false, -- installed with `uv tool install basedpyright` (see mason block below)
          settings = {
            basedpyright = {
              analysis = {
                typeCheckingMode = "standard",
                diagnosticMode = "openFilesOnly", -- don't scan the whole repo
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
              },
            },
          },
        },

        ruff = { mason = false }, -- `uv tool install ruff`
      },
    },
  },

  -- Python tools come from uv, not Mason. Mason builds them with
  -- `python3 -m venv` + pip (which also needs Ubuntu's python3-venv), so
  -- keep it away from them and let the uv-installed binaries on PATH win:
  --   uv tool install basedpyright
  --   uv tool install ruff
  --   uv tool install ansible-lint --with-executables-from ansible-core
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      local uv_managed = { "ansible-lint", "basedpyright", "ruff" }
      opts.ensure_installed = vim.tbl_filter(function(pkg)
        return not vim.tbl_contains(uv_managed, pkg)
      end, opts.ensure_installed or {})
    end,
  },
}
