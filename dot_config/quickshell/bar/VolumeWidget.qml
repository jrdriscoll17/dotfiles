import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services
import qs.audio

Pill {
	id: root

	// The bar's screen, so the dropdown opens on the monitor that was clicked.
	required property var barScreen

	property bool panelOpen: false

	tooltipText: `${Audio.description}\n${Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"}\n\nScroll to adjust · right click to mute\nClick for outputs`

	onLeftClicked: panelOpen = !panelOpen
	onRightClicked: Audio.toggleMute()
	onScrolled: delta => Audio.addVolume(delta * 0.05)

	spacing: 5

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Audio.icon
		color: Audio.muted ? Theme.fgDim : Theme.cyan
		font.family: Theme.fontIcon
		font.pixelSize: Theme.fontSizeIcon
	}

	Item {
		anchors.verticalCenter: parent.verticalCenter
		// Widest reading is "100%" — 27px in the mono face at this size.
		implicitWidth: 27
		implicitHeight: label.implicitHeight

		Text {
			id: label
			anchors.horizontalCenter: parent.horizontalCenter
			text: Audio.muted ? "off" : `${Math.round(Audio.volume * 100)}%`
			color: Audio.muted ? Theme.fgDim : Theme.fg
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSize
		}
	}

	LazyLoader {
		active: root.panelOpen

		component: AudioPanel {
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
