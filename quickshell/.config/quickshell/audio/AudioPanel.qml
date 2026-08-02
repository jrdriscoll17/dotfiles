import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.services

// Dropdown shown under the bar: volume slider and output picker.
//
// Same construction as NetworkPanel — a layer surface plus HyprlandFocusGrab
// rather than a grabbing popup, which may only be created from an input event.
PanelWindow {
	id: root

	required property var barScreen

	// Distance from the screen's right edge to the pill that opened this, so
	// the panel hangs directly under it rather than flush with the screen.
	property real anchorInset: 0

	signal requestClose

	screen: barScreen
	WlrLayershell.namespace: "quickshell:audio"
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

	implicitWidth: 320
	implicitHeight: frame.implicitHeight
	color: "transparent"

	HyprlandFocusGrab {
		windows: [root]
		active: true
		onCleared: root.requestClose()
	}

	Rectangle {
		id: frame

		implicitWidth: root.implicitWidth
		implicitHeight: column.implicitHeight + 20
		radius: 14
		color: Theme.alpha(Theme.base, 0.98)
		border.width: 1
		border.color: Theme.outline

		Column {
			id: column

			anchors.top: parent.top
			anchors.topMargin: 10
			anchors.left: parent.left
			anchors.right: parent.right
			spacing: 4

			// -- current output + level -------------------------------------
			Item {
				width: parent.width
				height: 40

				Column {
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.right: level.left
					anchors.rightMargin: 10
					anchors.verticalCenter: parent.verticalCenter
					spacing: 1

					Text {
						width: parent.width
						elide: Text.ElideRight
						text: Audio.description
						color: Theme.fg
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSize
						font.weight: Font.DemiBold
					}

					Text {
						text: Audio.muted ? "Muted" : "Output"
						color: Audio.muted ? Theme.red : Theme.fgDim
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSizeSmall
					}
				}

				Text {
					id: level
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: `${Math.round(Audio.volume * 100)}%`
					color: Audio.muted ? Theme.fgDim : Theme.fg
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSize
				}
			}

			// -- slider -----------------------------------------------------
			Item {
				width: parent.width
				height: 34

				Text {
					id: muteButton
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: Audio.icon
					color: Audio.muted ? Theme.red : Theme.cyan
					font.family: Theme.fontIcon
					font.pixelSize: 16

					MouseArea {
						anchors.fill: parent
						anchors.margins: -6
						cursorShape: Qt.PointingHandCursor
						onClicked: Audio.toggleMute()
					}
				}

				Item {
					id: slider

					anchors.left: muteButton.right
					anchors.leftMargin: 12
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					height: 20

					readonly property real fraction: Math.max(0, Math.min(1, Audio.volume))

					function applyAt(x: real): void {
						Audio.setVolume(x / slider.width);
					}

					Rectangle {
						id: track
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width
						height: 5
						radius: 2.5
						color: Theme.surfaceBright
					}

					Rectangle {
						anchors.verticalCenter: parent.verticalCenter
						width: track.width * slider.fraction
						height: track.height
						radius: track.radius
						color: Audio.muted ? Theme.fgDim : Theme.cyan
					}

					Rectangle {
						id: handle
						anchors.verticalCenter: parent.verticalCenter
						x: track.width * slider.fraction - width / 2
						width: 13
						height: 13
						radius: height / 2
						color: Audio.muted ? Theme.fgDim : Theme.cyan
						border.width: 2
						border.color: Theme.base
						scale: sliderMouse.pressed ? 1.15 : 1

						Behavior on scale {
							NumberAnimation {
								duration: Theme.animFast
							}
						}
					}

					MouseArea {
						id: sliderMouse
						anchors.fill: parent
						anchors.margins: -6
						cursorShape: Qt.PointingHandCursor

						onPressed: event => slider.applyAt(mapToItem(track, event.x, 0).x)
						onPositionChanged: event => {
							if (pressed)
								slider.applyAt(mapToItem(track, event.x, 0).x);
						}
						onWheel: event => {
							Audio.addVolume(event.angleDelta.y > 0 ? 0.05 : -0.05);
							event.accepted = true;
						}
					}
				}
			}

			Rectangle {
				width: parent.width - 28
				x: 14
				height: 1
				color: Theme.outline
			}

			// -- output picker ----------------------------------------------
			Text {
				x: 14
				topPadding: 6
				bottomPadding: 2
				text: "Outputs"
				color: Theme.fgDim
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
				font.weight: Font.DemiBold
			}

			ListView {
				width: parent.width
				height: Math.min(contentHeight, 220)
				visible: Audio.sinks.length > 0
				clip: true
				interactive: contentHeight > height
				model: Audio.sinks

				delegate: Rectangle {
					id: sinkRow

					required property var modelData

					readonly property bool current: Audio.sink !== null && Audio.sink.id === modelData.id

					width: ListView.view.width
					height: 34
					color: sinkMouse.containsMouse ? Theme.surface : "transparent"

					Text {
						id: check
						anchors.left: parent.left
						anchors.leftMargin: 16
						anchors.verticalCenter: parent.verticalCenter
						// Filled dot for the active output, hollow for the rest.
						text: sinkRow.current ? "󰝥" : "󰝦"
						color: sinkRow.current ? Theme.cyan : Theme.fgFaint
						font.family: Theme.fontIcon
						font.pixelSize: 13
					}

					Text {
						anchors.left: check.right
						anchors.leftMargin: 10
						anchors.right: parent.right
						anchors.rightMargin: 14
						anchors.verticalCenter: parent.verticalCenter
						elide: Text.ElideRight
						text: Audio.nameFor(sinkRow.modelData)
						color: sinkRow.current ? Theme.fg : Theme.fgDim
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSize
					}

					MouseArea {
						id: sinkMouse
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							if (!sinkRow.current)
								Audio.setSink(sinkRow.modelData);
						}
					}
				}
			}

			Text {
				visible: Audio.sinks.length === 0
				x: 14
				bottomPadding: 8
				text: "No outputs"
				color: Theme.fgFaint
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
			}

			// -- footer -----------------------------------------------------
			Rectangle {
				width: parent.width - 28
				x: 14
				height: 1
				color: Theme.outline
			}

			Item {
				width: parent.width
				height: 32

				Text {
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: `${Audio.sinks.length} device${Audio.sinks.length === 1 ? "" : "s"}`
					color: Theme.fgDim
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall
				}

				Text {
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: "Mixer"
					color: mixerMouse.containsMouse ? Theme.blue : Theme.fgDim
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall

					MouseArea {
						id: mixerMouse
						anchors.fill: parent
						anchors.margins: -6
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							Quickshell.execDetached(["pavucontrol"]);
							root.requestClose();
						}
					}
				}
			}
		}
	}
}
