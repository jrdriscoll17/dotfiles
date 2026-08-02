return {
  "nvimtools/none-ls.nvim",
  lazy = false,
  dependencies = { "nvimtools/none-ls-extras.nvim" },
  config = function()
    local null_ls = require("null-ls")

    null_ls.setup({
      sources = {
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.prettier,
        null_ls.builtins.formatting.rubocop,
      },
    })

    local format_func = function()
      vim.lsp.buf.format({ async = true, timeout_ms = 2000 })
    end

    vim.keymap.set("n", "<leader>gf", format_func, {})
  end,
}
