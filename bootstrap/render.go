package main

// The theme renderers. Each takes the palette and writes files; live-reload
// side effects live in reloadAll so a dry render stays cheap.
//
// Ported from theme.py. Output is byte-for-byte what the Python renderers
// produced — the formats are consumed by other programs, and several of these
// files are diffed against the repo, so drift would be noise at best.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// writeFile creates parent directories, like Python's write().
func writeFile(path, content string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(content), 0o644)
}

func stripHash(c string) string { return strings.TrimPrefix(c, "#") }

// rgbaColor renders Hyprland's rgba(RRGGBBAA).
func rgbaColor(c string, a float64) string {
	return fmt.Sprintf("rgba(%s%02x)", stripHash(c), int(roundHalfUp(a*255)))
}

// roundHalfUp matches Python's round() for the values used here. Only ever
// called with 255 and 0.93*255 / 0.67*255, none of which land on .5.
func roundHalfUp(f float64) float64 {
	return float64(int(f + 0.5))
}

// subLine rewrites one setting in a config we do not own outright.
func subLine(path, pattern, replacement string) error {
	if !exists(path) {
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	re, err := regexp.Compile("(?m)" + pattern)
	if err != nil {
		return err
	}
	text := string(raw)
	out := re.ReplaceAllLiteralString(text, replacement)
	if out == text {
		return nil
	}
	return os.WriteFile(path, []byte(out), 0o644)
}

// setINIKey sets key=value, creating the file, the section or the key as
// needed. subLine alone silently does nothing when the key is absent, which is
// how a config can end up stranded on the previous theme.
func setINIKey(path, section, key, value string) error {
	line := key + "=" + value
	var text string
	if raw, err := os.ReadFile(path); err == nil {
		text = string(raw)
	}

	keyRe := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + `=`)
	sectionRe := regexp.MustCompile(`(?m)^\[` + regexp.QuoteMeta(section) + `\]`)

	switch {
	case keyRe.MatchString(text):
		full := regexp.MustCompile(`(?m)^` + regexp.QuoteMeta(key) + `=.*$`)
		text = full.ReplaceAllLiteralString(text, line)
	case sectionRe.MatchString(text):
		text = replaceFirstFunc(sectionRe, text, func(m string) string {
			return m + "\n" + line
		})
	default:
		text = strings.TrimLeft(strings.TrimRight(text, " \t\n\r")+
			"\n\n["+section+"]\n"+line+"\n", " \t\n\r")
	}
	return writeFile(path, text)
}

// -- renderers ---------------------------------------------------------------

func renderQuickshell(t *Theme) error {
	var lines []string
	for _, k := range t.Colors.Keys() {
		lines = append(lines, fmt.Sprintf("\treadonly property color %s: \"%s\"", k, t.c(k)))
	}
	return writeFile(inHome(".config/quickshell/generated/Colors.qml"),
		fmt.Sprintf(`pragma Singleton

import Quickshell
import QtQuick

// %s
//
// Theme.qml aliases these, so every widget keeps reading Theme.<colour> and
// only this file changes when the theme does. Quickshell watches its config
// directory, so writing this hot-reloads the bar.
Singleton {
	readonly property string themeName: "%s"
	readonly property string themeLabel: "%s"

%s
}
`, t.banner, t.Name, t.Label, strings.Join(lines, "\n")))
}

var iconRoots = func() []string {
	return []string{inHome(".local/share/icons"), inHome(".icons"), "/usr/share/icons"}
}

// Categories worth indexing: app launchers, notification icons, tray icons.
var iconCategories = []string{"apps", "status", "devices", "places", "actions", "categories"}

// iconThemeChain is a theme plus whatever it inherits, in lookup order, ending
// at hicolor.
func iconThemeChain(name string) []string {
	var chain []string
	seen := map[string]bool{}
	queue := []string{name, "hicolor"}

	for len(queue) > 0 {
		theme := queue[0]
		queue = queue[1:]
		if seen[theme] {
			continue
		}
		seen[theme] = true

		for _, root := range iconRoots() {
			dir := filepath.Join(root, theme)
			if fi, err := os.Stat(dir); err != nil || !fi.IsDir() {
				continue
			}
			chain = append(chain, dir)
			index := filepath.Join(dir, "index.theme")
			raw, err := os.ReadFile(index)
			if err != nil {
				continue
			}
			for _, line := range strings.Split(string(raw), "\n") {
				if after, ok := strings.CutPrefix(line, "Inherits="); ok {
					for _, p := range strings.Split(after, ",") {
						queue = append(queue, strings.TrimSpace(p))
					}
				}
			}
		}
	}
	return chain
}

