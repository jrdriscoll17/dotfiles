pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// CPU / memory / disk sampling.
//
// CPU and memory come straight from /proc via FileView (cheap, no subprocess).
// Disk needs df, so it runs on a much slower timer.
Singleton {
	id: root

	// cpu
	property real cpuUsage: 0 // 0..1
	property real cpuGhz: 0

	// memory (GiB)
	property real memUsed: 0
	property real memTotal: 0
	readonly property real memRatio: memTotal > 0 ? memUsed / memTotal : 0

	// disk, for /
	property string diskAvail: "--"
	property string diskSize: "--"
	property string diskUsed: "--"
	property real diskRatio: 0

	property int _lastTotal: 0
	property int _lastIdle: 0

	// /proc/stat's first line is aggregate jiffies since boot; usage is the
	// delta between samples, so the first tick only establishes a baseline.
	FileView {
		id: statFile
		path: "/proc/stat"
		printErrors: false

		onLoaded: {
			const fields = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
			if (fields.length < 5)
				return;

			const total = fields.reduce((a, b) => a + b, 0);
			const idle = fields[3] + fields[4]; // idle + iowait

			const dTotal = total - root._lastTotal;
			const dIdle = idle - root._lastIdle;

			if (root._lastTotal > 0 && dTotal > 0) {
				root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
			}

			root._lastTotal = total;
			root._lastIdle = idle;
		}
	}

	FileView {
		id: memFile
		path: "/proc/meminfo"
		printErrors: false

		onLoaded: {
			const kb = {};
			for (const line of text().split("\n")) {
				const m = line.match(/^(\w+):\s+(\d+)/);
				if (m)
					kb[m[1]] = parseInt(m[2]);
			}
			if (!kb.MemTotal)
				return;

			// MemAvailable is the honest "what a new process could get" number,
			// unlike MemFree which ignores reclaimable cache.
			const avail = kb.MemAvailable !== undefined ? kb.MemAvailable : kb.MemFree;
			root.memTotal = kb.MemTotal / 1048576;
			root.memUsed = (kb.MemTotal - avail) / 1048576;
		}
	}

	FileView {
		id: freqFile
		path: "/proc/cpuinfo"
		printErrors: false

		onLoaded: {
			let max = 0;
			for (const line of text().split("\n")) {
				const m = line.match(/^cpu MHz\s*:\s*([\d.]+)/);
				if (m)
					max = Math.max(max, parseFloat(m[1]));
			}
			if (max > 0)
				root.cpuGhz = max / 1000;
		}
	}

	Process {
		id: dfProc
		command: ["df", "-P", "-h", "/"]
		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.trim().split("\n");
				if (lines.length < 2)
					return;

				const f = lines[1].trim().split(/\s+/);
				if (f.length < 5)
					return;

				root.diskSize = f[1];
				root.diskUsed = f[2];
				root.diskAvail = f[3];
				root.diskRatio = parseFloat(f[4].replace("%", "")) / 100;
			}
		}
	}

	Timer {
		interval: 2000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			statFile.reload();
			memFile.reload();
			freqFile.reload();
		}
	}

	Timer {
		interval: 60000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: dfProc.running = true
	}
}
