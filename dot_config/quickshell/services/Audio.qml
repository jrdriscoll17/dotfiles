pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Thin wrapper over the default pipewire sink.
//
// PwObjectTracker is required: node properties (volume, mute) are only bound
// and kept live while something explicitly tracks the object.
Singleton {
	id: root

	readonly property PwNode sink: Pipewire.defaultAudioSink
	readonly property bool ready: sink !== null && sink.audio !== null
	readonly property real volume: ready ? sink.audio.volume : 0
	readonly property bool muted: ready ? sink.audio.muted : true
	readonly property string description: root.nameFor(sink)

	// Every real output device, ignoring per-application streams. Tracked as a
	// group so the picker can show live names and volumes for all of them.
	readonly property var sinks: {
		const out = [];
		for (const n of Pipewire.nodes.values) {
			if (!n.isSink || n.isStream)
				continue;
			if ((n.type & PwNodeType.Audio) === 0)
				continue;
			out.push(n);
		}
		return out;
	}

	PwObjectTracker {
		objects: root.sinks
	}

	function nameFor(node): string {
		if (node === null)
			return "No output";
		return node.description || node.nickname || node.name;
	}

	// Setting the preferred sink is sticky: pipewire keeps routing here until
	// the device disappears or another one is chosen.
	function setSink(node): void {
		Pipewire.preferredDefaultAudioSink = node;
	}

	function setVolume(v: real): void {
		if (!root.ready)
			return;
		root.sink.audio.volume = Math.max(0, Math.min(1, v));
	}

	function addVolume(delta: real): void {
		root.setVolume(root.volume + delta);
	}

	function toggleMute(): void {
		if (!root.ready)
			return;
		root.sink.audio.muted = !root.sink.audio.muted;
	}

	// Nerd Font speaker glyphs, picked by level the way the old waybar
	// format-icons array did.
	readonly property string icon: {
		if (!ready || muted)
			return "󰖁"; // 󰖁 muted
		if (volume < 0.01)
			return "󰕾"; // 󰕾 at zero
		if (volume < 0.34)
			return "󰕿"; // 󰕿
		if (volume < 0.67)
			return "󰖀"; // 󰖀
		return "󰕾"; // 󰕾
	}
}
