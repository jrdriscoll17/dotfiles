pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Notification daemon, replacing mako.
//
// Quickshell owns the org.freedesktop.Notifications name while this is loaded,
// so mako must not be running at the same time — whichever claims the bus name
// first wins and the other silently receives nothing.
Singleton {
	id: root

	// Popups currently on screen, newest first. Notification objects live as
	// long as they are tracked; dropping one from here also stops tracking it.
	property var popups: []

	// Everything seen this session, newest first, capped — the drawer reads
	// this, so dismissing a popup doesn't lose the message.
	property var history: []

	readonly property int historyLimit: 50

	// Suppresses popups without dropping notifications: they still land in
	// history, so nothing is missed while it's on.
	property bool doNotDisturb: false

	readonly property int count: popups.length

	// How long a popup sits there before expiring. Senders may request their
	// own timeout; anything critical stays until it's acted on, which is what
	// mako did too.
	function timeoutFor(notif): int {
		if (notif.urgency === NotificationUrgency.Critical)
			return 0;
		if (notif.expireTimeout > 0)
			return notif.expireTimeout;
		return notif.urgency === NotificationUrgency.Low ? 5000 : 8000;
	}

	function dismiss(notif): void {
		root.popups = root.popups.filter(n => n !== notif);
		// Tell the sender it's gone; resident notifications (media players)
		// expect dismiss rather than a silent drop.
		notif.dismiss();
	}

	function dismissAll(): void {
		const open = root.popups;
		root.popups = [];
		for (const n of open)
			n.dismiss();
	}

	function clearHistory(): void {
		root.history = [];
	}

	function toggleDnd(): void {
		root.doNotDisturb = !root.doNotDisturb;
		if (root.doNotDisturb)
			root.popups = [];
	}

	NotificationServer {
		id: server

		// Persistence keeps notifications across a shell reload, which happens
		// on every theme switch and every config edit.
		keepOnReload: true

		bodySupported: true
		bodyMarkupSupported: true
		bodyImagesSupported: true
		actionsSupported: true
		actionIconsSupported: true
		imageSupported: true
		persistenceSupported: true

		onNotification: notif => {
			// Without this the server drops the notification as soon as the
			// signal handler returns.
			notif.tracked = true;

			root.history = [notif, ...root.history].slice(0, root.historyLimit);

			if (!root.doNotDisturb)
				root.popups = [notif, ...root.popups];

			// A notification closed by the sender (or by an action) has to
			// leave the popup list too.
			notif.closed.connect(() => {
				root.popups = root.popups.filter(n => n !== notif);
			});
		}
	}
}
