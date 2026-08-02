return {
  "stevearc/oil.nvim",
  opts = {},
  config = function()
    require("oil").setup({
      columns = {},
      keymaps = {
        ["<leader>e"] = "actions.open_cwd",
        ["<Esc>"] = { callback = "actions.close", mode = "n" },
      },
      watch_for_changes = true,
      float = { padding = 10, win_options = { winblend = 0 } },
      vim.keymap.set("n", "<leader>e", ":Oil --float<CR>"),
    })
  end,
}
