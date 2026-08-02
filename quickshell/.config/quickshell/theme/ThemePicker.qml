import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.config
import qs.services

// Theme picker. One card per theme in ~/.config/theme: wallpaper preview, name,
// and the palette it will paint the desktop with.
//
// Applying shells out to `theme set <name>`, which regenerates every config on
// the box — including generated/Colors.qml, so the bar behind this window
// recolours on its own a moment later.
PanelWindow {
	id: root

	// Same treatment as the launcher: whichever monitor has focus.
	screen: {
		const name = Hyprland.focusedMonitor?.name ?? "";
		for (const s of Quickshell.screens) {
			if (s.name === name)
				return s;
		}
		return Quickshell.screens[0];
	}

	WlrLayershell.namespace: "quickshell:themepicker"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	exclusionMode: ExclusionMode.Ignore
	color: Theme.alpha("#000000", 0.45)

	readonly property var themes: ThemeState.themes
	property int selected: 0
	// Once the user has moved or hovered, stop re-homing the selection on them.
	property bool touched: false

	// `theme data` is read in a subprocess, so the card list usually lands after
	// this window is built. A plain binding wouldn't survive the first move(),
	// hence syncing by hand until the user takes over.
	function syncSelection(): void {
		if (root.touched)
			return;
		const i = root.themes.findIndex(t => t.name === ThemeState.activeName);
		root.selected = Math.max(0, i);
	}

	onThemesChanged: root.syncSelection()
	Component.onCompleted: root.syncSelection()

	Connections {
		target: ThemeState

		function onActiveNameChanged(): void {
			root.syncSelection();
		}
	}

	function move(step: int): void {
		if (themes.length === 0)
			return;
		touched = true;
		selected = (selected + step + themes.length) % themes.length;
	}

	function applySelected(): void {
		if (themes.length > 0)
			ThemeState.apply(themes[selected].name);
	}

	MouseArea {
		anchors.fill: parent
		onClicked: ThemeState.hide()
	}

	Column {
		anchors.centerIn: parent
		spacing: 22

		Column {
			anchors.horizontalCenter: parent.horizontalCenter
			spacing: 4

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				text: "Theme"
				color: Theme.fg
				font.family: Theme.fontUi
				font.pixelSize: 22
				font.weight: Font.DemiBold
			}

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				text: "← → to choose · enter to apply · esc to close"
				color: Theme.fgDim
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
			}
		}

		Row {
			spacing: 18

			Repeater {
				model: root.themes

				delegate: Rectangle {
					id: card

					required property var modelData
					required property int index

					readonly property bool chosen: root.selected === index
					readonly property bool live: ThemeState.activeName === modelData.name

					width: 260
					height: 300
					radius: 16
					color: Theme.alpha(Theme.base, 0.96)
					border.width: 2
					border.color: card.chosen ? Theme.accent : Theme.outline

					Behavior on border.color {
						ColorAnimation {
							duration: Theme.animFast
						}
					}

					scale: card.chosen ? 1.0 : 0.97

					Behavior on scale {
						NumberAnimation {
							duration: Theme.animNormal
							easing.type: Easing.OutCubic
						}
					}

					Column {
						anchors.fill: parent
						anchors.margins: 12
						spacing: 10

						// Wallpaper preview. sourceSize keeps the 4K originals
						// from being decoded at full resolution three at a time.
						ClippingRectangle {
							width: parent.width
							height: 140
							radius: 10
							color: Theme.surface
							border.width: 1
							border.color: Theme.alpha(Theme.outline, 0.8)

							Image {
								anchors.fill: parent
								source: `file://${card.modelData.wallpaper}`
								sourceSize.width: 520
								fillMode: Image.PreserveAspectCrop
								asynchronous: true
							}
						}

						Row {
							width: parent.width
							spacing: 6

							Text {
								text: card.modelData.label
								color: Theme.fg
								font.family: Theme.fontUi
								font.pixelSize: 15
								font.weight: Font.DemiBold
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								visible: card.live
								text: "· active"
								color: Theme.accent
								font.family: Theme.fontUi
								font.pixelSize: Theme.fontSizeSmall
							}
						}

						Text {
							width: parent.width
							text: card.modelData.blurb
							color: Theme.fgDim
							font.family: Theme.fontUi
							font.pixelSize: Theme.fontSizeSmall
							wrapMode: Text.WordWrap
							maximumLineCount: 3
							elide: Text.ElideRight
						}

						// The palette itself, so the card shows what it does
						// rather than just naming it.
						Row {
							spacing: 5

							Repeater {
								model: ["accent", "blue", "green", "yellow", "orange", "red", "purple", "fg"]

								delegate: Rectangle {
									required property string modelData

									width: 20
									height: 20
									radius: height / 2
									color: card.modelData.colors[modelData]
									border.width: 1
									border.color: Theme.alpha(Theme.base, 0.6)
								}
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onEntered: {
							root.touched = true;
							root.selected = card.index;
						}
						onClicked: root.applySelected()
					}
				}
			}
		}
	}

	Item {
		anchors.fill: parent
		focus: true

		Keys.onPressed: event => {
			switch (event.key) {
			case Qt.Key_Escape:
				ThemeState.hide();
				break;
			case Qt.Key_Left:
			case Qt.Key_H:
				root.move(-1);
				break;
			case Qt.Key_Right:
			case Qt.Key_L:
				root.move(1);
				break;
			case Qt.Key_Return:
			case Qt.Key_Enter:
			case Qt.Key_Space:
				root.applySelected();
				break;
			default:
				return;
			}
			event.accepted = true;
		}
	}
}
