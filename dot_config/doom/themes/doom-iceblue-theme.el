;;; doom-iceblue-theme.el --- cold sea and glacier tones -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Hand-written to match the Ice Blue palette in ~/.config/theme, so Emacs, nvim,
;; the terminals and the Quickshell bar all draw from the same hexes. Keep the
;; colours here in sync with themes/ice-blue.json — nothing generates this file.
;;
;;; Code:

(require 'doom-themes)

(defgroup doom-iceblue-theme nil
  "Options for the `doom-iceblue' theme."
  :group 'doom-themes)

(defcustom doom-iceblue-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds a 4px padding to the mode-line.
Can be an integer to determine the exact padding."
  :group 'doom-iceblue-theme
  :type '(choice integer boolean))

(def-doom-theme doom-iceblue
  "A cold, high-contrast theme drawn from a lava-coast photograph: deep sea
navy, glacier blues, and the flow's ember tones reserved for warnings."
  :family 'doom-iceblue
  :background-mode 'dark

  ;; name        default   256           16
  ((bg         '("#0d1720" "black"       "black"        ))
   (bg-alt     '("#08111a" "black"       "black"        ))
   (base0      '("#060e15" "black"       "black"        ))
   (base1      '("#101c26" "#1e1e1e"     "brightblack"  ))
   (base2      '("#16232e" "#2e2e2e"     "brightblack"  ))
   (base3      '("#1f303d" "#262626"     "brightblack"  ))
   (base4      '("#2c4150" "#3f3f3f"     "brightblack"  ))
   (base5      '("#587082" "#525252"     "brightblack"  ))
   (base6      '("#7d99aa" "#6b6b6b"     "brightblack"  ))
   (base7      '("#a7bfcd" "#979797"     "brightblack"  ))
   (base8      '("#e2eef4" "#dfdfdf"     "white"        ))
   (fg         '("#c4d7e2" "#bfbfbf"     "brightwhite"  ))
   (fg-alt     '("#a7bfcd" "#2d2d2d"     "white"        ))

   (grey       base4)
   (red        '("#e5675f" "#ff6655"     "red"          ))
   (orange     '("#e8925c" "#dd8844"     "brightred"    ))
   (green      '("#6fc2a8" "#99bb66"     "green"        ))
   (teal       '("#6fc2a8" "#44b9b1"     "brightgreen"  ))
   (yellow     '("#d8b070" "#ECBE7B"     "yellow"       ))
   (blue       '("#6fadc8" "#51afef"     "brightblue"   ))
   (dark-blue  '("#4d8aa5" "#2257A0"     "blue"         ))
   (magenta    '("#9d92c9" "#c678dd"     "magenta"      ))
   (violet     '("#9d92c9" "#a9a1e1"     "brightmagenta"))
   (cyan       '("#7fd8e8" "#46D9FF"     "brightcyan"   ))
   (dark-cyan  '("#4f96a6" "#5699AF"     "cyan"         ))

   ;; face categories -- required for all themes
   (highlight      cyan)
   (vertical-bar   base3)
   (selection      base4)
   (builtin        blue)
   ;; Deliberately light. Comments sitting near the background is the single
   ;; thing this whole palette was rebuilt to fix.
   (comments       base6)
   (doc-comments   (doom-lighten base6 0.15))
   (constants      orange)
   (functions      cyan)
   (keywords       blue)
   (methods        cyan)
   (operators      fg-alt)
   (type           teal)
   (strings        green)
   (variables      base7)
   (numbers        orange)
   (region         base4)
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    orange)
   (vc-added       green)
   (vc-deleted     red)

   ;; custom categories
   (hidden     `(,(car bg) "black" "black"))
   (-modeline-pad
    (when doom-iceblue-padded-modeline
      (if (integerp doom-iceblue-padded-modeline) doom-iceblue-padded-modeline 4)))

   (modeline-fg     fg)
   (modeline-fg-alt base5)
   (modeline-bg     base2)
   (modeline-bg-l   base2)
   (modeline-bg-inactive   base1)
   (modeline-bg-inactive-l base1))

  ;;;; Base theme face overrides
  ((fringe :background bg :foreground base4)
   ((line-number &override) :foreground base5)
   ((line-number-current-line &override) :foreground cyan :weight 'bold)
   (mode-line
    :background modeline-bg :foreground modeline-fg
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg)))
   (mode-line-inactive
    :background modeline-bg-inactive :foreground modeline-fg-alt
    :box (if -modeline-pad `(:line-width ,-modeline-pad :color ,modeline-bg-inactive)))
   (mode-line-emphasis :foreground highlight)

   ;;;; doom-modeline
   (doom-modeline-bar :background highlight)
   (doom-modeline-project-root-dir :foreground base6)
   ;;;; markdown-mode
   (markdown-markup-face :foreground base5)
   (markdown-header-face :inherit 'bold :foreground blue)
   ((markdown-code-face &override) :background base1)
   ;;;; org <built-in>
   (org-hide :foreground hidden)
   ((org-block &override) :background base1)
   ((org-block-begin-line &override) :background base1 :foreground comments)
   ;;;; solaire-mode
   (solaire-mode-line-face :inherit 'mode-line :background modeline-bg-l)
   (solaire-mode-line-inactive-face :inherit 'mode-line-inactive :background modeline-bg-inactive-l)))

;;; doom-iceblue-theme.el ends here
