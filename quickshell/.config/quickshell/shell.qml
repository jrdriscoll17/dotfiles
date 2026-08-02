import Quickshell
import Quickshell.Io
import qs.bar
import qs.launcher
import qs.notifications
import qs.services
import qs.theme

ShellRoot {
	// One bar per connected monitor; Variants tracks hotplug and the
	// enable/disable churn from the game-mode toggle in hyprland.lua.
	Variants {
		model: Quickshell.screens

		delegate: Bar {}
	}

	// Only built while open, so it always appears on the focused monitor.
	LazyLoader {
		active: LauncherState.open

		component: Launcher {}
	}

	// Notification popups. The window sizes itself to the cards and hides when
	// there are none, so this stays loaded rather than going through a
	// LazyLoader — the server behind it has to run either way.
	NotificationPopups {}

	// Theme picker (`qs ipc call theme toggle`, Super+Shift+T). Also only built
	// while open, and it disappears on its own when applying a theme rewrites
	// generated/Colors.qml and Quickshell reloads.
	LazyLoader {
		active: ThemeState.open

		component: ThemePicker {}
	}

	// `qs ipc call launcher toggle` — bound to Super+Shift+D in hyprland.lua.
	//
	// Avoid naming handlers after `qs ipc` subcommands (show, call, wait,
	// listen, prop): the CLI matches those first and never dispatches the call.
	IpcHandler {
		target: "launcher"

		function toggle(): void {
			LauncherState.toggle();
		}

		function open(): void {
			LauncherState.show();
		}

		function close(): void {
			LauncherState.hide();
		}
	}

	// `qs ipc call notifications dismiss` / `dnd`.
	IpcHandler {
		target: "notifications"

		function dismiss(): void {
			Notifs.dismissAll();
		}

		function dnd(): void {
			Notifs.toggleDnd();
		}
	}

	IpcHandler {
		target: "theme"

		function toggle(): void {
			ThemeState.toggle();
		}

		function open(): void {
			ThemeState.show();
		}

		function close(): void {
			ThemeState.hide();
		}
	}
}