// sizeRank orders directories so bigger (and scalable) wins: a 512px source
// beats a 16px one for a 34px notification badge.
//
// The @2x suffix counts: "32x32@2x" holds 64px artwork, so it outranks "32x32".
// theme.py stripped the suffix instead, which tied the two and left the winner
// to whatever order the filesystem happened to return directories in — so its
// icons.json was not reproducible across machines. Ranking by effective pixels
// is both deterministic and what "bigger wins" was always meant to say.
func sizeRank(name string) (int, int) {
	if strings.HasPrefix(name, "scalable") {
		return 1, 0
	}
	head, _, _ := strings.Cut(name, "x")
	n, err := strconv.Atoi(head)
	if err != nil {
		return 0, 0
	}
	scale := 1
	if _, after, found := strings.Cut(name, "@"); found {
		digits := after
		if i := strings.IndexFunc(after, func(r rune) bool { return r < '0' || r > '9' }); i >= 0 {
			digits = after[:i]
		}
		if s, err := strconv.Atoi(digits); err == nil && s > 0 {
			scale = s
		}
	}
	return 0, n * scale
}

// sortBySizeDesc mirrors Python's sorted(key=size_rank, reverse=True), which is
// stable, so equal ranks keep directory order.
func sortBySizeDesc(names []string) {
	sort.SliceStable(names, func(i, j int) bool {
		ai, aj := name2rank(names[i]), name2rank(names[j])
		if ai[0] != aj[0] {
			return ai[0] > aj[0]
		}
		return ai[1] > aj[1]
	})
}

func name2rank(n string) [2]int {
	a, b := sizeRank(n)
	return [2]int{a, b}
}

func subdirs(dir string) []string {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		if fi, err := os.Stat(filepath.Join(dir, e.Name())); err == nil && fi.IsDir() {
			out = append(out, e.Name())
		}
	}
	return out
}

// renderIcons indexes icon-name -> file, because Qt inside Quickshell has no
// icon theme. Setting one needs a platform theme plugin (qt6ct or the gtk one),
// neither of which is installed, so Quickshell.iconPath() and image://icon/...
// only ever resolve absolute paths. The shell reads this index instead; see
// services/Icons.qml.
func renderIcons(t *Theme) error {
	out := inHome(".config/quickshell/generated/icons.json")
	marker := inHome(".config/quickshell/generated/icons.theme")
	iconTheme := t.GTK.Icons

	if exists(out) && exists(marker) {
		if raw, err := os.ReadFile(marker); err == nil &&
			strings.TrimSpace(string(raw)) == iconTheme {
			return nil
		}
	}

	// Each theme has its own icon set, so a naive rebuild costs ~1.6s of disk
	// walking on every single switch. Cached per icon theme, that becomes a
	// 2.5MB copy. `theme icons` clears the cache when new apps are installed.
	cache := filepath.Join(cacheDir(), "icons-"+iconTheme+".json")
	if raw, err := os.ReadFile(cache); err == nil {
		if err := writeFile(out, string(raw)); err != nil {
			return err
		}
		return writeFile(marker, iconTheme+"\n")
	}

	index := map[string]string{}
	add := func(path string) {
		stem := strings.TrimSuffix(filepath.Base(path), filepath.Ext(path))
		if _, seen := index[stem]; !seen {
			index[stem] = path
		}
	}
	isIcon := func(name string) bool {
		switch filepath.Ext(name) {
		case ".svg", ".png", ".xpm":
			return true
		}
		return false
	}

	for _, themeDir := range iconThemeChain(iconTheme) {
		// Two layouts in the wild: Papirus nests size/category, the Suru themes
		// nest category/size. Walk both by checking which half of each pair
		// names a category.
		outers := subdirs(themeDir)
		sortBySizeDesc(outers)
		for _, outer := range outers {
			outerPath := filepath.Join(themeDir, outer)

			var innerPaths []string
			if slicesContains(iconCategories, outer) {
				inners := subdirs(outerPath)
				sortBySizeDesc(inners)
				for _, in := range inners {
					innerPaths = append(innerPaths, filepath.Join(outerPath, in))
				}
			} else {
				for _, category := range iconCategories {
					innerPaths = append(innerPaths, filepath.Join(outerPath, category))
				}
			}

			for _, dir := range innerPaths {
				entries, err := os.ReadDir(dir)
				if err != nil {
					continue
				}
				for _, e := range entries {
					if isIcon(e.Name()) {
						add(filepath.Join(dir, e.Name()))
					}
				}
			}
		}
	}

	// Legacy drop-box a lot of third-party packages still use.
	if entries, err := os.ReadDir("/usr/share/pixmaps"); err == nil {
		for _, e := range entries {
			if isIcon(e.Name()) {
				add(filepath.Join("/usr/share/pixmaps", e.Name()))
			}
		}
	}

	payload, err := compactSortedJSON(index)
	if err != nil {
		return err
	}
	if err := writeFile(out, payload); err != nil {
		return err
	}
	if err := writeFile(cache, payload); err != nil {
		return err
	}
	return writeFile(marker, iconTheme+"\n")
}

