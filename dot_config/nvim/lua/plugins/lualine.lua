return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Each of the three colorschemes ships a lualine theme under its own
		-- name, so the generated theme.lua picks the status line too.
		require("lualine").setup({ options = { theme = require("theme").colorscheme } })
	end,
}
