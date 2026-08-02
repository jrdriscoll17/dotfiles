import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import QtQuick
import qs.config
import qs.services

// Application launcher, replacing `wofi --show drun`.
//
// Full-screen overlay on whichever monitor currently has focus, with an
// exclusive keyboard grab so typing goes straight to the search field.
PanelWindow {
	id: root

	// Opens on the focused monitor rather than always on the primary one.
	screen: {
		const name = Hyprland.focusedMonitor?.name ?? "";
		for (const s of Quickshell.screens) {
			if (s.name === name)
				return s;
		}
		return Quickshell.screens[0];
	}

	WlrLayershell.namespace: "quickshell:launcher"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	// Ignore the bars' exclusive zones so the overlay really is full-screen,
	// rather than starting below the bar.
	exclusionMode: ExclusionMode.Ignore

	color: Theme.alpha("#000000", 0.35)

	property string query: ""
	property int selected: 0

	readonly property var entries: {
		const q = root.query.trim().toLowerCase();
		const scored = [];

		for (const app of DesktopEntries.applications.values) {
			if (app.noDisplay)
				continue;

			const s = root.scoreEntry(app, q);
			if (s >= 0)
				scored.push({
					app: app,
					score: s
				});
		}

		scored.sort((a, b) => b.score - a.score || a.app.name.localeCompare(b.app.name));
		return scored.slice(0, 40).map(e => e.app);
	}

	// Ranking: exact prefix beats substring beats a scattered subsequence,
	// with metadata (generic name, comment, keywords) worth the least.
	function scoreEntry(app: DesktopEntry, q: string): int {
		if (q === "")
			return 0;

		const name = (app.name ?? "").toLowerCase();

		if (name.startsWith(q))
			return 1000 - name.length;

		const idx = name.indexOf(q);
		if (idx >= 0)
			return 800 - idx;

		if (root.isSubsequence(q, name))
			return 500;

		const meta = [app.genericName ?? "", app.comment ?? ""].concat(app.keywords ?? []).join(" ").toLowerCase();
		if (meta.includes(q))
			return 200;

		return -1;
	}

	function isSubsequence(needle: string, haystack: string): bool {
		let i = 0;
		for (let j = 0; j < haystack.length && i < needle.length; j++) {
			if (haystack[j] === needle[i])
				i++;
		}
		return i === needle.length;
	}

	function launch(app: DesktopEntry): void {
		if (!app)
			return;
		app.execute();
		LauncherState.hide();
	}

	onEntriesChanged: selected = 0

	// Rows only take the selection from the pointer once this is armed. Opening
	// the launcher delivers a hover event for whatever row materialises under a
	// stationary cursor, which would otherwise steal the selection from the top
	// match before the user has touched the mouse.
	property bool hoverArmed: false

	Timer {
		interval: 300
		running: true
		onTriggered: root.hoverArmed = true
	}

	// Clicking the dimmed backdrop dismisses.
	MouseArea {
		anchors.fill: parent
		onClicked: LauncherState.hide()
	}

	Rectangle {
		id: panel

		anchors.horizontalCenter: parent.horizontalCenter
		y: parent.height * 0.18
		width: 620
		height: Math.min(560, header.height + Math.max(list.contentHeight, 60) + 24)

		radius: 16
		color: Theme.alpha(Theme.base, 0.97)
		border.width: 1
		border.color: Theme.outline

		// Swallow clicks so they don't reach the dismiss handler behind.
		MouseArea {
			anchors.fill: parent
		}

		Item {
			id: header

			anchors.top: parent.top
			anchors.left: parent.left
			anchors.right: parent.right
			height: 62

			Text {
				id: searchIcon
				anchors.left: parent.left
				anchors.leftMargin: 20
				anchors.verticalCenter: parent.verticalCenter
				text: "󰍉"
				color: Theme.blue
				font.family: Theme.fontIcon
				font.pixelSize: 18
			}

			TextInput {
				id: input

				anchors.left: searchIcon.right
				anchors.leftMargin: 12
				anchors.right: parent.right
				anchors.rightMargin: 20
				anchors.verticalCenter: parent.verticalCenter

				color: Theme.fg
				font.family: Theme.fontUi
				font.pixelSize: 17
				selectionColor: Theme.alpha(Theme.blue, 0.4)
				selectedTextColor: Theme.fg
				clip: true

				focus: true
				onTextChanged: root.query = text

				Text {
					anchors.verticalCenter: parent.verticalCenter
					visible: input.text === ""
					text: "Search applications"
					color: Theme.fgFaint
					font: input.font
				}

				Keys.onEscapePressed: LauncherState.hide()
				Keys.onReturnPressed: root.launch(root.entries[root.selected])
				Keys.onEnterPressed: root.launch(root.entries[root.selected])

				Keys.onDownPressed: {
					if (root.entries.length > 0)
						root.selected = (root.selected + 1) % root.entries.length;
				}

				Keys.onUpPressed: {
					if (root.entries.length > 0)
						root.selected = (root.selected - 1 + root.entries.length) % root.entries.length;
				}

				Keys.onTabPressed: {
					if (root.entries.length > 0)
						root.selected = (root.selected + 1) % root.entries.length;
				}
			}

			Rectangle {
				anchors.bottom: parent.bottom
				anchors.left: parent.left
				anchors.right: parent.right
				anchors.leftMargin: 14
				anchors.rightMargin: 14
				height: 1
				color: Theme.outline
			}
		}

		ListView {
			id: list

			anchors.top: header.bottom
			anchors.topMargin: 8
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.bottom: parent.bottom
			anchors.bottomMargin: 12
			anchors.leftMargin: 8
			anchors.rightMargin: 8

			clip: true
			model: root.entries
			currentIndex: root.selected
			highlightMoveDuration: Theme.animFast
			// Keep the selection in view when driven from the keyboard.
			highlightRangeMode: ListView.ApplyRange
			preferredHighlightBegin: 40
			preferredHighlightEnd: height - 40

			delegate: Rectangle {
				id: entryRow

				required property int index
				required property DesktopEntry modelData

				width: list.width
				height: 52
				radius: 10
				color: index === root.selected ? Theme.alpha(Theme.blue, 0.22) : rowMouse.containsMouse ? Theme.surface : "transparent"

				Behavior on color {
					ColorAnimation {
						duration: Theme.animFast
					}
				}

				// Icons.path() consults the generated index; anything it can't
				// place falls back to a letter tile rather than Qt's magenta
				// "broken image" checker.
				readonly property string iconSource: {
					const own = Icons.path(modelData.icon ?? "");
					if (own !== "")
						return own;
					return Icons.path("application-x-executable");
				}

				Item {
					id: entryIcon
					anchors.left: parent.left
					anchors.leftMargin: 12
					anchors.verticalCenter: parent.verticalCenter
					implicitWidth: 32
					implicitHeight: 32

					IconImage {
						anchors.centerIn: parent
						implicitSize: 32
						visible: entryRow.iconSource !== ""
						source: entryRow.iconSource
					}

					Rectangle {
						anchors.fill: parent
						visible: entryRow.iconSource === ""
						radius: 8
						color: Theme.surfaceBright

						Text {
							anchors.centerIn: parent
							text: (entryRow.modelData.name ?? "?").charAt(0).toUpperCase()
							color: Theme.fgDim
							font.family: Theme.fontUi
							font.pixelSize: 16
							font.weight: Font.Bold
						}
					}
				}

				Column {
					anchors.left: entryIcon.right
					anchors.leftMargin: 14
					anchors.right: parent.right
					anchors.rightMargin: 12
					anchors.verticalCenter: parent.verticalCenter
					spacing: 2

					Text {
						width: parent.width
						text: entryRow.modelData.name
						color: Theme.fg
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSize + 1
						font.weight: Font.DemiBold
						elide: Text.ElideRight
					}

					Text {
						width: parent.width
						visible: text !== ""
						text: entryRow.modelData.comment || entryRow.modelData.genericName || ""
						color: Theme.fgDim
						font.family: Theme.fontUi
						font.pixelSize: Theme.fontSizeSmall
						elide: Text.ElideRight
					}
				}

				MouseArea {
					id: rowMouse
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onPositionChanged: {
						if (root.hoverArmed)
							root.selected = entryRow.index;
					}
					onClicked: root.launch(entryRow.modelData)
				}
			}
		}

		Text {
			anchors.centerIn: list
			visible: root.entries.length === 0
			text: "No matches"
			color: Theme.fgFaint
			font.family: Theme.fontUi
			font.pixelSize: Theme.fontSize
		}
	}
}
