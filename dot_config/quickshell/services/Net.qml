pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// NetworkManager state, via Quickshell's native Networking module — no nm-applet.
//
// Note the device list populates asynchronously a second or two after startup;
// every accessor here has to tolerate an empty list rather than assume one.
Singleton {
	id: root

	readonly property var devices: Networking.devices.values

	// Prefer a wired device that's actually connected; fall back to one that at
	// least has carrier, so a half-up link still shows something useful.
	readonly property var wiredDevice: {
		let withLink = null;
		for (const d of devices) {
			if (d.type !== DeviceType.Wired)
				continue;
			if (d.connected)
				return d;
			if (d.hasLink && withLink === null)
				withLink = d;
		}
		return withLink;
	}

	readonly property var wifiDevice: {
		for (const d of devices) {
			if (d.type === DeviceType.Wifi)
				return d;
		}
		return null;
	}

	readonly property bool wiredUp: wiredDevice !== null && wiredDevice.connected
	readonly property bool wifiUp: wifiDevice !== null && wifiDevice.connected
	readonly property bool wifiRadioOn: Networking.wifiEnabled

	readonly property int connectivity: Networking.connectivity
	readonly property bool online: connectivity === NetworkConnectivity.Full
	// Unknown is common when NM's connectivity check is disabled, so treat a
	// connected device as good enough rather than crying wolf.
	readonly property bool degraded: !online && connectivity !== NetworkConnectivity.Unknown

	readonly property var activeWifiNetwork: {
		if (wifiDevice === null)
			return null;
		for (const n of wifiDevice.networks.values) {
			if (n.connected)
				return n;
		}
		return null;
	}

	readonly property string wifiSsid: activeWifiNetwork !== null ? activeWifiNetwork.name : ""
	readonly property real wifiSignal: activeWifiNetwork !== null ? activeWifiNetwork.signalStrength : 0

	// Networks sorted strongest first, with the connected one pinned to the top.
	readonly property var wifiNetworks: {
		if (wifiDevice === null)
			return [];
		const list = wifiDevice.networks.values.filter(n => n.name !== "");
		return list.sort((a, b) => {
			if (a.connected !== b.connected)
				return a.connected ? -1 : 1;
			if (a.known !== b.known)
				return a.known ? -1 : 1;
			return b.signalStrength - a.signalStrength;
		});
	}

	readonly property string primary: wiredUp ? "wired" : wifiUp ? "wifi" : "none"

	// -- addresses ----------------------------------------------------------
	// NetworkDevice.address is the MAC, so IPv4 comes from `ip` instead.
	property var ipv4: ({})

	function addressFor(dev): string {
		if (dev === null)
			return "";
		return root.ipv4[dev.name] ?? "";
	}

	Process {
		id: ipProc
		command: ["ip", "-j", "-4", "addr", "show"]

		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const map = {};
					for (const link of JSON.parse(text)) {
						const info = (link.addr_info ?? []).find(a => a.family === "inet");
						if (info)
							map[link.ifname] = `${info.local}/${info.prefixlen}`;
					}
					root.ipv4 = map;
				} catch (e) {
					// Transient parse failures aren't worth surfacing; the next
					// tick will pick up a clean read.
				}
			}
		}
	}

	Timer {
		interval: 10000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: ipProc.running = true
	}

	function refresh(): void {
		ipProc.running = true;
	}

	// Scanning is only worth its power cost while the panel is on screen.
	function setScanning(on: bool): void {
		if (root.wifiDevice !== null)
			root.wifiDevice.scannerEnabled = on;
	}

	function toggleWifiRadio(): void {
		Networking.wifiEnabled = !Networking.wifiEnabled;
	}

	// -- presentation -------------------------------------------------------
	function signalIcon(strength: real): string {
		const s = Math.max(0, Math.min(1, strength));
		if (s >= 0.8)
			return "󰤨";
		if (s >= 0.6)
			return "󰤥";
		if (s >= 0.4)
			return "󰤢";
		if (s >= 0.2)
			return "󰤟";
		return "󰤯";
	}

	readonly property string icon: {
		if (primary === "wired")
			return "󰈀";
		if (primary === "wifi")
			return signalIcon(wifiSignal);
		if (!wifiRadioOn)
			return "󰤭";
		return "󰤮";
	}

	readonly property string label: {
		if (primary === "wired")
			return "Eth";
		if (primary === "wifi")
			return wifiSsid !== "" ? wifiSsid : "Wi-Fi";
		return "Offline";
	}

	readonly property string connectivityText: NetworkConnectivity.toString(connectivity)
}
