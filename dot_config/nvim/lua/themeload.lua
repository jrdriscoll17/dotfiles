-- Reads the generated lua/theme.lua, freshly, every time.
--
-- theme.lua is rewritten by `theme set` while nvim is not running, so it is the
-- one module here whose contents change underneath the config. Going through
-- `require` puts it behind Neovim's module cache and lazy's spec cache, and a
-- stale hit there means nvim comes up on the *previous* theme with nothing to
-- indicate why — which is exactly what happened after a theme round-trip, and
-- why `:Lazy U` (which drops those caches) appeared to fix it.
--
-- dofile compiles the file on each call and is not cached, so the values are
-- always what is on disk. It is a few hundred bytes read three times at
-- startup; the cache was never worth the ambiguity.
--
-- This module itself is static, so it is fine for *it* to be cached.

local M = {}

-- Used when theme.lua does not exist yet — a machine where `theme apply` has
-- not run. Values are onedark's, matching the fallback colorscheme.
local fallback = {
	name = "onedark",
	colorscheme = "onedark",
	colors = {
		comment = "#5c6370",
		accent = "#61afef",
		outline = "#3e4451",
	},
}

function M.get()
	local path = vim.fn.stdpath("config") .. "/lua/theme.lua"
	if vim.fn.filereadable(path) == 0 then
		return fallback, "theme.lua has not been generated yet — run `theme apply`"
	end

	local chunk, err = loadfile(path)
	if not chunk then
		return fallback, ("theme.lua failed to parse: %s"):format(err)
	end

	local ok, theme = pcall(chunk)
	if not ok or type(theme) ~= "table" or type(theme.colors) ~= "table" then
		return fallback, ("theme.lua did not return a palette: %s"):format(theme)
	end
	return theme, nil
end

return M
