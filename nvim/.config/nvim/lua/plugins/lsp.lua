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
      },
    },
  },
}
