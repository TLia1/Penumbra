pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon: popups for new notifications, history for the control center.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
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
            n.closed.connect(() => root.hidePopup(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 4);
        }
    }
}
