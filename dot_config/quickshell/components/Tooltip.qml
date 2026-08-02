import Quickshell
import QtQuick
import qs.config

// Popup shown under a bar item on hover. Anchoring to both the bottom edge and
// bottom gravity makes the compositor centre it horizontally on the anchor.
PopupWindow {
	id: root

	required property Item anchorItem
	property string text: ""
	property Component contentComponent: null

	anchor.item: anchorItem
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.margins.top: 6

	implicitWidth: frame.implicitWidth
	implicitHeight: frame.implicitHeight
	color: "transparent"

	Rectangle {
		id: frame

		implicitWidth: column.implicitWidth + 20
		implicitHeight: column.implicitHeight + 14
		radius: Theme.pillRadius
		color: Theme.alpha(Theme.surface, 0.97)
		border.width: 1
		border.color: Theme.outline

		Column {
			id: column
			anchors.centerIn: parent
			spacing: 6

			Text {
				visible: root.text !== ""
				text: root.text
				color: Theme.fg
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSize
				lineHeight: 1.25
			}

			Loader {
				sourceComponent: root.contentComponent
				active: root.contentComponent !== null
			}
		}
	}
}
