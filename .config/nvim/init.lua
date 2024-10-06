vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "number"
vim.opt.fillchars = { eob = " " }
vim.g.mapleader = " "

local set = vim.api.nvim_set_keymap

set("n", "<c-w>h", "<c-h>", { noremap = true })
set("n", "<c-w>j", "<c-j>", { noremap = true })
set("n", "<c-w>k", "<c-k>", { noremap = true })
set("n", "<c-w>l", "<c-l>", { noremap = true })
set("n", "<c-w>h", "<c-Left>", { noremap = true })
set("n", "<c-w>j", "<c-Down>", { noremap = true })
set("n", "<c-w>k", "<c-Up>", { noremap = true })
set("n", "<c-w>l", "<c-Right>", { noremap = true })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
