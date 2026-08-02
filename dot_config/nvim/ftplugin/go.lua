-- Go uses hard tabs (gofmt enforces this), so turn off expandtab for Go buffers.
vim.bo.expandtab = false
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4

-- Inlay hints disabled (uses the `hints` settings configured for gopls).
vim.lsp.inlay_hint.enable(false, { bufnr = 0 })

-- On save: organize imports (add/remove/sort) then gofmt via gopls.
vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = 0,
  callback = function()
    -- Ask gopls for the "organize imports" code action and apply it synchronously.
    local params = vim.lsp.util.make_range_params(0, "utf-8")
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
    for _, res in pairs(result or {}) do
      for _, action in pairs(res.result or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
        end
      end
    end
    -- Then format the buffer (gofumpt, since we enabled it).
    vim.lsp.buf.format({ async = false, timeout_ms = 2000 })
  end,
})
