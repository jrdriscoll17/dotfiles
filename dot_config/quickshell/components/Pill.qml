import Quickshell
import QtQuick
import qs.config

// The bar's basic building block: a rounded, hoverable container laying its
// children out in a row, with an optional hover tooltip.
Rectangle {
	id: root

	default property alias content: row.data
	property alias spacing: row.spacing
	property string tooltipText: ""
	property Component tooltipContent: null
	property bool interactive: true
	property color bgColor: Theme.pillBg
	property color bgHoverColor: Theme.surfaceBright
	property int horizontalPadding: Theme.pillPadding

	readonly property bool hovered: mouse.containsMouse

	signal leftClicked
	signal rightClicked
	signal middleClicked
	signal scrolled(int delta)

	implicitWidth: row.implicitWidth + horizontalPadding * 2
	implicitHeight: Theme.barHeight
	// Fully rounded ends, whatever the pill's height works out to.
	radius: height / 2
	color: interactive && mouse.containsMouse ? bgHoverColor : bgColor
	border.width: 1
	border.color: Theme.pillBorder

	Behavior on color {
		ColorAnimation {
			duration: Theme.animFast
		}
	}

	// Above the MouseArea so nested controls (the clock's idle toggle) get their
	// clicks. Plain Text children don't accept events, so they still fall
	// through to the pill-wide MouseArea below.
	Row {
		id: row
		z: 1
		anchors.centerIn: parent
		spacing: Theme.gap
	}

	MouseArea {
		id: mouse
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

		onClicked: event => {
			if (event.button === Qt.LeftButton)
				root.leftClicked();
			else if (event.button === Qt.RightButton)
				root.rightClicked();
			else if (event.button === Qt.MiddleButton)
				root.middleClicked();
		}

		onWheel: event => {
			root.scrolled(event.angleDelta.y > 0 ? 1 : -1);
			event.accepted = true;
		}
	}

	// Delayed so tooltips don't flicker while sweeping the pointer across the bar.
	Timer {
		id: hoverDelay
		interval: 450
		running: mouse.containsMouse && (root.tooltipText !== "" || root.tooltipContent !== null)
		onTriggered: tooltipLoader.active = true
	}

	onHoveredChanged: {
		if (!hovered)
			tooltipLoader.active = false;
	}

	LazyLoader {
		id: tooltipLoader
		active: false

		component: Tooltip {
			anchorItem: root
			text: root.tooltipText
			contentComponent: root.tooltipContent
			visible: true
		}
	}
}
