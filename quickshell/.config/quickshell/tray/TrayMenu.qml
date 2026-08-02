import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.config

// Context menu for a StatusNotifierItem, drawn to match the rest of the shell.
//
// Quickshell can hand these off to Qt's platform menus instead, but that needs
// `//@ pragma UseQApplication` and produces a widget menu styled by the Qt
// theme — a light grey box against this bar. Rendering the QsMenuOpener model
// directly keeps it in the shell's own palette.
PanelWindow {
	id: root

	required property var barScreen
	required property var menuHandle

	// Distance from the screen's right edge to the icon that opened this.
	property real anchorInset: 0

	signal requestClose

	screen: barScreen
	WlrLayershell.namespace: "quickshell:traymenu"
	WlrLayershell.layer: WlrLayer.Overlay
	focusable: true

	anchors {
		top: true
		right: true
	}

	margins {
		top: Theme.barMargin + Theme.barHeight + 8
		right: Theme.barMargin + root.anchorInset
	}

	exclusionMode: ExclusionMode.Ignore

	// Rows report their natural width here rather than the menu reading it off
	// the Column: rows stretch to the menu's width, so deriving the menu's
	// width from them in a binding is circular and collapses to the floor.
	property real contentWidth: 0

	implicitWidth: Math.min(420, Math.max(170, contentWidth))
	implicitHeight: frame.implicitHeight
	color: "transparent"

	HyprlandFocusGrab {
		windows: [root]
		active: true
		onCleared: root.requestClose()
	}

	QsMenuOpener {
		id: opener
		menu: root.menuHandle
	}

	Rectangle {
		id: frame

		implicitHeight: column.implicitHeight + 12
		width: root.width
		radius: 12
		color: Theme.alpha(Theme.base, 0.98)
		border.width: 1
		border.color: Theme.outline

		Column {
			id: column

			anchors.top: parent.top
			anchors.topMargin: 6
			anchors.left: parent.left
			anchors.right: parent.right

			Repeater {
				model: opener.children

				delegate: Item {
					id: entryItem

					required property var modelData

					// Submenus expand in place rather than flying out sideways,
					// which would need a second surface and hover tracking.
					property bool expanded: false

					implicitWidth: entryRow.implicitWidth
					implicitHeight: entryRow.implicitHeight + subLoader.implicitHeight
					width: parent.width

					MenuRow {
						id: entryRow
						entry: entryItem.modelData
						width: parent.width
						expanded: entryItem.expanded
						onActivated: {
							if (entryItem.modelData.hasChildren)
								entryItem.expanded = !entryItem.expanded;
							else {
								entryItem.modelData.triggered();
								root.requestClose();
							}
						}
					}

					Loader {
						id: subLoader

						anchors.top: entryRow.bottom
						width: parent.width
						active: entryItem.expanded
						visible: active

						sourceComponent: Column {
							QsMenuOpener {
								id: subOpener
								menu: entryItem.modelData
							}

							Repeater {
								model: subOpener.children

								delegate: MenuRow {
									required property var modelData

									entry: modelData
									width: subLoader.width
									indented: true
									onActivated: {
										modelData.triggered();
										root.requestClose();
									}
								}
							}
						}
					}
				}
			}
		}
	}

	// One row: separator line, or icon + label with an optional check mark and
	// submenu chevron.
	component MenuRow: Item {
		id: row

		required property var entry
		property bool indented: false
		property bool expanded: false

		signal activated

		readonly property bool separator: entry.isSeparator

		implicitWidth: 28 + (row.indented ? 12 : 0) + (icon.visible ? 22 : 0) + label.implicitWidth + (chevron.visible ? 18 : 0)
		implicitHeight: separator ? 7 : 30

		onImplicitWidthChanged: root.contentWidth = Math.max(root.contentWidth, implicitWidth)
		Component.onCompleted: root.contentWidth = Math.max(root.contentWidth, implicitWidth)

		Rectangle {
			anchors.centerIn: parent
			visible: row.separator
			width: parent.width - 20
			height: 1
			color: Theme.outline
		}

		Rectangle {
			anchors.fill: parent
			anchors.leftMargin: 4
			anchors.rightMargin: 4
			visible: !row.separator && rowMouse.containsMouse && row.entry.enabled
			radius: 7
			color: Theme.surface
		}

		IconImage {
			id: icon
			anchors.left: parent.left
			anchors.leftMargin: 12 + (row.indented ? 12 : 0)
			anchors.verticalCenter: parent.verticalCenter
			implicitSize: 15
			visible: !row.separator && row.entry.icon !== ""
			source: row.entry.icon
			opacity: row.entry.enabled ? 1 : 0.4
		}

		Text {
			id: label
			anchors.left: icon.visible ? icon.right : parent.left
			anchors.leftMargin: icon.visible ? 8 : 12 + (row.indented ? 12 : 0)
			// Anchored on both sides so long entries elide instead of running
			// past the menu's clamped width.
			anchors.right: parent.right
			anchors.rightMargin: chevron.visible ? 30 : 12
			anchors.verticalCenter: parent.verticalCenter
			visible: !row.separator
			text: {
				const t = row.entry.text;
				if (row.entry.buttonType === QsMenuButtonType.None)
					return t;
				// Check state is drawn inline; SNI check marks are rare enough
				// that a dedicated column would mostly be empty space.
				return `${row.entry.checkState === Qt.Checked ? "● " : "○ "}${t}`;
			}
			color: row.entry.enabled ? Theme.fg : Theme.fgFaint
			font.family: Theme.fontUi
			font.pixelSize: Theme.fontSize
			elide: Text.ElideRight
		}

		Text {
			id: chevron
			anchors.right: parent.right
			anchors.rightMargin: 12
			anchors.verticalCenter: parent.verticalCenter
			visible: !row.separator && row.entry.hasChildren
			text: row.expanded ? "󰅀" : "󰅂"
			color: Theme.fgDim
			font.family: Theme.fontIcon
			font.pixelSize: 12
		}

		MouseArea {
			id: rowMouse
			anchors.fill: parent
			enabled: !row.separator && row.entry.enabled
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: row.activated()
		}
	}
}
