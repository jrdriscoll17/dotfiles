;;; init.el -*- lexical-binding: t; -*-
;; Replicating jake's neovim setup. `doom sync` after changing this file.

(doom! :input

       :completion
       (corfu +icons)              ; blink.cmp analog (in-buffer completion)
       (vertico +icons)            ; telescope analog (find-file/grep/buffers)

       :ui
       doom                        ; doom-one theme = Atom One Dark (your onedark)
       doom-dashboard
       hl-todo
       indent-guides               ; indent-blankline analog
       ;;(ligatures +extra)
       modeline                    ; lualine analog (doom-modeline)
       nav-flash
       ophints
       (popup +defaults)
       treemacs
       (vc-gutter +pretty)
       workspaces
       zen                         ; zen-mode analog (SPC t z)

       :editor
       (evil +everything)          ; vim keys; gives evil-surround (nvim-surround)
       file-templates
       fold
       format                      ; apheleia = none-ls formatters (stylua/prettier/rubocop)
       snippets

       :emacs
       (dired +icons)              ; oil.nvim analog
       electric
       (ibuffer +icons)
       undo
       vc

       :term
       vterm

       :checkers
       syntax                      ; flycheck/flymake -> diagnostics

       :tools
       (eval +overlay)
       lookup
       (lsp +peek)                 ; lsp-mode + lsp-ui (your choice)
       magit
       tree-sitter                 ; nvim-treesitter analog

       :lang
       (dart +lsp +flutter +tree-sitter)  ; dart-ts-mode + lsp-dart + flutter.el
       (go +lsp +tree-sitter)
       (json +lsp +tree-sitter)
       (javascript +lsp +tree-sitter)   ; typescript/ts_ls + tsgo
       (lua +lsp +tree-sitter)          ; lua_ls
       (ruby +lsp +tree-sitter)         ; ruby_lsp + rubocop
       (web +lsp +tree-sitter)          ; html + css + svelte + tailwind
       markdown
       (sh +lsp)
       emacs-lisp

       :config
       (default +bindings +smartparens))
