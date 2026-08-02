import QtQuick
import qs.config

// Compact month grid for the clock's hover popup, replacing waybar's
// {calendar} tooltip.
Column {
	id: root

	property date today: new Date()

	readonly property int _year: today.getFullYear()
	readonly property int _month: today.getMonth()
	readonly property int _daysInMonth: new Date(_year, _month + 1, 0).getDate()
	// Grid starts on Sunday, matching the old waybar calendar.
	readonly property int _leading: new Date(_year, _month, 1).getDay()

	spacing: 8

	Text {
		anchors.horizontalCenter: parent.horizontalCenter
		text: Qt.formatDateTime(root.today, "MMMM yyyy")
		color: Theme.blue
		font.family: Theme.fontUi
		font.pixelSize: Theme.fontSize
		font.weight: Font.DemiBold
	}

	Grid {
		columns: 7
		spacing: 2

		Repeater {
			model: ["S", "M", "T", "W", "T", "F", "S"]

			delegate: Item {
				required property string modelData
				width: 24
				height: 18

				Text {
					anchors.centerIn: parent
					text: parent.modelData
					color: Theme.fgFaint
					font.family: Theme.fontUi
					font.pixelSize: Theme.fontSizeSmall
					font.weight: Font.DemiBold
				}
			}
		}

		// Blank cells before the 1st.
		Repeater {
			model: root._leading

			delegate: Item {
				width: 24
				height: 20
			}
		}

		Repeater {
			model: root._daysInMonth

			delegate: Rectangle {
				required property int index
				readonly property int day: index + 1
				readonly property bool isToday: day === root.today.getDate()

				width: 24
				height: 20
				radius: 6
				color: isToday ? Theme.blue : "transparent"

				Text {
					anchors.centerIn: parent
					text: parent.day
					color: parent.isToday ? Theme.base : Theme.fg
					font.family: Theme.fontMono
					font.pixelSize: Theme.fontSizeSmall
					font.weight: parent.isToday ? Font.Bold : Font.Normal
				}
			}
		}
	}
}