func slicesContains(haystack []string, needle string) bool {
	for _, h := range haystack {
		if h == needle {
			return true
		}
	}
	return false
}

// compactSortedJSON matches json.dumps(separators=(",", ":"), sort_keys=True).
// Go's encoder sorts map keys and emits no spaces already; HTML escaping is the
// one difference that has to be turned off.
func compactSortedJSON(m map[string]string) (string, error) {
	var b strings.Builder
	enc := json.NewEncoder(&b)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(m); err != nil {
		return "", err
	}
	return strings.TrimRight(b.String(), "\n"), nil
}

func renderKitty(t *Theme) error {
	return writeFile(inHome(".config/kitty/theme.conf"),
		fmt.Sprintf(`# %s

foreground           %s
background           %s
selection_foreground none
selection_background %s

cursor               %s
cursor_text_color    %s

# normal
color0  %s
color1  %s
color2  %s
color3  %s
color4  %s
color5  %s
color6  %s
color7  %s

# bright
color8  %s
color9  %s
color10 %s
color11 %s
color12 %s
color13 %s
color14 %s
color15 %s
`, t.banner,
			t.term("fg"), t.term("bg"), t.term("selectionBg"),
			t.term("cursor"), t.term("bg"),
			t.term("black"), t.c("red"), t.c("green"), t.c("orange"),
			t.c("blue"), t.c("purple"), t.c("cyan"), t.term("white"),
			t.term("brightBlack"), t.c("red"), t.c("green"), t.c("yellow"),
			t.c("blue"), t.c("purple"), t.c("cyan"), t.term("brightWhite")))
}

func renderAlacritty(t *Theme) error {
	x := func(col string) string { return "'0x" + stripHash(col) + "'" }
	return writeFile(inHome(".config/alacritty/colors.toml"),
		fmt.Sprintf(`# %s

[colors.primary]
background = %s
foreground = %s
bright_foreground = %s

[colors.cursor]
text = %s
cursor = %s

[colors.selection]
background = %s
text = 'CellForeground'

[colors.normal]
black =   %s
red =     %s
green =   %s
yellow =  %s
blue =    %s
magenta = %s
cyan =    %s
white =   %s

[colors.bright]
black =   %s
red =     %s
green =   %s
yellow =  %s
blue =    %s
magenta = %s
cyan =    %s
white =   %s
`, t.banner,
			x(t.term("bg")), x(t.term("fg")), x(t.term("brightWhite")),
			x(t.term("bg")), x(t.term("cursor")),
			x(t.term("selectionBg")),
			x(t.term("black")), x(t.c("red")), x(t.c("green")), x(t.c("orange")),
			x(t.c("blue")), x(t.c("purple")), x(t.c("cyan")), x(t.term("white")),
			x(t.term("brightBlack")), x(t.c("red")), x(t.c("green")), x(t.c("yellow")),
			x(t.c("blue")), x(t.c("purple")), x(t.c("cyan")), x(t.term("brightWhite"))))
}

