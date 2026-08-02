pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Battery state, straight from sysfs — no upower dependency, and cheap enough
// to poll on the same cadence as the other metrics.
//
// `available` is what keeps this off the desktops: the bar is one config across
// every machine, so the widget has to decide for itself whether it applies
// rather than being templated in per host. No BAT* directory means no battery,
// which is the same signal hydra uses to pick host-specific components.
Singleton {
	id: root

	property bool available: false
	property int percent: 0
	// "Charging", "Discharging", "Full", "Not charging", "Unknown"
	property string status: "Unknown"
	// Seconds remaining, or 0 when it cannot be worked out.
	property int secondsLeft: 0

	readonly property bool charging: status === "Charging" || status === "Full"
	readonly property bool critical: !charging && percent <= 10
	readonly property bool low: !charging && percent <= 20

	// Which BAT* the kernel gave us. Some machines have BAT1 and no BAT0.
	property string _dir: ""

	readonly property string icon: {
		if (!available)
			return "";
		if (charging)
			return "󰂄";
		if (percent >= 90)
			return "󰁹";
		if (percent >= 70)
			return "󰂀";
		if (percent >= 50)
			return "󰁾";
		if (percent >= 30)
			return "󰁼";
		if (percent >= 15)
			return "󰁺";
		return "󰂎";
	}

	readonly property string timeLabel: {
		if (secondsLeft <= 0)
			return "";
		const h = Math.floor(secondsLeft / 3600);
		const m = Math.floor((secondsLeft % 3600) / 60);
		return h > 0 ? `${h}h ${m}m` : `${m}m`;
	}

	// Finding the battery is a one-off: hotplugging one is not a case worth
	// polling for.
	Process {
		id: findProc
		command: ["sh", "-c", "ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1"]
		running: true
		stdout: StdioCollector {
			onStreamFinished: {
				const path = text.trim();
				if (path === "")
					return; // desktop: stays unavailable, widget stays hidden
				root._dir = path;
				root.available = true;
				poll.triggeredOnStart = true;
				poll.running = true;
			}
		}
	}

	FileView {
		id: capacityFile
		path: root._dir === "" ? "" : root._dir + "/capacity"
		printErrors: false
		onLoaded: {
			const n = parseInt(text().trim());
			if (!isNaN(n))
				root.percent = Math.max(0, Math.min(100, n));
		}
	}

	FileView {
		id: statusFile
		path: root._dir === "" ? "" : root._dir + "/status"
		printErrors: false
		onLoaded: {
			const s = text().trim();
			if (s !== "")
				root.status = s;
		}
	}

	// Time remaining needs charge and current, and the kernel exposes either
	// charge_* (µAh) or energy_* (µWh) depending on the driver. Missing files
	// simply leave the estimate at zero rather than erroring.
	FileView {
		id: chargeNowFile
		path: root._dir === "" ? "" : root._dir + "/charge_now"
		printErrors: false
		onLoaded: root._recompute()
	}

	FileView {
		id: currentNowFile
		path: root._dir === "" ? "" : root._dir + "/current_now"
		printErrors: false
		onLoaded: root._recompute()
	}

	FileView {
		id: energyNowFile
		path: root._dir === "" ? "" : root._dir + "/energy_now"
		printErrors: false
		onLoaded: root._recompute()
	}

	FileView {
		id: powerNowFile
		path: root._dir === "" ? "" : root._dir + "/power_now"
		printErrors: false
		onLoaded: root._recompute()
	}

	function _num(view: var): real {
		try {
			const n = parseFloat(view.text().trim());
			return isNaN(n) ? 0 : n;
		} catch (e) {
			return 0;
		}
	}

	function _recompute(): void {
		// Charge/current is the common pair; energy/power is the fallback. Both
		// give hours once divided, so the arithmetic is the same either way.
		let remaining = root._num(chargeNowFile);
		let rate = root._num(currentNowFile);
		if (remaining === 0 || rate === 0) {
			remaining = root._num(energyNowFile);
			rate = root._num(powerNowFile);
		}

		if (remaining <= 0 || rate <= 0) {
			root.secondsLeft = 0;
			return;
		}
		// While charging the interesting figure is time to full, not time to
		// empty, so measure the gap up to 100%.
		if (root.charging) {
			const full = root.percent > 0 ? remaining * 100 / root.percent : 0;
			remaining = Math.max(0, full - remaining);
		}
		root.secondsLeft = Math.round(remaining / rate * 3600);
	}

	Timer {
		id: poll
		interval: 10000
		running: false
		repeat: true
		onTriggered: {
			capacityFile.reload();
			statusFile.reload();
			chargeNowFile.reload();
			currentNowFile.reload();
			energyNowFile.reload();
			powerNowFile.reload();
		}
	}
}
