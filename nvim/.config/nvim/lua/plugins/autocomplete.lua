return {
	{
		"saghen/blink.cmp",
		dependencies = { { "rafamadriz/friendly-snippets" }, { "saghen/blink.compat" } },
		version = "*",
		opts = {
			keymap = { preset = "super-tab" },
			appearance = { nerd_font_variant = "mono" },
			sources = {
				default = { "lsp", "path", "snippets", "buffer", "supermaven" },

				providers = {
					supermaven = {
						name = "supermaven",
						module = "blink.compat.source",
						score_offset = 3,
					},
				},
			},
			completion = {
				menu = { border = "single" },
				documentation = { window = { border = "single" } },
			},
			signature = { window = { border = "single" } },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		opts_extend = { "sources.default" },
	},
}
