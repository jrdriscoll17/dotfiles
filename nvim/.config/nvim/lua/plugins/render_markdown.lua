return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  opts = {
    -- Un-render the block under the cursor so it's editable as raw text
    anti_conceal = { enabled = true },
    code = { width = "block", right_pad = 2 },
    heading = { width = "block" },
  },
}
