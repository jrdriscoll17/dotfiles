import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import qs.config
import qs.components
import qs.tray

// StatusNotifierItem tray. Hidden entirely when nothing is registered so the
// bar doesn't carry an empty pill around.
Pill {
	id: root

	// The bar's screen, so menus open on the monitor that was clicked.
	required property var barScreen

	// Item whose menu is currently open, if any.
	property var openMenuItem: null
	property real openMenuInset: 0

	visible: SystemTray.items.values.length > 0
	interactive: false
	spacing: 8
	horizontalPadding: 10

	Repeater {
		model: SystemTray.items

		delegate: Item {
			id: entry

			required property SystemTrayItem modelData

			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: 18
			implicitHeight: 18

			// implicitSize rather than anchors.fill: IconImage rasterises SVG
			// icons at its implicit size, and leaving that unset makes Qt try
			// (and refuse) an enormous buffer.
			IconImage {
				id: icon
				anchors.centerIn: parent
				implicitSize: 18
				source: entry.modelData.icon
				// Passive items are dimmed rather than hidden, the way the old
				// waybar stylesheet handled them.
				opacity: entry.modelData.status === Status.Passive ? 0.5 : (itemMouse.containsMouse ? 1.0 : 0.9)

				Behavior on opacity {
					NumberAnimation {
						duration: Theme.animFast
					}
				}
			}

			MouseArea {
				id: itemMouse
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

				onClicked: event => {
					const item = entry.modelData;

					// Some items are menu-only and have no activate action.
					if (event.button === Qt.LeftButton) {
						if (item.onlyMenu && item.hasMenu)
							entry.openMenu();
						else
							item.activate();
					} else if (event.button === Qt.RightButton) {
						if (item.hasMenu)
							entry.openMenu();
					} else if (event.button === Qt.MiddleButton) {
						item.secondaryActivate();
					}
				}
			}

			function openMenu(): void {
				if (root.openMenuItem === entry.modelData) {
					root.openMenuItem = null;
					return;
				}

				// The bar's right-hand group is anchored to the window's right
				// edge, so this icon's offset within the group is also its
				// distance from the screen edge.
				const group = root.parent;
				root.openMenuInset = group !== null ? group.width - entry.mapToItem(group, entry.width, 0).x : 0;
				root.openMenuItem = entry.modelData;
			}
		}
	}

	LazyLoader {
		active: root.openMenuItem !== null

		component: TrayMenu {
			barScreen: root.barScreen
			menuHandle: root.openMenuItem?.menu ?? null
			anchorInset: root.openMenuInset
			visible: true
			onRequestClose: root.openMenuItem = null
		}
	}
}
