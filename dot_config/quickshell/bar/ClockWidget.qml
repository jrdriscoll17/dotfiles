import Quickshell
import QtQuick
import qs.config
import qs.components
import qs.services

// Date · time · idle inhibitor, all in one island.
Pill {
	id: root

	readonly property date now: clock.date

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	horizontalPadding: 12
	spacing: 10
	tooltipContent: calendarComponent

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Qt.formatDateTime(root.now, "MMMM d, yyyy")
		color: Theme.blue
		font.family: Theme.fontUi
		font.pixelSize: Theme.fontSize
	}

	Rectangle {
		anchors.verticalCenter: parent.verticalCenter
		width: 1
		height: 12
		color: Theme.outline
	}

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Qt.formatDateTime(root.now, "h:mm AP")
		color: Theme.fg
		font.family: Theme.fontUi
		font.pixelSize: Theme.fontSize
		font.weight: Font.DemiBold
	}

	Rectangle {
		anchors.verticalCenter: parent.verticalCenter
		width: 1
		height: 12
		color: Theme.outline
	}

	// Idle inhibitor. Its own MouseArea, so clicking the eye toggles idle while
	// the rest of the island still shows the calendar.
	Item {
		anchors.verticalCenter: parent.verticalCenter
		implicitWidth: eye.implicitWidth + 6
		implicitHeight: root.height

		Text {
			id: eye
			anchors.centerIn: parent
			// Font Awesome eye / eye-slash, carried over from waybar. Escaped
			// rather than literal so the private-use codepoints survive edits.
			text: IdleState.inhibited ? "" : ""
			color: IdleState.inhibited ? Theme.red : Theme.fgDim
			font.family: Theme.fontIcon
			font.pixelSize: Theme.fontSizeIcon
		}

		MouseArea {
			id: eyeMouse
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: IdleState.toggle()
		}
	}

	Component {
		id: calendarComponent

		Calendar {
			today: root.now
		}
	}
}