func renderNvim(t *Theme) error {
	var entries []string
	for _, k := range t.Colors.Keys() {
		entries = append(entries, fmt.Sprintf("\t\t%s = \"%s\",", k, t.c(k)))
	}
	return writeFile(inHome(".config/nvim/lua/theme.lua"),
		fmt.Sprintf(`-- %s
--
-- lua/plugins/colorscheme.lua reads this to pick the colorscheme and to patch
-- the handful of highlights (comments, float borders) the shell keeps in sync.
return {
	name = "%s",
	colorscheme = "%s",
	colors = {
%s
	},
}
`, t.banner, t.Name, t.Editors.Nvim, strings.Join(entries, "\n")))
}

func renderDoom(t *Theme) error {
	return writeFile(inHome(".config/doom/theme.el"),
		fmt.Sprintf(`;;; theme.el -*- lexical-binding: t; -*-
;; %s
;;
;; config.el loads this. The face overrides mirror the ones that used to be
;; hardcoded there (true-black background, cyan child-frame borders) but track
;; the active palette instead.

(setq doom-theme '%s)

(custom-set-faces!
  '(default              :background "%s")
  '(solaire-default-face :background "%s")
  '(hl-line              :background "%s")
  '(child-frame-border   :background "%s")
  '(vertical-border      :foreground "%s")
  ;; The reason this file exists: comment contrast. Themes vary in how far
  ;; they sink comments into the background; this pins them at a measured
  ;; ratio against the editor background instead.
  '(font-lock-comment-face :foreground "%s")
  '(font-lock-doc-face     :foreground "%s")
  '(mode-line              :family "UbuntuMono Nerd Font")
  '(mode-line-inactive     :family "UbuntuMono Nerd Font"))
`, t.banner, t.Editors.Doom,
			t.term("bg"), t.term("bg"), t.c("surface"), t.c("accent"), t.c("accent"),
			t.c("comment"), t.c("comment")))
}

func renderHypr(t *Theme) error {
	wallpaper := t.wallpaperPath()

	if err := writeFile(inHome(".config/hypr/hyprpaper.conf"),
		fmt.Sprintf(`# %s

wallpaper {
  monitor =
  path = %s
}

splash = false
`, t.banner, wallpaper)); err != nil {
		return err
	}

	// hyprlock.conf sources this.
	return writeFile(inHome(".config/hypr/colors.conf"),
		fmt.Sprintf(`# %s

$wallpaper = %s

$base = %s
$surface = %s
$outline = %s
$fg = %s
$fgDim = %s
$accent = %s
$blue = %s
$green = %s
$red = %s
$orange = %s
`, t.banner, wallpaper,
			rgbaColor(t.c("base"), 1), rgbaColor(t.c("surface"), 1),
			rgbaColor(t.c("outline"), 1), rgbaColor(t.c("fg"), 1),
			rgbaColor(t.c("fgDim"), 1), rgbaColor(t.c("accent"), 1),
			rgbaColor(t.c("blue"), 1), rgbaColor(t.c("green"), 1),
			rgbaColor(t.c("red"), 1), rgbaColor(t.c("orange"), 1)))
}

