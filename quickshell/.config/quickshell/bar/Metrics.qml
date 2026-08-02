import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services

// Storage / memory / CPU, as a tight group of three pills.
//
// These use short text labels rather than icons: at 13px the Nerd Font glyphs
// for "memory" and "cpu" are both anonymous chips and impossible to tell apart.
Row {
	id: root

	spacing: 3

	// Label + fixed-width value. The fixed width stops the bar shuffling every
	// two seconds as readings gain and lose digits, so it's sized to the widest
	// reading each metric can produce — 6.5px per character in the mono face.
	component Metric: Pill {
		id: metric

		property string label: ""
		property color labelColor: Theme.fg
		property string value: ""
		property int valueWidth: 33

		spacing: 5

		Text {
			anchors.verticalCenter: parent.verticalCenter
			text: metric.label
			color: metric.labelColor
			font.family: Theme.fontUi
			font.pixelSize: Theme.fontSizeSmall
			font.weight: Font.Bold
			font.letterSpacing: 0.6
		}

		Item {
			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: metric.valueWidth
			implicitHeight: valueText.implicitHeight

			Text {
				id: valueText
				// Centred, not right-aligned: with a short reading like "3%"
				// all the column's slack would otherwise pile up against the
				// label and read as a gap.
				anchors.horizontalCenter: parent.horizontalCenter
				text: metric.value
				color: Theme.fg
				font.family: Theme.fontMono
				font.pixelSize: Theme.fontSize
			}
		}
	}

	Metric {
		label: "DISK"
		// Green until the disk gets tight, then warn — same 20%/10% free
		// thresholds the old storage.sh script used.
		labelColor: SysInfo.diskRatio > 0.9 ? Theme.red : SysInfo.diskRatio > 0.8 ? Theme.yellow : Theme.green
		value: SysInfo.diskAvail
		valueWidth: 27
		tooltipText: `Filesystem  /\nSize ${SysInfo.diskSize}   Used ${SysInfo.diskUsed}   Free ${SysInfo.diskAvail}\nIn use ${Math.round(SysInfo.diskRatio * 100)}%`
		onLeftClicked: Quickshell.execDetached(["pcmanfm"])
	}

	Metric {
		label: "RAM"
		labelColor: SysInfo.memRatio > 0.9 ? Theme.red : Theme.yellow
		value: `${SysInfo.memUsed.toFixed(1)}G`
		tooltipText: `Memory\n${SysInfo.memUsed.toFixed(1)} of ${SysInfo.memTotal.toFixed(1)} GiB   ${Math.round(SysInfo.memRatio * 100)}%\n\nClick to open btop`
		onLeftClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
	}

	Metric {
		label: "CPU"
		labelColor: SysInfo.cpuUsage > 0.85 ? Theme.red : Theme.orange
		value: `${Math.round(SysInfo.cpuUsage * 100)}%`
		valueWidth: 27
		tooltipText: `CPU\n${Math.round(SysInfo.cpuUsage * 100)}% at ${SysInfo.cpuGhz.toFixed(2)} GHz\n\nClick to open btop`
		onLeftClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
	}
}
