return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Each of the three colorschemes ships a lualine theme under its own
		-- name, so the generated theme.lua picks the status line too. Read it
		-- fresh — see lua/themeload.lua for why not `require`.
		local theme = require("themeload").get()
		require("lualine").setup({ options = { theme = theme.colorscheme } })
	end,
}
