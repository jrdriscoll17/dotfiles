return {
  "folke/zen-mode.nvim",
  opts = {},
  config = function()
    require("zen-mode").setup({
      vim.keymap.set("n", "zz", ":ZenMode<CR>", {desc = "Starts zen mode"})
    })
  end,
}
