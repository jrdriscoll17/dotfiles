return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Each of the three colorschemes ships a lualine theme under its own
		-- name, so the generated theme.lua picks the status line too. It is
		-- generated, though, so fall back rather than erroring on a machine
		-- where `theme apply` has not run yet.
		local ok, theme = pcall(require, "theme")
		local name = ok and theme.colorscheme or "auto"
		require("lualine").setup({ options = { theme = name } })
	end,
}
