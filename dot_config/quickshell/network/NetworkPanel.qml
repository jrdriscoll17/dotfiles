import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Networking
import QtQuick
import qs.config
import qs.services

// Dropdown shown under the bar: wired status, wifi radio toggle and a connect
// list.
//
// This is a layer surface rather than a PopupWindow with grabFocus. A grabbing
// xdg popup may only be created in response to an input event, which makes it
// unreliable to open from a property change; a layer surface plus an explicit
// HyprlandFocusGrab has no such constraint and still gives keyboard focus for
// the password field and click-outside dismissal.
PanelWindow {
	id: root

	required property var barScreen

	// Distance from the screen's right edge to the pill that opened this, so
	// the panel hangs directly under it rather than flush with the screen.
	property real anchorInset: 0

	signal requestClose

	screen: barScreen
	WlrLayershell.namespace: "quickshell:network"
	WlrLayershell.layer: WlrLayer.Overlay
	focusable: true

	anchors {
		top: true
		right: true
	}

	// Sit just below the bar, right-aligned with the pill that opened it.
	margins {
		top: Theme.barMargin + Theme.barHeight + 8
		right: Theme.barMargin + root.anchorInset
	}

	exclusionMode: ExclusionMode.Ignore

	implicitWidth: 340
	implicitHeight: frame.implicitHeight
	color: "transparent"

	HyprlandFocusGrab {
		windows: [root]
		active: true
		onCleared: root.requestClose()
	}

	// Network awaiting a password, if any.
	property var pendingNetwork: null

	function activate(net): void {
		if (net.connected) {
			net.disconnect();
		} else if (root.pendingNetwork === net) {
			// Second click on a network already asking for a passphrase closes
			// the drawer again.
			root.pendingNetwork = null;
		} else if (net.known && net.nmSettings.length > 0) {
			net.connect(net.nmSettings[0]);
			root.requestClose();
		} else if (net.security === WifiSecurityType.Open || net.security === WifiSecurityType.Owe) {
			net.connectWithPsk("");
			root.requestClose();
		} else {
			// Secured and unknown — collect a passphrase first.
			root.pendingNetwork = net;
		}
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

			// -- wired ------------------------------------------------------
			Item {
				width: parent.width
				height: 46

				Text {
					id: wiredIcon
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: "󰈀"
					color: Net.wiredUp ? Theme.green : Theme.fgFaint
					font.family: Theme.fontIcon
					font.pixelSize: 17
				}

				Column {
					anchors.left: wiredIcon.right
					anchors.leftMargin: 12
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					spacing: 1

					Text {
						text: Net.wiredDevice !== null ? Net.wiredDevice.name : "No wired device"
						color: Theme.fg
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSize
						font.weight: Font.DemiBold
					}

					Text {
						width: parent.width
						elide: Text.ElideRight
						color: Theme.fgDim
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSizeSmall
						text: {
							const d = Net.wiredDevice;
							if (d === null)
								return "—";
							if (!d.hasLink)
								return "Cable unplugged";
							const ip = Net.addressFor(d);
							const speed = d.linkSpeed >= 1000 ? `${(d.linkSpeed / 1000).toFixed(1).replace(".0", "")} Gb/s` : `${d.linkSpeed} Mb/s`;
							return d.connected ? `${speed}${ip !== "" ? "  ·  " + ip : ""}` : `Link up (${speed}), not connected`;
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

			// -- wifi header ------------------------------------------------
			Item {
				width: parent.width
				height: 42

				Text {
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: "Wi-Fi"
					color: Theme.fg
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSize
					font.weight: Font.DemiBold
				}

				// Radio toggle
				Rectangle {
					id: toggle
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					width: 38
					height: 20
					radius: 10
					color: Net.wifiRadioOn ? Theme.blue : Theme.surfaceBright

					Behavior on color {
						ColorAnimation {
							duration: Theme.animFast
						}
					}

					Rectangle {
						width: 14
						height: 14
						radius: 7
						color: Net.wifiRadioOn ? Theme.base : Theme.fgDim
						anchors.verticalCenter: parent.verticalCenter
						x: Net.wifiRadioOn ? parent.width - width - 3 : 3

						Behavior on x {
							NumberAnimation {
								duration: Theme.animNormal
								easing.type: Easing.OutQuint
							}
						}
					}

					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: Net.toggleWifiRadio()
					}
				}
			}

			// -- network list -----------------------------------------------
			Text {
				visible: Net.wifiRadioOn && Net.wifiNetworks.length === 0
				x: 14
				bottomPadding: 10
				text: "Scanning…"
				color: Theme.fgFaint
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
			}

			Text {
				visible: !Net.wifiRadioOn
				x: 14
				bottomPadding: 10
				text: "Wi-Fi is off"
				color: Theme.fgFaint
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
			}

			ListView {
				width: parent.width
				height: Math.min(contentHeight, 260)
				visible: Net.wifiRadioOn && Net.wifiNetworks.length > 0
				clip: true
				interactive: contentHeight > height
				model: Net.wifiNetworks

				delegate: Rectangle {
					id: netRow

					required property var modelData

					readonly property bool isPending: root.pendingNetwork === modelData

					width: ListView.view.width
					height: isPending ? 78 : 40
					color: rowMouse.containsMouse || isPending ? Theme.surface : "transparent"

					Behavior on height {
						NumberAnimation {
							duration: Theme.animNormal
							easing.type: Easing.OutQuint
						}
					}

					Text {
						id: sigIcon
						anchors.left: parent.left
						anchors.leftMargin: 14
						y: 11
						text: Net.signalIcon(netRow.modelData.signalStrength)
						color: netRow.modelData.connected ? Theme.green : Theme.fgDim
						font.family: Theme.fontIcon
						font.pixelSize: 15
					}

					Text {
						id: ssid
						anchors.left: sigIcon.right
						anchors.leftMargin: 10
						y: 12
						width: netRow.width - 150
						elide: Text.ElideRight
						text: netRow.modelData.name
						color: Theme.fg
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSize
					}

					Text {
						anchors.right: parent.right
						anchors.rightMargin: 14
						y: 13
						text: {
							const n = netRow.modelData;
							if (n.stateChanging)
								return "…";
							if (n.connected)
								return rowMouse.containsMouse ? "disconnect" : "connected";
							if (n.known)
								return "saved";
							return n.security === WifiSecurityType.Open ? "open" : "󰌾";
						}
						color: netRow.modelData.connected ? Theme.green : Theme.fgFaint
						font.family: netRow.modelData.known || netRow.modelData.connected || netRow.modelData.stateChanging || netRow.modelData.security === WifiSecurityType.Open ? Theme.fontUi : Theme.fontIcon
						font.pixelSize: Theme.fontSizeSmall
					}

					MouseArea {
						id: rowMouse
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						height: 40
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.activate(netRow.modelData)
					}

					// Passphrase entry, revealed for unknown secured networks.
					Rectangle {
						visible: netRow.isPending
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.leftMargin: 14
						anchors.rightMargin: 14
						anchors.bottom: parent.bottom
						anchors.bottomMargin: 8
						height: 28
						radius: 7
						color: Theme.base
						border.width: 1
						border.color: Theme.outline

						TextInput {
							id: psk
							anchors.fill: parent
							anchors.leftMargin: 9
							anchors.rightMargin: 9
							verticalAlignment: TextInput.AlignVCenter
							echoMode: TextInput.Password
							color: Theme.fg
							font.family: Theme.fontUi
							font.pixelSize: Theme.fontSizeSmall
							clip: true
							focus: netRow.isPending

							onVisibleChanged: {
								if (visible)
									forceActiveFocus();
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								visible: psk.text === ""
								text: "Password, then Enter"
								color: Theme.fgFaint
								font: psk.font
							}

							Keys.onEscapePressed: root.pendingNetwork = null
							Keys.onReturnPressed: {
								netRow.modelData.connectWithPsk(psk.text);
								root.pendingNetwork = null;
								root.requestClose();
							}
						}
					}
				}
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
				height: 34

				Text {
					anchors.left: parent.left
					anchors.leftMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: Net.connectivityText
					color: Net.online ? Theme.fgDim : Theme.yellow
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall
				}

				Text {
					id: settingsLink
					anchors.right: parent.right
					anchors.rightMargin: 14
					anchors.verticalCenter: parent.verticalCenter
					text: "Editor"
					color: linkMouse.containsMouse ? Theme.blue : Theme.fgDim
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall

					MouseArea {
						id: linkMouse
						anchors.fill: parent
						anchors.margins: -6
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							Quickshell.execDetached(["nm-connection-editor"]);
							root.requestClose();
						}
					}
				}
			}
		}
	}
}
