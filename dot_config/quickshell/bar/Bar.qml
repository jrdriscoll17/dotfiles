import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.config
import qs.components
import qs.services

// One bar per monitor. There is no bar surface — the window is transparent and
// the pills float directly over the wallpaper as separate islands.
PanelWindow {
	id: root

	required property ShellScreen modelData

	screen: modelData
	WlrLayershell.namespace: "quickshell:bar"

	anchors {
		top: true
		left: true
		right: true
	}

	margins {
		top: Theme.barMargin
		left: Theme.barMargin
		right: Theme.barMargin
	}

	implicitHeight: Theme.barHeight
	color: "transparent"

	// Bound to the shared flag so the toggle applies no matter which bar's
	// button was clicked.
	IdleInhibitor {
		window: root
		enabled: IdleState.inhibited
	}

	// -- left --------------------------------------------------------------
	Pill {
		anchors.left: parent.left
		anchors.verticalCenter: parent.verticalCenter
		interactive: false
		// Match the vertical inset, so the end chips are concentric with the
		// pill's rounded ends.
		horizontalPadding: (Theme.barHeight - workspaces.chipSize) / 2

		Workspaces {
			id: workspaces

			anchors.verticalCenter: parent.verticalCenter
			// Optional chaining: modelData is briefly null while Variants
			// rebuilds its instances on reload and on monitor hotplug.
			monitorName: root.modelData?.name ?? ""
		}
	}

	// -- centre ------------------------------------------------------------
	ClockWidget {
		anchors.centerIn: parent
	}

	// -- right -------------------------------------------------------------
	Row {
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		spacing: Theme.groupGap

		Metrics {
			anchors.verticalCenter: parent.verticalCenter
		}

		NetworkWidget {
			anchors.verticalCenter: parent.verticalCenter
			barScreen: root.modelData
		}

		VolumeWidget {
			anchors.verticalCenter: parent.verticalCenter
			barScreen: root.modelData
		}

		TrayWidget {
			anchors.verticalCenter: parent.verticalCenter
			barScreen: root.modelData
		}
	}
}
