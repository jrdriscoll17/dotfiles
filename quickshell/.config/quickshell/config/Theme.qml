pragma Singleton

import Quickshell
import QtQuick
import qs.generated

// Central design tokens: the live palette plus the metrics the floating-bar
// treatment needs.
//
// The colours are aliases of Colors.qml, which `theme set <name>` regenerates
// from ~/.config/theme/themes/<name>.json. Widgets keep referring to
// Theme.<colour>, so a theme switch touches exactly one generated file and
// Quickshell hot-reloads it.
Singleton {
	// -- palette ------------------------------------------------------------
	readonly property color base: Colors.base
	readonly property color surface: Colors.surface
	readonly property color surfaceBright: Colors.surfaceBright
	readonly property color outline: Colors.outline

	readonly property color fg: Colors.fg
	readonly property color fgDim: Colors.fgDim
	readonly property color fgFaint: Colors.fgFaint
	// Deliberately lighter than fgFaint: this is the one the code editors pin
	// comment text to, kept here so shell chrome can match.
	readonly property color comment: Colors.comment

	readonly property color red: Colors.red
	readonly property color green: Colors.green
	readonly property color yellow: Colors.yellow
	readonly property color blue: Colors.blue
	readonly property color purple: Colors.purple
	readonly property color cyan: Colors.cyan
	readonly property color orange: Colors.orange

	// What the shell highlights with: the blue in One Dark, the ice cyan in Ice
	// Blue, the moss green in Evergreen.
	readonly property color accent: Colors.accent

	readonly property string themeName: Colors.themeName
	readonly property string themeLabel: Colors.themeLabel

	// -- fonts --------------------------------------------------------------
	// Ubuntu everywhere; the only exception is the dedicated icon font, which
	// carries the Material Design glyphs the bar uses.
	readonly property string fontUi: "Ubuntu Nerd Font"
	readonly property string fontMono: "UbuntuMono Nerd Font"
	readonly property string fontIcon: "Symbols Nerd Font Mono"

	readonly property int fontSize: 13
	readonly property int fontSizeSmall: 11
	readonly property int fontSizeIcon: 14

	// -- metrics ------------------------------------------------------------
	// Monitors run at scale 2, so these are logical pixels.
	//
	// There is no bar background: the pills are the bar. barHeight is therefore
	// the island height, and the window is exactly that tall.
	readonly property int barHeight: 26
	readonly property int barMargin: 8
	// Pills round themselves to height/2; this is for the flyout surfaces
	// (tooltip, network panel) that keep square-ish corners.
	readonly property int pillRadius: 10
	readonly property int pillPadding: 10
	readonly property int gap: 6
	readonly property int groupGap: 8

	readonly property int animFast: 120
	readonly property int animNormal: 200

	// Island background: mostly opaque so text stays readable over any
	// wallpaper, with a hint of translucency so it doesn't read as a solid slab.
	readonly property color pillBg: Qt.rgba(surface.r, surface.g, surface.b, 0.92)
	readonly property color pillBorder: Qt.rgba(outline.r, outline.g, outline.b, 0.7)

	function alpha(c: color, a: real): color {
		return Qt.rgba(c.r, c.g, c.b, a);
	}
}
