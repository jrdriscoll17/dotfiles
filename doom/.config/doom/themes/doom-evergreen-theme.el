;;; doom-evergreen-theme.el --- soft moss and bark -*- lexical-binding: t; no-byte-compile: t; -*-
;;
;; Hand-written to match the Evergreen palette in ~/.config/theme (Everforest
;; derived), so Emacs, nvim, the terminals and the Quickshell bar all draw from
;; the same hexes. Keep in sync with themes/evergreen.json — nothing generates
;; this file.
;;
;;; Code:

(require 'doom-themes)

(defgroup doom-evergreen-theme nil
  "Options for the `doom-evergreen' theme."
  :group 'doom-themes)

(defcustom doom-evergreen-padded-modeline doom-themes-padded-modeline
  "If non-nil, adds a 4px padding to the mode-line.
Can be an integer to determine the exact padding."
  :group 'doom-evergreen-theme
  :type '(choice integer boolean))

(def-doom-theme doom-evergreen
  "A low-glare forest theme: muted moss and bark surfaces under warm off-white
text, with desaturated accents that stay readable for long sittings."
  :family 'doom-evergreen
  :background-mode 'dark

  ;; name        default   256           16
  ((bg         '("#2d353b" "black"       "black"        ))
   (bg-alt     '("#232a2e" "black"       "black"        ))
   (base0      '("#1e2326" "black"       "black"        ))
   (base1      '("#272e33" "#1e1e1e"     "brightblack"  ))
   (base2      '("#343f44" "#2e2e2e"     "brightblack"  ))
   (base3      '("#3d484d" "#262626"     "brightblack"  ))
   (base4      '("#475258" "#3f3f3f"     "brightblack"  ))
   (base5      '("#7a8478" "#525252"     "brightblack"  ))
   (base6      '("#93a08f" "#6b6b6b"     "brightblack"  ))
   (base7      '("#9da9a0" "#979797"     "brightblack"  ))
   (base8      '("#e8dfc7" "#dfdfdf"     "white"        ))
   (fg         '("#d3c6aa" "#bfbfbf"     "brightwhite"  ))
   (fg-alt     '("#c0b498" "#2d2d2d"     "white"        ))

   (grey       base4)
   (red        '("#e67e80" "#ff6655"     "red"          ))
   (orange     '("#e69875" "#dd8844"     "brightred"    ))
   (green      '("#a7c080" "#99bb66"     "green"        ))
   (teal       '("#83c092" "#44b9b1"     "brightgreen"  ))
   (yellow     '("#dbbc7f" "#ECBE7B"     "yellow"       ))
   (blue       '("#7fbbb3" "#51afef"     "brightblue"   ))
   (dark-blue  '("#5f8c8a" "#2257A0"     "blue"         ))
   (magenta    '("#d699b6" "#c678dd"     "magenta"      ))
   (violet     '("#d699b6" "#a9a1e1"     "brightmagenta"))
   (cyan       '("#83c092" "#46D9FF"     "brightcyan"   ))
   (dark-cyan  '("#5f8c8a" "#5699AF"     "cyan"         ))

   ;; face categories -- required for all themes
   (highlight      green)
   (vertical-bar   base3)
   (selection      base4)
   (builtin        green)
   ;; Everforest's own grey1, lifted a little: the point of the rebuild was
   ;; comments that stay legible rather than dissolving into the background.
   (comments       base6)
   (doc-comments   (doom-lighten base6 0.15))
   (constants      orange)
   (functions      green)
   (keywords       red)
   (methods        green)
   (operators      orange)
   (type           yellow)
   (strings        teal)
   (variables      fg)
   (numbers        magenta)
   (region         base4)
   (error          red)
   (warning        yellow)
   (success        green)
   (vc-modified    yellow)
   (vc-added       green)
   (vc-deleted     red)

   ;; custom categories
   (hidden     `(,(car bg) "black" "black"))
   (-modeline-pad
    (when doom-evergreen-padded-modeline
      (if (integerp doom-evergreen-padded-modeline) doom-evergreen-padded-modeline 4)))

   (modeline-fg     fg)
   (modeline-fg-alt base5)
   (modeline-bg     base2)
   (modeline-bg-l   base2)
   (modeline-bg-inactive   base1)
   (modeline-bg-inactive-l base1))

  ;;;; Base theme face overrides
  ((fringe :background bg :foreground base4)
   ((line-number &override) :foreground base5)
   ((line-number-current-line &override) :foreground green :weight 'bold)
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
   (markdown-header-face :inherit 'bold :foreground green)
   ((markdown-code-face &override) :background base1)
   ;;;; org <built-in>
   (org-hide :foreground hidden)
   ((org-block &override) :background base1)
   ((org-block-begin-line &override) :background base1 :foreground comments)
   ;;;; solaire-mode
   (solaire-mode-line-face :inherit 'mode-line :background modeline-bg-l)
   (solaire-mode-line-inactive-face :inherit 'mode-line-inactive :background modeline-bg-inactive-l)))

;;; doom-evergreen-theme.el ends here
