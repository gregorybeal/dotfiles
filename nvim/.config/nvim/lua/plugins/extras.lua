-- LazyVim "extras" are curated bundles that wire up the right LSP +
-- formatter + linter + extra tools for a language, all known to work
-- together. Importing them here is the version-controlled equivalent of
-- toggling them in the :LazyExtras UI.

return {
  -- ── Languages you asked to fully support ──────────────────────────
  { import = "lazyvim.plugins.extras.lang.python" },   -- basedpyright + ruff + neotest + dap + venv-selector
  { import = "lazyvim.plugins.extras.lang.yaml" },     -- yamlls + automatic schema detection
  { import = "lazyvim.plugins.extras.lang.ansible" },  -- ansible-language-server + ansible-lint
  { import = "lazyvim.plugins.extras.lang.docker" },   -- dockerls + compose (useful around your stack)
  { import = "lazyvim.plugins.extras.lang.toml" },     -- pyproject.toml / ruff.toml / etc.
  { import = "lazyvim.plugins.extras.lang.json" },     -- package.json + JSON schemas
  { import = "lazyvim.plugins.extras.lang.markdown" }, -- READMEs and notes

  -- ── Quality-of-life ───────────────────────────────────────────────
  { import = "lazyvim.plugins.extras.util.dot" },      -- niceties for dotfiles, ssh config, gitconfig, etc.

  -- Lua and Shell/Bash need NO extra: LazyVim ships lua_ls (+ lazydev)
  -- and bashls in its defaults, so those work out of the box.
}