func renderBtop(t *Theme) error {
	err := writeFile(filepath.Join(inHome(".config/btop/themes"), t.Name+".theme"),
		fmt.Sprintf(`# %s

theme[main_bg]="%s"
theme[main_fg]="%s"
theme[title]="%s"
theme[hi_fg]="%s"
theme[selected_bg]="%s"
theme[selected_fg]="%s"
theme[inactive_fg]="%s"
theme[graph_text]="%s"
theme[meter_bg]="%s"
theme[proc_misc]="%s"
theme[cpu_box]="%s"
theme[mem_box]="%s"
theme[net_box]="%s"
theme[proc_box]="%s"
theme[div_line]="%s"
theme[temp_start]="%s"
theme[temp_mid]="%s"
theme[temp_end]="%s"
theme[cpu_start]="%s"
theme[cpu_mid]="%s"
theme[cpu_end]="%s"
theme[free_start]="%s"
theme[free_mid]="%s"
theme[free_end]="%s"
theme[cached_start]="%s"
theme[cached_mid]="%s"
theme[cached_end]="%s"
theme[available_start]="%s"
theme[available_mid]="%s"
theme[available_end]="%s"
theme[used_start]="%s"
theme[used_mid]="%s"
theme[used_end]="%s"
theme[download_start]="%s"
theme[download_mid]="%s"
theme[download_end]="%s"
theme[upload_start]="%s"
theme[upload_mid]="%s"
theme[upload_end]="%s"
`, t.banner,
			t.term("bg"), t.c("fg"), t.c("fg"), t.c("accent"),
			t.c("surfaceBright"), t.c("accent"), t.c("fgFaint"), t.c("fgDim"),
			t.c("surfaceBright"), t.c("green"),
			t.c("outline"), t.c("outline"), t.c("outline"), t.c("outline"), t.c("outline"),
			t.c("green"), t.c("yellow"), t.c("red"),
			t.c("cyan"), t.c("blue"), t.c("purple"),
			t.c("green"), t.c("cyan"), t.c("blue"),
			t.c("blue"), t.c("purple"), t.c("purple"),
			t.c("yellow"), t.c("orange"), t.c("orange"),
			t.c("orange"), t.c("red"), t.c("red"),
			t.c("cyan"), t.c("blue"), t.c("purple"),
			t.c("green"), t.c("yellow"), t.c("orange")))
	if err != nil {
		return err
	}
	return subLine(inHome(".config/btop/btop.conf"),
		`^color_theme = ".*"$`,
		fmt.Sprintf(`color_theme = "%s/.config/btop/themes/%s.theme"`, home(), t.Name))
}

// themeSearch finds an installed GTK theme directory.
func themeSearch(name string) string {
	for _, root := range []string{
		inHome(".themes"), inHome(".local/share/themes"), "/usr/share/themes",
	} {
		dir := filepath.Join(root, name)
		if fi, err := os.Stat(dir); err == nil && fi.IsDir() {
			return dir
		}
	}
	return ""
}

