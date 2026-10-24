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

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
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
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.hidePopup(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 4);
        }
    }
}
