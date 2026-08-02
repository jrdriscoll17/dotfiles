pragma Singleton

import Quickshell
import QtQuick

// Shared idle-inhibit flag. Each bar owns a wayland IdleInhibitor bound to
// this, so toggling the button on any monitor keeps all four bars in sync.
Singleton {
	property bool inhibited: false

	function toggle(): void {
		inhibited = !inhibited;
	}
}
