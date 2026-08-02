import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.config

// Workspaces 1-10 are always shown, matching the old persistent-workspaces
// setup. Empty ones collapse to a dot so four monitors' worth of bars don't
// turn into a wall of numbers.
Row {
	id: root

	required property string monitorName

	// Chip diameter. The containing pill pads itself by half the difference
	// against the bar height so the first and last chip end up concentric with
	// the pill's rounded ends.
	readonly property int chipSize: 18

	spacing: 3

	Repeater {
		model: 10

		delegate: Rectangle {
			id: chip

			required property int index
			readonly property int wsId: index + 1

			// Reading Hyprland.workspaces.values here keeps this binding live as
			// workspaces are created and destroyed.
			readonly property var ws: {
				for (const w of Hyprland.workspaces.values) {
					if (w.id === chip.wsId)
						return w;
				}
				return null;
			}

			readonly property bool exists: ws !== null
			readonly property bool onThisMonitor: exists && ws.monitor !== null && ws.monitor.name === root.monitorName
			readonly property bool active: onThisMonitor && ws.active
			readonly property bool occupied: exists && ws.toplevels.values.length > 0
			readonly property bool urgent: exists && ws.urgent

			width: active ? root.chipSize + 8 : root.chipSize
			height: root.chipSize
			radius: height / 2
			anchors.verticalCenter: parent.verticalCenter

			color: {
				if (urgent)
					return Theme.red;
				if (active)
					return Theme.blue;
				if (occupied)
					return Theme.alpha(Theme.fg, hover.containsMouse ? 0.25 : 0.13);
				return hover.containsMouse ? Theme.alpha(Theme.fg, 0.13) : "transparent";
			}

			Behavior on width {
				NumberAnimation {
					duration: Theme.animNormal
					easing.type: Easing.OutQuint
				}
			}

			Behavior on color {
				ColorAnimation {
					duration: Theme.animFast
				}
			}

			// Number for anything with windows or focus; a dot for the rest.
			Text {
				anchors.centerIn: parent
				visible: chip.active || chip.occupied
				text: chip.wsId
				color: chip.active || chip.urgent ? Theme.base : Theme.fg
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSizeSmall
				font.weight: Font.DemiBold
			}

			Rectangle {
				anchors.centerIn: parent
				visible: !chip.active && !chip.occupied
				width: 4
				height: 4
				radius: 2
				color: chip.onThisMonitor ? Theme.fgDim : Theme.fgFaint
			}

			MouseArea {
				id: hover
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor

				// Focus this bar's monitor first, so the workspace lands here
				// rather than on whichever monitor happened to be focused —
				// this mirrors the on_current_monitor binds in hyprland.lua.
				onClicked: {
					Hyprland.dispatch(`focusmonitor ${root.monitorName}`);
					Hyprland.dispatch(`focusworkspaceoncurrentmonitor ${chip.wsId}`);
				}
			}
		}
	}
}
