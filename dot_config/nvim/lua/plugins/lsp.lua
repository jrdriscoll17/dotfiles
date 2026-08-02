return {
	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp" },
		lazy = false,
		config = function()
      vim.lsp.config("gopls", {
        settings = {
          gopls = {
            gofumpt = true, -- stricter formatting than plain gofmt
            staticcheck = true, -- extra lint diagnostics
            analyses = {
              unusedparams = true,
              unusedwrite = true,
              nilness = true,
            },
            hints = { -- inlay hints (needs vim.lsp.inlay_hint.enable, see below)
              parameterNames = true,
              assignVariableTypes = true,
              constantValues = true,
              functionTypeParameters = true,
            },
          },
        },
      })

      vim.lsp.config("vscode-html-languageservice", {})
      vim.lsp.config("vscode-css-languageservice", {})
      vim.lsp.config("vscode-json-languageserver", {})
			vim.lsp.config("svelte", {
				on_attach = function(client)
					vim.api.nvim_create_autocmd("BufWritePost", {
						pattern = { "*.js", "*.ts" },
						callback = function(ctx)
							client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
						end,
					})
				end,
			})

			vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, {})
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
		end,
	},
}
