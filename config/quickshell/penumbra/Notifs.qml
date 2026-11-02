pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon: popups for new notifications, history for the control center.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    // The history keeps this many notifications; older ones expire.
    readonly property int limit: 50
    // When each notification arrived (Date.now()), by id.
    property var received: ({})
    // Newest first.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length
    // History by app, newest first: [{ app, items }].
    readonly property var groups: {
        const groups = [];
        for (const n of history) {
            const app = n.appName || "Notification";
            let group = groups.find(g => g.app === app);
            if (!group)
                groups.push(group = { app, items: [] });
            group.items.push(n);
        }
        return groups;
    }

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
    }
    function clearApp(app) {
        for (const n of history.filter(n => (n.appName || "Notification") === app))
            n.dismiss();
    }
    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    // A popup timed out: transient notifications go away instead of into the history.
    function retire(n) {
        hidePopup(n);
        if (n.transient)
            n.expire();
    }
    // "now", "5 min", "2 h", "yesterday" or the date; `now` is passed in so callers update with the clock.
    function age(n, now) {
        const at = received[n.id];
        if (!at)
            return "";
        const minutes = Math.floor((now - at) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes} min`;
        if (minutes < 24 * 60)
            return `${Math.floor(minutes / 60)} h`;
        return minutes < 48 * 60 ? "yesterday" : Qt.formatDate(new Date(at), "d MMM");
    }
    // Milliseconds a popup stays up (expireTimeout is already in ms); critical ones wait for the user.
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? Math.min(n.expireTimeout, 20000) : 6000;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.received = Object.assign({}, root.received, { [n.id]: Date.now() });
            n.closed.connect(() => {
                root.hidePopup(n);
                const received = Object.assign({}, root.received);
                delete received[n.id];
                root.received = received;
            });
            const shown = !root.dnd || n.urgency === NotificationUrgency.Critical;
            if (shown) {
                const stack = [n, ...root.popups];
                root.popups = stack.slice(0, 4);
                // Pushed out of the stack counts as timed out, so transient ones still expire.
                for (const dropped of stack.slice(4))
                    root.retire(dropped);
            } else if (n.transient)
                Qt.callLater(() => n.expire());
            // Oldest first; keep the newest `limit`.
            const all = server.trackedNotifications.values;
            for (const old of all.slice(0, Math.max(0, all.length - root.limit)))
                old.expire();
        }
    }
}
