;; -*- no-byte-compile: t; -*-
;;; packages.el
;; Extra packages beyond Doom modules. `doom sync` after editing.

;; treesitter-based structural textobjects (nvim-treesitter-textobjects).
;; Doom's :editor evil gives evil-surround/commentary; this adds `if`/`af`,
;; `ic`/`ac` (function/class) tree-sitter text objects.
(package! evil-textobj-tree-sitter)

;; winshift.nvim analog: move buffers between windows (SPC w for the rest is
;; already provided by evil/doom).
(package! buffer-move)

;; treesj (split/join) analog. Not tree-sitter based, but toggles collapsing a
;; multiline construct <-> single line. Closest available in Emacs.
;; Uncomment if you want it:
;; (package! evil-matchit)

;; Svelte + Tailwind: web-mode (via :lang web) covers svelte templates; the
;; svelte language server is handled by lsp-mode automatically. No extra pkg.

;; templ (a-h/templ): Go HTML templating. Doom has no :lang module for it, so
;; pull the tree-sitter major mode from MELPA. LSP client is registered by hand
;; in config.el (lsp-mode ships no templ client). The `templ` CLI provides both
;; codegen and the language server (`templ lsp`); install with
;; `go install github.com/a-h/templ/cmd/templ@latest`.
(package! templ-ts-mode)
