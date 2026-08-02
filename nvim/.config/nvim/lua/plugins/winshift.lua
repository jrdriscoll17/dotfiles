return {
  "sindrets/winshift.nvim",
  config = function()
    vim.keymap.set("n", "<A-w>", ":Winshift<CR>", {desc="Starts WinShift mode"})
  end
}
