pragma Singleton

import Quickshell
import QtQuick

// Visibility state for the app launcher. Kept in a singleton so the bar button,
// the IPC handler and the launcher window itself all drive the same flag.
Singleton {
	property bool open: false

	function show(): void {
		open = true;
	}

	function hide(): void {
		open = false;
	}

	function toggle(): void {
		open = !open;
	}
}
