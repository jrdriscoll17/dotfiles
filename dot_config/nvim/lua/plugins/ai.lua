return {
	"supermaven-inc/supermaven-nvim",
  opts = {
    disable_inline_completion = true,
  },
	config = function()
		require("supermaven-nvim").setup({})
	end,
}
