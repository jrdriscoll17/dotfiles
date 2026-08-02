;;; config.el -*- lexical-binding: t; -*-
;; Replicating jake's neovim setup in Doom. `doom sync` after editing init.el/
;; packages.el; this file is read on startup (or `SPC h r r` to reload).

;;; ---------------------------------------------------------------------------
;;; Look & feel (onedark deep, transparent, cyan borders)
;;; ---------------------------------------------------------------------------

;; Theme + palette-derived faces come from theme.el, which `theme set <name>`
;; regenerates from ~/.config/theme. doom-one for One Dark; doom-iceblue and
;; doom-evergreen live in themes/ here.
(load! "theme")

;; number + relativenumber
(setq display-line-numbers-type 'relative)

;; transparent = true. GUI Emacs can't be "no background" like a terminal, so we
;; use compositor transparency (Hyprland). Tune 0-100; lower = more see-through.
(add-to-list 'default-frame-alist '(alpha-background . 50))
;; Apply to the initial frame too (guard against daemon startup w/ no frame):
(when (display-graphic-p)
  (set-frame-parameter nil 'alpha-background 50))

;; The background, hl-line, child-frame borders and comment colour that used to
;; be hardcoded here now live in theme.el (loaded above) so they follow the
;; active palette. solaire-default-face is the bg Doom uses in real file
;; buffers, so it is set there too.

;; fillchars eob=" " -> Doom already hides end-of-buffer tildes (no
;; vi-tilde-fringe module), so nothing to do.

(setq doom-font (font-spec :family "UbuntuMono Nerd Font" :size 16)
      ;; doom-modeline segments fall back to the variable-pitch font; point it at
      ;; the same family so the status bar matches instead of using a proportional
      ;; system font.
      doom-variable-pitch-font (font-spec :family "UbuntuMono Nerd Font" :size 16))

;;; ---------------------------------------------------------------------------
;;; Indentation: expandtab, 2 spaces
;;; ---------------------------------------------------------------------------

(setq-default tab-width 2
              indent-tabs-mode nil       ; expandtab
              evil-shift-width 2
              standard-indent 2)

(after! web-mode
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2))
(setq-hook! '(js-mode-hook js-ts-mode-hook typescript-mode-hook
              typescript-ts-mode-hook css-mode-hook css-ts-mode-hook
              json-mode-hook json-ts-mode-hook)
  tab-width 2
  js-indent-level 2
  css-indent-offset 2)

;; Go uses hard tabs (gofmt enforces it) — mirror your ftplugin/go.lua.
(setq-hook! '(go-mode-hook go-ts-mode-hook)
  indent-tabs-mode t
  tab-width 4)

;;; ---------------------------------------------------------------------------
;;; Clipboard (Wayland)
;;; ---------------------------------------------------------------------------
;; pgtk Emacs (emacs-wayland) uses the Wayland clipboard natively, so
;; unnamedplus + wl-clipboard is automatic. If you ever run terminal Emacs and
;; want wl-clipboard, uncomment:
;; (setq wl-copy-process nil)  ; see xclip.el / wl-clipboard integrations

;;; ---------------------------------------------------------------------------
;;; Keybindings (matching your nvim leader maps)
;;; ---------------------------------------------------------------------------
;; Window nav: evil already binds C-w h/j/k/l — matches your <c-w>hjkl remaps.

(map! :leader
      ;; telescope -> vertico/consult
      :desc "Find file"        "f f" #'+vertico/find-file-in-project ; ff
      :desc "Live grep"        "f g" #'+default/search-project        ; fg
      :desc "Buffers"          "f b" #'consult-buffer                 ; fb
      :desc "Help tags"        "f h" #'apropos                        ; fh (help)
      :desc "Recent files"     "SPC" #'consult-recent-file            ; <leader><leader>

      ;; oil.nvim -> floating file browser (child frame). SPC e like <leader>e.
      :desc "File browser (float)" "e" #'+jake/file-browser

      ;; none-ls format -> apheleia/lsp format buffer (your <leader>gf).
      ;; NOTE: SPC g is Doom's magit prefix; format lives under code (SPC c f)
      ;; which is also Doom's native format key.
      :desc "Format buffer"    "c f" #'+format/buffer

      ;; trouble -> diagnostics list. Doom's :checkers syntax uses flycheck
      ;; (lsp feeds it), so use consult-flycheck, not consult-flymake.
      ;; (nvim was <leader>xx; SPC x is a command in Doom, so this lives under
      ;;  the code prefix as SPC c x.)
      :desc "Diagnostics list" "c x" #'consult-flycheck
      :desc "LSP symbols"      "c S" #'consult-lsp-file-symbols)

;; LSP keys matching nvim: K hover, gd definition, <leader>ca code action.
;; Doom already binds K (lookup docs), gd (go to definition) and SPC c a
;; (code action) — so these match with no config. Explicit for clarity:
(after! lsp-mode
  (map! :map lsp-mode-map
        :n "K"       #'lsp-ui-doc-glance
        :n "g d"     #'+lookup/definition
        :leader
        :desc "Code action" "c a" #'lsp-execute-code-action))

;; treesj (split/join) -> no direct pkg; use evil's built-in `SPC m j/s`-ish.
;; If you install evil-matchit or a fold pkg, bind here.

;; winshift.nvim -> buffer-move on A-w (move buffer between windows).
(map! :n "M-w" #'buf-move-right) ; add buf-move-left/up/down as you like

;; zen-mode: your `zz`.
(map! :n "z z" #'+zen/toggle)

;;; ---------------------------------------------------------------------------
;;; SPC e: floating file browser (replaces dired-jump)
;;; ---------------------------------------------------------------------------
;; A dired inside a floating child frame for the current file's directory:
;;   RET / l   visit — a FILE opens in the window you launched from and closes
;;             the float; a DIRECTORY descends into it (stays floating)
;;   - / h     go up one directory (stays floating)
;;   ESC / q   close the float
;; The dired buffer is transient + isolated, so it never clobbers a normal
;; dired you might have open for the same directory. A child frame (not a
;; separate top-level frame) is used so Hyprland doesn't tile it.

(defvar +jake/fb-frame nil "The floating browser's child frame.")
(defvar +jake/fb-origin nil "Window the browser was launched from.")
(defvar +jake/fb-buffer nil "Transient dired buffer shown in the float.")

(defun +jake/fb--quit ()
  "Close the floating browser and return to the launching window."
  (interactive)
  (let* ((frame +jake/fb-frame)
         (had-frame (frame-live-p frame))
         (win +jake/fb-origin)
         (pframe (and (window-live-p win) (window-frame win))))
    ;; Cancel the parent->child input redirection set up at open, so keyboard
    ;; events flow to the parent again. Because the child never took real GTK
    ;; focus, the parent's focused widget was never disturbed — no re-grab, no
    ;; visibility round-trip, no flicker needed.
    (when (frame-live-p pframe)
      (redirect-frame-focus pframe nil)
      (select-frame pframe)
      (when (window-live-p win) (select-window win)))
    (when had-frame
      ;; keep the workspace-delete hook from firing on our transient float
      (let ((delete-frame-functions
             (remq '+workspaces-delete-associated-workspace-h delete-frame-functions)))
        (delete-frame frame)))
    (when (buffer-live-p +jake/fb-buffer) (kill-buffer +jake/fb-buffer))
    (setq +jake/fb-frame nil +jake/fb-buffer nil)))

(defun +jake/fb--open (dir)
  "Show DIR in the floating browser, (re)installing its transient keys."
  (require 'dired)
  ;; `dired-buffers' nil -> force a brand-new, unshared dired buffer.
  (let ((buf (let ((dired-buffers nil))
               (dired-noselect (file-name-as-directory dir)))))
    (when (and (buffer-live-p +jake/fb-buffer) (not (eq buf +jake/fb-buffer)))
      (kill-buffer +jake/fb-buffer))
    (setq +jake/fb-buffer buf)
    (with-current-buffer buf
      (local-set-key (kbd "RET") #'+jake/fb--visit)
      (local-set-key (kbd "-")   #'+jake/fb--up)
      (local-set-key (kbd "q")   #'+jake/fb--quit)
      (local-set-key [escape]    #'+jake/fb--quit)
      ;; buffer-local evil normal-state keys beat evil-collection's dired maps.
      (when (bound-and-true-p evil-local-mode)
        (evil-local-set-key 'normal (kbd "RET") #'+jake/fb--visit)
        (evil-local-set-key 'normal (kbd "l")   #'+jake/fb--visit)
        (evil-local-set-key 'normal (kbd "-")   #'+jake/fb--up)
        (evil-local-set-key 'normal (kbd "h")   #'+jake/fb--up)
        (evil-local-set-key 'normal (kbd "q")   #'+jake/fb--quit)
        (evil-local-set-key 'normal [escape]    #'+jake/fb--quit)))
    (set-window-buffer (frame-selected-window +jake/fb-frame) buf)))

(defun +jake/fb--visit ()
  "Descend into a directory, or open a file in the launching window."
  (interactive)
  (let ((file (ignore-errors (dired-get-file-for-visit))))
    (cond ((null file) nil)
          ((file-directory-p file) (+jake/fb--open file))
          (t (let ((origin +jake/fb-origin))
               (+jake/fb--quit)
               (when (window-live-p origin) (select-window origin))
               (find-file file))))))

(defun +jake/fb--up ()
  "Go up one directory, staying in the float."
  (interactive)
  (+jake/fb--open (file-name-directory (directory-file-name (dired-current-directory)))))

(defun +jake/fb--fit (&rest _)
  "Size the float to ~70%x60% of its parent frame (clamped) and re-center it.
Shrinks to fit a small Emacs frame; re-centers when the frame grows."
  (when (frame-live-p +jake/fb-frame)
    (let ((parent (frame-parameter +jake/fb-frame 'parent-frame)))
      (when (frame-live-p parent)
        (set-frame-size +jake/fb-frame
                        (max 24 (min 100 (round (* (frame-width  parent) 0.7))))
                        (max 8  (min 30  (round (* (frame-height parent) 0.6)))))
        (let ((pw (frame-pixel-width parent)) (ph (frame-pixel-height parent))
              (cw (frame-pixel-width +jake/fb-frame))
              (ch (frame-pixel-height +jake/fb-frame)))
          (set-frame-position +jake/fb-frame
                              (max 0 (/ (- pw cw) 2))
                              (max 0 (/ (- ph ch) 4))))))))

(defun +jake/fb--on-parent-resize (frame)
  "Re-fit the float when its parent FRAME changes size."
  (when (and (frame-live-p +jake/fb-frame)
             (eq frame (frame-parameter +jake/fb-frame 'parent-frame)))
    ;; defer out of redisplay before resizing/moving a frame
    (run-at-time 0 nil #'+jake/fb--fit)))

(add-hook 'window-size-change-functions #'+jake/fb--on-parent-resize)

(defun +jake/file-browser ()
  "Open a floating file browser for the current buffer's directory."
  (interactive)
  (when (frame-live-p +jake/fb-frame) (delete-frame +jake/fb-frame))
  (setq +jake/fb-origin (selected-window))
  (let* ((parent (selected-frame))
         (dir (or (and buffer-file-name (file-name-directory buffer-file-name))
                  default-directory))
         ;; Stop Doom/persp-mode from giving this child frame its own workspace
         ;; (that's what caused the phantom "#1" workspace + stuck cursor).
         (persp-interactive-init-frame-behaviour-override #'ignore)
         (persp-emacsclient-init-frame-behaviour-override #'ignore)
         (frame (make-frame
                 `((parent-frame . ,parent)
                   (minibuffer . nil)
                   (undecorated . t)
                   (skip-taskbar . t)
                   (no-other-frame . t)
                   (unsplittable . t)
                   ;; Give the float its OWN look, distinct from the pure-black
                   ;; editor: doom-one's grey (#282c34), fully opaque (no
                   ;; see-through). Tune both knobs:
                   ;;   background-color -> the grey    alpha-background -> 0..100
                   (background-color . "#282c34")
                   (alpha-background . 100)
                   (width . 90) (height . 28)
                   (internal-border-width . 2)
                   (left-fringe . 8) (right-fringe . 8)
                   (vertical-scroll-bars . nil)
                   (horizontal-scroll-bars . nil)))))
    (setq +jake/fb-frame frame)
    ;; Paint the float grey. The buffer text is drawn with solaire-mode's remap
    ;; (default -> solaire-default-face, both globally #000000), so a buffer-local
    ;; face-remap or the frame's background-color param can't win. A FRAME-LOCAL
    ;; face attribute does: it overrides the global face for this frame only,
    ;; leaving the black editor untouched. Cover both the base and solaire faces.
    (dolist (f '(default solaire-default-face))
      (when (facep f) (set-face-background f "#282c34" frame)))
    (dolist (f '(hl-line solaire-hl-line-face))
      (when (facep f) (set-face-background f "#323844" frame)))
    (+jake/fb--fit)                       ; size + center relative to parent
    (+jake/fb--open dir)
    ;; Route keyboard input to the float WITHOUT taking real OS/GTK focus.
    ;; `select-frame-set-input-focus' grabs focus onto the child's GTK window;
    ;; when the child is later destroyed, pgtk leaves the parent toplevel with no
    ;; focused GTK widget, so it silently drops every key but the arrows. Instead
    ;; redirect the parent's focus to the child: the parent keeps its Wayland/GTK
    ;; focus the whole time, Emacs routes events (and the active cursor) to the
    ;; child via the redirection, and closing the float needs no focus recovery.
    (redirect-frame-focus parent frame)
    (select-frame frame)
    (select-window (frame-selected-window frame))))

;; ESC closes the float the Doom-native way (in addition to the buffer-local
;; ESC key), so it works from any evil state. Named (not an anonymous lambda) so
;; `add-hook' is idempotent — reloading config.el won't stack duplicate copies.
(defun +jake/fb--escape-h ()
  "Close the floating browser on ESC; return non-nil so `doom/escape' stops."
  (when (frame-live-p +jake/fb-frame) (+jake/fb--quit) t))
(add-hook 'doom-escape-hook #'+jake/fb--escape-h)

;;; ---------------------------------------------------------------------------
;;; :q on the last window -> dashboard instead of quitting Emacs
;;; ---------------------------------------------------------------------------
;; Splits and extra frames still close as usual. To actually exit Emacs, use
;; :qa / :wqa or SPC q q (evil-quit-all / doom/quit) — those are untouched.

(defun +jake/real-frames ()
  "Visible GUI frames the user actually sees.
Excludes child frames (the file-browser float) and, crucially for the
daemon setup, the hidden non-graphical frame `emacs --daemon' keeps around."
  (seq-filter (lambda (f)
                (and (not (frame-parameter f 'parent-frame)) ; not a child frame
                     (frame-parameter f 'visibility)         ; visible
                     (display-graphic-p f)))                 ; GUI, not the daemon tty frame
              (frame-list)))

(defun +jake/quit-to-dashboard-a (orig &rest args)
  "Around advice for `evil-quit': show the dashboard on the last window."
  (if (and (one-window-p t)
           (= 1 (length (+jake/real-frames))))
      ;; `doom-fallback-buffer' is the dashboard ("*doom*") when the
      ;; doom-dashboard module is active; core function, always defined.
      (progn (delete-other-windows)
             (switch-to-buffer (doom-fallback-buffer)))
    (apply orig args)))

(advice-add 'evil-quit :around #'+jake/quit-to-dashboard-a)

;;; ---------------------------------------------------------------------------
;;; LSP servers (your nvim lsp list) + gopls settings
;;; ---------------------------------------------------------------------------
;; The :lang modules auto-start these servers when you open a matching file:
;;   go(gopls) json ts/js(ts-ls) lua(lua_ls) ruby(ruby-lsp) web(html/css/
;;   svelte/tailwindcss). Install the servers via `M-x lsp-install-server` or
;;   your package manager; Doom prompts you on first open.

;; inline diagnostics like tiny-inline-diagnostic (lsp-ui sideline).
(after! lsp-ui
  (setq lsp-ui-sideline-enable t
        lsp-ui-sideline-show-diagnostics t
        lsp-ui-sideline-show-hover nil
        lsp-ui-sideline-show-code-actions nil
        lsp-ui-doc-enable t
        lsp-ui-doc-position 'at-point))

;; gopls settings mirroring your plugins/lsp.lua + ftplugin/go.lua.
(after! lsp-go
  (setq lsp-go-use-gofumpt t                 ; gofumpt = true
        lsp-go-analyses '((unusedparams . t) ; analyses {...}
                          (unusedwrite . t)
                          (nilness . t))))
(after! lsp-mode
  ;; staticcheck = true (not exposed as a var; register directly).
  (lsp-register-custom-settings '(("gopls.staticcheck" t t)))
  ;; Inlay hints: OFF, matching `vim.lsp.inlay_hint.enable(false)`.
  (setq lsp-inlay-hint-enable nil))

;; On save in Go: organize imports (source.organizeImports) + gofumpt format,
;; matching your ftplugin/go.lua BufWritePre autocmd.
(defun +jake/go-before-save ()
  (when (memq major-mode '(go-mode go-ts-mode))
    (lsp-organize-imports)))
(add-hook! '(go-mode-hook go-ts-mode-hook)
  (add-hook 'before-save-hook #'+jake/go-before-save nil t))
;; Doom's (format) module (apheleia) handles gofumpt-on-save via lsp.

;;; ---------------------------------------------------------------------------
;;; Dart / Flutter
;;; ---------------------------------------------------------------------------
;; :lang (dart +lsp +flutter +tree-sitter) gives dart-ts-mode, lsp-dart (the
;; analysis server that ships with the SDK) and flutter.el (run/hot-reload).
;; Requires the Flutter SDK on PATH — `sudo pacman -S flutter-bin` (chaotic-aur;
;; it bundles the Dart SDK, so don't also install the `dart` package or lsp-dart
;; may pick the wrong SDK).

;; Dart style is 2 spaces (already the global default) and `dart format` wraps
;; at 80; keep the LSP's formatter in agreement.
(after! lsp-dart
  (setq lsp-dart-line-length 80
        ;; Flutter widget guides + closing labels ("// Column") in the buffer —
        ;; the main reason to use lsp-dart over a plain LSP client.
        lsp-dart-closing-labels t
        lsp-dart-outline nil          ; no side outline buffer
        lsp-dart-flutter-outline nil))

;; dart-ts-mode's font-lock queries track UserNobody14's grammar and reference
;; Dart 3 node types (`rethrow_builtin', `part_of_builtin', the `base'/`sealed'/
;; `when' keywords). Against an older libtree-sitter-dart.so the whole query
;; fails to compile and you get a *silently* unhighlighted buffer — no error,
;; just plain text. Register the source so `M-x treesit-install-language-grammar'
;; rebuilds from the right repo.
(after! treesit
  (add-to-list 'treesit-language-source-alist
               '(dart "https://github.com/UserNobody14/tree-sitter-dart")))

;; Same tree-sitter mismatch on the LSP side: `lsp-language-id-configuration'
;; only knows `dart-mode', so opening a .dart file in `dart-ts-mode' warns
;; "Unable to calculate the languageId" and the server gets no language id.
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(dart-ts-mode . "dart")))

;; The module binds its localleader menus to `dart-mode-map', but +tree-sitter
;; opens .dart files in `dart-ts-mode', whose keymap does NOT inherit that one —
;; so SPC m f/t/h would be dead. Re-bind them onto dart-ts-mode-map.
(map! :after dart-ts-mode
      :map dart-ts-mode-map
      :localleader
      (:prefix ("f" . "flutter")
       "f" #'flutter-run
       "q" #'flutter-quit
       "r" #'flutter-hot-reload
       "R" #'flutter-hot-restart)
      (:prefix ("t" . "test")
       "t" #'lsp-dart-run-test-at-point
       "a" #'lsp-dart-run-all-tests
       "f" #'lsp-dart-run-test-file
       "l" #'lsp-dart-run-last-test
       "v" #'lsp-dart-visit-last-test))

;;; ---------------------------------------------------------------------------
;;; templ (a-h/templ) — tree-sitter major mode + LSP
;;; ---------------------------------------------------------------------------
;; templ-ts-mode (from packages.el) provides the major mode + auto-mode-alist
;; for .templ. It needs three tree-sitter grammars: `go` (already installed),
;; plus `javascript` and `templ`. NOTE: this Emacs build does NOT bundle the
;; javascript grammar, and templ-ts-mode errors out on that *before* it can
;; offer to install the templ grammar — so register both sources here and let
;; it auto-install. `M-x treesit-install-language-grammar` also works off this.
(after! treesit
  (dolist (src '((javascript . ("https://github.com/tree-sitter/tree-sitter-javascript"))
                 (templ      . ("https://github.com/vrischmann/tree-sitter-templ"))))
    (add-to-list 'treesit-language-source-alist src)))
(setq templ-ts-mode-grammar-install 'auto)

;; templ-ts-mode ships `(add-to-list 'auto-mode-alist ...)` via an autoload, but
;; Doom's loaddef generator strips bare side-effecting forms — only the function
;; autoload survives. So .templ files open in fundamental-mode (no mode -> no
;; hook -> no tree-sitter, no LSP). Register the association ourselves.
(add-to-list 'auto-mode-alist '("\\.templ\\'" . templ-ts-mode))

;; Make sure Emacs can find go-install'd binaries (templ, gopls) even when
;; launched from a desktop session that never sourced your fish PATH.
(let ((gobin (expand-file-name "~/go/bin")))
  (when (file-directory-p gobin)
    (add-to-list 'exec-path gobin)
    (setenv "PATH" (concat gobin path-separator (getenv "PATH")))))

;; lsp-mode has no built-in templ client — register one. The server is the
;; templ CLI itself, invoked as `templ lsp`.
(after! lsp-mode
  (add-to-list 'lsp-language-id-configuration '(templ-ts-mode . "templ"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("templ" "lsp"))
    :activation-fn (lsp-activate-on "templ")
    :server-id 'templ-lsp
    :priority 0)))

;; Start LSP + configure indentation when a .templ buffer opens.
(add-hook 'templ-ts-mode-hook #'lsp!)

;;; ---------------------------------------------------------------------------
;;; Dired (oil.nvim analog) — hidden-files toggle
;;; ---------------------------------------------------------------------------
;; Doom enables `dired-omit-mode' by default (its localleader `SPC m h' toggles
;; it). Fold two more things into that "hidden files" set so `g .' hides them
;; like oil.nvim's toggle_hidden:
;;   - dotfiles (.env, .gitignore, …)   -> the usual "hidden files"
;;   - *_templ.go                       -> templ-generated Go (gitignored noise)
(after! dired-x
  (setq dired-omit-files
        (concat dired-omit-files
                "\\|^\\.[^.]"         ; dotfiles (but not . or ..)
                "\\|_templ\\.go\\'"))) ; templ-generated Go
;; g . toggles hidden files (evil normal state), matching oil.nvim.
(map! :map dired-mode-map
      :n "g ." #'dired-omit-mode)

;; Show only icon + filename — no permissions/owner/size/date columns. Doom's
;; default omits the `dired' scene (a plain `dired-*'-opened directory, i.e. how
;; the file browser opens), so those `ls -l' columns stay visible there; `t'
;; enables `dired-hide-details-mode' in every dirvish scene. Toggle per-buffer
;; with `(' if you ever want the columns back.
(after! dirvish
  (setq dirvish-hide-details t))

;;; ---------------------------------------------------------------------------
;;; Formatters (none-ls: stylua, prettier, rubocop)
;;; ---------------------------------------------------------------------------
;; The :editor format (apheleia) module runs these on save when the binaries are
;; on PATH: stylua (lua), prettier (js/ts/css/html/svelte/json), rubocop (ruby).
;; apheleia ships formatter definitions for all of these out of the box.
(setq +format-on-save-disabled-modes '(sql-mode tex-mode latex-mode)) ; keep others on

;;; ---------------------------------------------------------------------------
;; Markdown preview: render GitHub-flavored markdown with pandoc, offline.
;; `C-c C-c l` toggles markdown-live-preview-mode (renders into an eww split
;; inside Emacs; re-renders on save/edit). `C-c C-c p` opens a one-shot
;; render. Needs `pandoc` on PATH (sudo pacman -S pandoc).
(after! markdown-mode
  (setq markdown-command "pandoc --from=gfm --to=html5 --standalone --quiet"
        ;; keep the preview inside Emacs via eww rather than an external browser
        markdown-live-preview-window-function #'markdown-live-preview-window-eww
        ;; open the preview in a pane to the right, not stacked below
        markdown-split-window-direction 'right
        ;; don't leave the rendered *eww* buffer around after toggling off
        markdown-live-preview-delete-export 'delete-on-export))

(defun +markdown-live-preview-toggle ()
  "Toggle `markdown-live-preview-mode' from either side.
From a markdown buffer this enables the preview (opening the *eww* render in a
pane to the right). From the resulting *eww* preview it finds the source buffer
and turns the preview off."
  (interactive)
  (if (derived-mode-p 'markdown-mode)
      (if (bound-and-true-p markdown-live-preview-mode)
          ;; turning OFF from the source side: remember the preview's window,
          ;; disable the mode (which kills the *eww* buffer), then close the pane
          (let ((win (and (buffer-live-p markdown-live-preview-buffer)
                          (get-buffer-window markdown-live-preview-buffer))))
            (markdown-live-preview-mode -1)
            (when (and (window-live-p win) (not (one-window-p)))
              (delete-window win)))
        (markdown-live-preview-mode 1))
    ;; from inside the *eww* preview: find the source, disable there, close pane
    (let* ((eww-buf (current-buffer))
           (eww-win (get-buffer-window eww-buf))
           (src (seq-find (lambda (b)
                            (eq (buffer-local-value 'markdown-live-preview-buffer b)
                                eww-buf))
                          (buffer-list))))
      (if src
          (progn
            (with-current-buffer src (markdown-live-preview-mode -1))
            (when (and (window-live-p eww-win) (not (one-window-p)))
              (delete-window eww-win)))
        (user-error "No markdown source buffer for this preview")))))

(map! :after markdown-mode
      :localleader
      :map (markdown-mode-map gfm-mode-map)
      :desc "Live preview (toggle)" "p" #'+markdown-live-preview-toggle)

;; Reach the same toggle from inside the eww preview so you can close it there.
(map! :after eww
      :localleader
      :map eww-mode-map
      :desc "Close markdown preview" "p" #'+markdown-live-preview-toggle)

;; Sticky window-management mode: SPC w . drops into a hydra where every key
;; repeats until you press ESC. Arrow keys move between windows.
(defhydra doom-window-hydra (:hint nil)
  "
arrows move   _v_ vsplit  _s_ split   _<_/_>_ width  _-_/_+_ height   _d_ close  _=_ balance   ESC quit
"
  ("<left>"  evil-window-left)   ("<down>"  evil-window-down)
  ("<up>"    evil-window-up)     ("<right>" evil-window-right)
  ("v" evil-window-vsplit)       ("s" evil-window-split)
  ("<" evil-window-decrease-width)  (">" evil-window-increase-width)
  ("-" evil-window-decrease-height) ("+" evil-window-increase-height)
  ("d" evil-window-delete)       ("=" balance-windows)
  ("<escape>" nil))

(map! :leader :desc "Window (sticky)" "w ." #'doom-window-hydra/body)
