-- Makes <C-h/j/k/l> move between nvim splits AND tmux panes seamlessly.
-- Requires the matching lines in ~/.tmux.conf (see the README).
return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window/pane" },
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window/pane" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window/pane" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window/pane" },
    },
  },
}
