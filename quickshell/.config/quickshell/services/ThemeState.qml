pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Visibility and data for the theme picker.
//
// The themes themselves live in ~/.config/theme; `theme data` hands back the
// whole set (palettes, wallpapers, which one is live) in one JSON blob, so the
// shell never has to know how that directory is laid out.
Singleton {
	id: root

	property bool open: false
	property var themes: []
	property string activeName: ""

	function show(): void {
		// Re-read on open: the CLI may have switched themes since last time.
		reload();
		open = true;
	}

	function hide(): void {
		open = false;
	}

	function toggle(): void {
		if (open)
			hide();
		else
			show();
	}

	function reload(): void {
		dataProc.running = true;
	}

	// Switching rewrites generated/Colors.qml, which Quickshell notices and
	// hot-reloads — and that reload tears down the QML engine, killing any
	// process this singleton owns. `setsid -f` hands the switch off to init so
	// it runs to completion; without it the shell recoloured and everything
	// after it (wallpaper, GTK, the saved state) was silently dropped.
	function apply(name: string): void {
		setProc.command = ["setsid", "-f", "theme", "set", name];
		setProc.running = true;
		hide();
	}

	Process {
		id: dataProc
		command: ["theme", "data"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const data = JSON.parse(text);
					root.themes = data.themes;
					root.activeName = data.current;
				} catch (e) {
					console.warn("ThemeState: could not parse `theme data`:", e);
				}
			}
		}
	}

	Process {
		id: setProc
	}

	Component.onCompleted: root.reload()
}
