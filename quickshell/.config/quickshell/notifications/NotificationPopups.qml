import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import qs.config
import qs.services

// Notification popups, in place of mako's.
//
// The window is only as big as the cards, so it never swallows clicks meant for
// whatever is underneath. It follows the focused monitor, which is where mako
// put them too.
PanelWindow {
	id: root

	screen: {
		const name = Hyprland.focusedMonitor?.name ?? "";
		for (const s of Quickshell.screens) {
			if (s.name === name)
				return s;
		}
		return Quickshell.screens[0];
	}

	WlrLayershell.namespace: "quickshell:notifications"
	WlrLayershell.layer: WlrLayer.Overlay
	// Never take focus: typing must keep going to whatever is underneath.
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	anchors {
		top: true
		right: true
	}

	// Clear of the bar, aligned with the right-hand pills.
	margins {
		top: Theme.barMargin + Theme.barHeight + 8
		right: Theme.barMargin
	}

	exclusionMode: ExclusionMode.Ignore
	color: "transparent"

	implicitWidth: 400
	implicitHeight: Math.max(1, column.implicitHeight)
	visible: Notifs.popups.length > 0

	Column {
		id: column

		width: parent.width
		spacing: 8

		Repeater {
			model: Notifs.popups

			delegate: NotificationCard {
				required property var modelData

				notif: modelData
				width: column.width
			}
		}
	}
}
