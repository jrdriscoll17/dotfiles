import QtQuick
import qs.config
import qs.components
import qs.services

// Charge indicator. Hides itself entirely on a machine with no battery, so the
// same bar config runs unchanged on the desktops.
Pill {
	id: root

	visible: Battery.available
	// A hidden Pill must take no space either, or the bar's right-hand group
	// keeps a gap where it would have been.
	width: visible ? implicitWidth : 0

	interactive: false

	tooltipText: {
		if (!Battery.available)
			return "";
		let s = `Battery ${Battery.percent}%\n${Battery.status}`;
		if (Battery.timeLabel !== "")
			s += Battery.charging ? `\n${Battery.timeLabel} until full` : `\n${Battery.timeLabel} remaining`;
		return s;
	}

	spacing: 5

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: Battery.icon
		font.family: Theme.fontIcon
		font.pixelSize: Theme.fontSizeIcon
		color: {
			if (Battery.charging)
				return Theme.green;
			if (Battery.critical)
				return Theme.red;
			if (Battery.low)
				return Theme.orange;
			return Theme.cyan;
		}

		// Only the genuinely urgent state pulses — a low battery that is
		// charging is not a problem, and a permanently animated bar is noise.
		SequentialAnimation on opacity {
			running: Battery.critical && !Battery.charging
			loops: Animation.Infinite
			alwaysRunToEnd: true
			NumberAnimation {
				to: 0.35
				duration: 900
				easing.type: Easing.InOutQuad
			}
			NumberAnimation {
				to: 1.0
				duration: 900
				easing.type: Easing.InOutQuad
			}
		}
	}

	Item {
		anchors.verticalCenter: parent.verticalCenter
		// Widest reading is "100%", matching VolumeWidget's measured width so
		// the two pills line up.
		implicitWidth: 27
		implicitHeight: label.implicitHeight

		Text {
			id: label

			anchors.horizontalCenter: parent.horizontalCenter
			text: `${Battery.percent}%`
			color: Battery.critical && !Battery.charging ? Theme.red : Theme.fg
			font.family: Theme.fontMono
			font.pixelSize: Theme.fontSize
		}
	}
}