func renderGTK(t *Theme) error {
	for _, version := range []string{"gtk-3.0", "gtk-4.0"} {
		path := inHome(filepath.Join(".config", version, "settings.ini"))
		for _, kv := range [][2]string{
			{"gtk-theme-name", t.GTK.Theme},
			{"gtk-icon-theme-name", t.GTK.Icons},
			{"gtk-application-prefer-dark-theme", "1"},
		} {
			if err := setINIKey(path, "Settings", kv[0], kv[1]); err != nil {
				return err
			}
		}
	}

	// GTK2 is still around (a few Xfce and Wine-adjacent dialogs) and reads a
	// completely separate file. nwg-look owns the header and includes
	// .gtkrc-2.0.mine, so keep both conventions intact and only retarget the
	// theme lines.
	gtkrc := inHome(".gtkrc-2.0")
	if exists(gtkrc) {
		if err := subLine(gtkrc, `^gtk-theme-name=.*$`,
			fmt.Sprintf(`gtk-theme-name="%s"`, t.GTK.Theme)); err != nil {
			return err
		}
		if err := subLine(gtkrc, `^gtk-icon-theme-name=.*$`,
			fmt.Sprintf(`gtk-icon-theme-name="%s"`, t.GTK.Icons)); err != nil {
			return err
		}
	} else {
		if err := writeFile(gtkrc, fmt.Sprintf(
			"# %s\ngtk-theme-name=\"%s\"\ngtk-icon-theme-name=\"%s\"\ngtk-font-name=\"Ubuntu Nerd Font 11\"\n",
			t.banner, t.GTK.Theme, t.GTK.Icons)); err != nil {
			return err
		}
	}

	// libadwaita/GTK4 apps ignore the theme name and read this file directly.
	//
	// The Material-Black themes are GTK2/3 only, so gtk4 names a separate theme
	// to borrow the GTK4 sheet from — a Colloid variant in the same palette. The
	// handful of GTK4 apps therefore stay in-palette even though they can't have
	// the Material-Black look.
	wanted := t.GTK.GTK4
	if wanted == "" {
		wanted = t.GTK.Theme
	}
	themeDir := themeSearch(wanted)
	for _, css := range []string{"gtk.css", "gtk-dark.css"} {
		dst := inHome(filepath.Join(".config/gtk-4.0", css))
		if exists(dst) {
			if err := os.Remove(dst); err != nil {
				return err
			}
		}
		if themeDir == "" {
			continue
		}
		src := filepath.Join(themeDir, "gtk-4.0", css)
		if !exists(src) {
			continue
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		if err := os.Symlink(src, dst); err != nil {
			return err
		}
	}
	return nil
}

const kvantumBase = "/usr/share/Kvantum/Nordic-Darker-Solid"

var generalColorsRe = regexp.MustCompile(`(?s)\[GeneralColors\]\n[^\[]*`)

// renderQt points Qt apps at Kvantum. No upstream Kvantum theme matches these
// palettes, so each one reuses a stock theme's SVG (the widget shapes) with its
// [GeneralColors] block rewritten — which is the part that reads as the theme.
func renderQt(t *Theme) error {
	name := t.GTK.Kvantum
	dest := inHome(filepath.Join(".config/Kvantum", name))
	baseConf := filepath.Join(kvantumBase, filepath.Base(kvantumBase)+".kvconfig")

	if exists(baseConf) {
		if err := os.MkdirAll(dest, 0o755); err != nil {
			return err
		}
		svg := filepath.Join(dest, name+".svg")
		if !exists(svg) {
			if err := copyFile(filepath.Join(kvantumBase, filepath.Base(kvantumBase)+".svg"),
				svg, 0o644); err != nil {
				return err
			}
		}

		colors := fmt.Sprintf(`[GeneralColors]
window.color=%s
base.color=%s
alt.base.color=%s
button.color=%s
light.color=%s
mid.light.color=%s
dark.color=%s
mid.color=%s
highlight.color=%s
inactive.highlight.color=%s
text.color=%s
window.text.color=%s
button.text.color=%s
disabled.text.color=%s
tooltip.text.color=%s
highlight.text.color=%s
link.color=%s
link.visited.color=%s
progress.indicator.text.color=%s
`, t.c("base"), t.c("dim"), t.c("surface"), t.c("surface"),
			t.c("surfaceBright"), t.c("surface"), t.c("dim"), t.c("outline"),
			t.c("accent"), t.c("surfaceBright"), t.c("fg"), t.c("fg"), t.c("fg"),
			t.c("fgFaint"), t.c("fg"), t.c("dim"), t.c("accent"), t.c("purple"),
			t.c("fg"))

		raw, err := os.ReadFile(baseConf)
		if err != nil {
			return err
		}
		text := replaceFirst(generalColorsRe, string(raw), colors)
		if err := writeFile(filepath.Join(dest, name+".kvconfig"),
			fmt.Sprintf("# %s\n%s", t.banner, text)); err != nil {
			return err
		}
	}

	if err := setINIKey(inHome(".config/Kvantum/kvantum.kvconfig"),
		"General", "theme", name); err != nil {
		return err
	}

	// qt5ct/qt6ct: create the config if it isn't there. Beyond the icon theme,
	// this is what gives Qt an icon theme *at all* — Quickshell included, since
	// Hyprland exports QT_QPA_PLATFORMTHEME=qt6ct to everything it starts.
	for _, qt := range []string{"qt5ct", "qt6ct"} {
		conf := inHome(filepath.Join(".config", qt, qt+".conf"))
		for _, kv := range [][2]string{
			{"icon_theme", t.GTK.Icons},
			{"style", "kvantum"},
			{"standard_dialogs", "default"},
		} {
			if err := setINIKey(conf, "Appearance", kv[0], kv[1]); err != nil {
				return err
			}
		}
	}
	return nil
}

// renderers run in this order deliberately: renderQuickshell writes the file
// Quickshell watches, and the hot reload that follows tears down the QML engine
// — which kills the `theme set` process the picker spawned. Doing it last means
// everything else has already landed. ThemeState.qml also detaches the process;
// belt and braces.
var renderers = []struct {
	name string
	fn   func(*Theme) error
}{
	{"icons", renderIcons},
	{"kitty", renderKitty},
	{"alacritty", renderAlacritty},
	{"nvim", renderNvim},
	{"doom", renderDoom},
	{"hypr", renderHypr},
	{"btop", renderBtop},
	{"gtk", renderGTK},
	{"qt", renderQt},
	{"quickshell", renderQuickshell},
}
