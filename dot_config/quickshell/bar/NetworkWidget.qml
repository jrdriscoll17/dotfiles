import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services
import qs.network

Pill {
	id: root

	// The bar's screen, so the dropdown opens on the monitor that was clicked.
	required property var barScreen

	property bool panelOpen: false

	tooltipText: {
		const lines = [];
		const w = Net.wiredDevice;
		if (w !== null) {
			const ip = Net.addressFor(w);
			lines.push(`${w.name}: ${w.connected ? "connected" : w.hasLink ? "link up" : "no cable"}${ip !== "" ? "  " + ip : ""}`);
		}
		if (Net.wifiDevice !== null) {
			const wip = Net.addressFor(Net.wifiDevice);
			lines.push(`${Net.wifiDevice.name}: ${!Net.wifiRadioOn ? "radio off" : Net.wifiUp ? Net.wifiSsid + "  " + Math.round(Net.wifiSignal * 100) + "%" : "disconnected"}${Net.wifiUp && wip !== "" ? "  " + wip : ""}`);
		}
		lines.push("");
		lines.push(Net.connectivityText);
		lines.push("Click for networks");
		return lines.join("\n");
	}

	// Suppress the hover tooltip while the panel is showing the same info.
	tooltipContent: null
	bgColor: Theme.pillBg

	onLeftClicked: panelOpen = !panelOpen

	// Only scan while the picker is actually open.
	onPanelOpenChanged: {
		Net.setScanning(panelOpen);
		if (panelOpen)
			Net.refresh();
	}

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Net.icon
		color: {
			if (Net.primary === "none")
				return Theme.red;
			if (Net.degraded)
				return Theme.yellow;
			return Theme.cyan;
		}
		font.family: Theme.fontIcon
		font.pixelSize: Theme.fontSizeIcon
	}

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Net.label
		color: Net.primary === "none" ? Theme.red : Theme.fg
		font.family: Theme.fontUi
		font.pixelSize: Theme.fontSize
	}

	LazyLoader {
		active: root.panelOpen

		component: NetworkPanel {
			barScreen: root.barScreen
			// The bar's right-hand group is anchored to the window's right edge,
			// so the gap after this pill within the group is also its distance
			// from the screen edge.
			anchorInset: root.parent !== null ? root.parent.width - (root.x + root.width) : 0
			visible: true
			onRequestClose: root.panelOpen = false
		}
	}
}
