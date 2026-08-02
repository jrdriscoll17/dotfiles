import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import qs.config
import qs.services

// One notification, used both as a popup and as a history row.
Rectangle {
	id: root

	required property var notif

	// Popups count down and can be dismissed; history rows just sit there.
	property bool showTimeout: true

	signal closed

	implicitHeight: layout.implicitHeight + 20
	radius: 14
	color: Theme.alpha(Theme.surface, 0.96)
	border.width: 1
	// Critical notifications keep mako's red edge; everything else uses the
	// same outline as the bar's pills.
	border.color: root.notif.urgency === NotificationUrgency.Critical ? Theme.red : Theme.pillBorder

	// Fade/slide in from the right, matching the direction they stack.
	opacity: 0
	x: 20

	Component.onCompleted: {
		root.opacity = 1;
		root.x = 0;
	}

	Behavior on opacity {
		NumberAnimation {
			duration: Theme.animNormal
		}
	}

	Behavior on x {
		NumberAnimation {
			duration: Theme.animNormal
			easing.type: Easing.OutCubic
		}
	}

	readonly property int timeout: Notifs.timeoutFor(root.notif)

	Timer {
		id: expiry

		// A zero timeout means "until acted on" — critical notifications, or a
		// sender that asked for persistence.
		running: root.showTimeout && root.timeout > 0 && !hover.hovered
		interval: root.timeout
		onTriggered: Notifs.dismiss(root.notif)
	}

	HoverHandler {
		id: hover
	}

	// Body click: run the default action if the sender provided one (that's
	// what "click the notification" means to most apps), otherwise dismiss.
	TapHandler {
		onTapped: {
			const def = root.defaultAction();
			if (def !== null)
				def.invoke();
			else if (root.showTimeout)
				Notifs.dismiss(root.notif);
		}
	}

	function defaultAction(): var {
		for (const action of root.notif.actions) {
			if (action.identifier === "default")
				return action;
		}
		return null;
	}

	// Actions worth drawing as buttons — the default one is the body click, so
	// showing it again would just be a second copy of the same thing.
	readonly property var visibleActions: {
		const out = [];
		for (const action of root.notif.actions) {
			if (action.identifier !== "default")
				out.push(action);
		}
		return out;
	}

	Row {
		id: layout

		anchors.left: parent.left
		anchors.right: parent.right
		anchors.top: parent.top
		anchors.margins: 10
		spacing: 10

		// The sender's image (album art, avatar) if there is one, otherwise the
		// app's icon, otherwise a bell. Plenty of senders (notify-send without
		// -i, cron scripts) provide neither, and an unresolvable icon name
		// renders as a broken-image placeholder rather than nothing.
		Item {
			id: badge

			width: 34
			height: 34

			// Senders are inconsistent: `image` may be real album art, a file path,
			// or (from notify-send -i) just an icon name wrapped in Quickshell's
			// image:// provider URL, which does not resolve here. Icons.path()
			// sorts all of those out and returns "" when nothing is usable.
			readonly property bool hasArt: {
				const img = root.notif.image;
				return img.startsWith("/") || img.startsWith("file:") || img.startsWith("data:");
			}

			readonly property string iconSource: Icons.firstOf([root.notif.image, root.notif.appIcon, root.notif.desktopEntry, root.notif.appName.toLowerCase()])

			Image {
				anchors.fill: parent
				visible: badge.hasArt
				source: badge.hasArt ? root.notif.image : ""
				fillMode: Image.PreserveAspectCrop
				sourceSize.width: 68
				sourceSize.height: 68
			}

			IconImage {
				anchors.centerIn: parent
				visible: !badge.hasArt && badge.iconSource !== ""
				implicitSize: 30
				source: badge.iconSource
			}

			// Nothing usable from the sender: a bell rather than a hole.
			Text {
				anchors.centerIn: parent
				visible: !badge.hasArt && badge.iconSource === ""
				text: "󰂚"
				color: root.notif.urgency === NotificationUrgency.Critical ? Theme.red : Theme.fgDim
				font.family: Theme.fontIcon
				font.pixelSize: 22
			}
		}

		Column {
			width: parent.width - 34 - layout.spacing
			spacing: 3

			Row {
				width: parent.width
				spacing: 6

				Text {
					width: parent.width - closeButton.width - parent.spacing
					text: root.notif.summary
					color: Theme.fg
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSize
					font.weight: Font.DemiBold
					elide: Text.ElideRight
				}

				// Only while hovered: a permanent × on every card is noise.
				Text {
					id: closeButton

					text: "✕"
					color: closeMouse.containsMouse ? Theme.red : Theme.fgDim
					opacity: hover.hovered ? 1 : 0
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall

					Behavior on opacity {
						NumberAnimation {
							duration: Theme.animFast
						}
					}

					MouseArea {
						id: closeMouse

						anchors.fill: parent
						anchors.margins: -5
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							if (root.showTimeout)
								Notifs.dismiss(root.notif);
							root.closed();
						}
					}
				}
			}

			Text {
				width: parent.width
				visible: text !== ""
				text: root.notif.body
				color: Theme.fgDim
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
				wrapMode: Text.WordWrap
				maximumLineCount: 6
				elide: Text.ElideRight
				// Senders may send Pango-ish markup; Text renders the subset it
				// understands and drops the rest rather than showing tags.
				textFormat: Text.StyledText
			}

			Text {
				visible: root.notif.appName !== ""
				text: root.notif.appName
				color: Theme.fgFaint
				font.family: Theme.fontUi
				font.pixelSize: Theme.fontSizeSmall
			}

			Row {
				spacing: 6
				visible: root.visibleActions.length > 0
				topPadding: 4

				Repeater {
					model: root.visibleActions

					delegate: Rectangle {
						id: actionButton

						required property var modelData

						implicitWidth: actionLabel.implicitWidth + 18
						implicitHeight: 24
						radius: height / 2
						color: actionMouse.containsMouse ? Theme.surfaceBright : Theme.alpha(Theme.base, 0.6)
						border.width: 1
						border.color: Theme.pillBorder

						Text {
							id: actionLabel

							anchors.centerIn: parent
							text: actionButton.modelData.text
							color: Theme.fg
							font.family: Theme.fontUi
							font.pixelSize: Theme.fontSizeSmall
						}

						MouseArea {
							id: actionMouse

							anchors.fill: parent
							hoverEnabled: true
							cursorShape: Qt.PointingHandCursor
							onClicked: actionButton.modelData.invoke()
						}
					}
				}
			}
		}
	}

	// Time remaining, as a hairline along the bottom edge. Hovering stops the
	// timer and the bar together — both restart from full when the pointer
	// leaves, so what you see is what the card will do.
	Item {
		id: progressTrack

		anchors.bottom: parent.bottom
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottomMargin: 3
		anchors.leftMargin: 8
		anchors.rightMargin: 8
		height: 2
		visible: root.showTimeout && root.timeout > 0

		Rectangle {
			height: parent.height
			radius: 1
			color: Theme.alpha(Theme.accent, 0.7)
			width: progressTrack.width

			NumberAnimation on width {
				from: progressTrack.width
				to: 0
				duration: root.timeout
				running: expiry.running
			}
		}
	}
}
