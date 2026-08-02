pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Icon-name lookup.
//
// Qt only resolves themed icon names when a platform theme plugin is installed.
// Without one (which is how this box was set up until qt6ct went in),
// `Quickshell.iconPath()` and `image://icon/...` fail for everything except
// absolute paths — the launcher showed letter placeholders and notifications
// showed broken-image tiles.
//
// So lookups try Qt first and fall back to generated/icons.json, an index of
// the active icon theme (and everything it inherits) written by `theme apply`.
// The index also covers names Qt misses, and keeps the shell working if the
// platform theme plugin ever goes away again.
Singleton {
	id: root

	property var index: ({})
	readonly property int count: Object.keys(root.index).length

	// The index is 2.5MB of JSON. Parsing it on every startup — and the shell
	// restarts on every theme switch and every config edit — is pure cost when
	// Qt can already resolve almost everything. So it loads on the first miss
	// and stays loaded.
	property bool indexWanted: false

	// Returns a usable Image/IconImage source, or "" if the name is unknown.
	// Absolute paths and URLs are handed back untouched.
	function path(name: string): string {
		if (!name)
			return "";

		if (name.startsWith("/"))
			return `file://${name}`;
		if (name.startsWith("file:") || name.startsWith("data:") || name.startsWith("qrc:"))
			return name;
		// Quickshell wraps icon names from notification hints in its own
		// provider URL, which fails for the same reason; unwrap and look the
		// name up here instead.
		if (name.startsWith("image://icon/"))
			return root.path(name.slice("image://icon/".length));
		// Some senders pass a full "org.foo.Bar.Baz" desktop id.
		if (name.includes("/"))
			return "";

		// Qt's own lookup first: with qt6ct installed it works, and it sees
		// icons installed after the index was last built.
		const native = Quickshell.iconPath(name, true);
		if (native !== "")
			return native;

		// A miss here is what pulls the index in; the binding re-evaluates once
		// it has loaded, so the caller gets its icon a frame or two later.
		if (!root.indexWanted)
			root.indexWanted = true;

		const hit = root.index[name];
		if (hit !== undefined)
			return `file://${hit}`;

		// Icon themes conventionally strip a -symbolic suffix.
		if (name.endsWith("-symbolic")) {
			const base = root.index[name.slice(0, -"-symbolic".length)];
			if (base !== undefined)
				return `file://${base}`;
		}

		return "";
	}

	// First name that resolves, so callers can express a preference order.
	function firstOf(names: var): string {
		for (const name of names) {
			const found = root.path(name);
			if (found !== "")
				return found;
		}
		return "";
	}

	FileView {
		path: root.indexWanted ? `${Quickshell.env("HOME")}/.config/quickshell/generated/icons.json` : ""
		watchChanges: root.indexWanted

		// Async: parse in onLoaded, never straight after a reload() call.
		onLoaded: {
			try {
				root.index = JSON.parse(text());
			} catch (e) {
				console.warn("Icons: could not parse the icon index:", e);
			}
		}

		onLoadFailed: console.warn("Icons: no icon index — run `theme apply`");
	}
}
