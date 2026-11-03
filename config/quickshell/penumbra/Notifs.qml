pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "sun.js" as Sun

// Notification daemon: popups for new notifications, history for the control center. Do not
// disturb comes on by hand, on a schedule, or by itself while you share the screen (recording,
// casting) or a window is fullscreen; per-app rules (Settings → Notifications) can keep an app's
// notifications out of the popups, drop them, or keep them past the history limit.
Singleton {
    id: root

    // By hand or by the schedule: the schedule sets it when its window starts and ends, so a
    // toggle by hand lasts until the next change, as with night light.
    property bool dndOn: false
    readonly property bool scheduled: Settings.dndSchedule
        && Sun.between(Clock.date.getHours() * 60 + Clock.date.getMinutes(), Sun.minutes(Settings.dndFrom), Sun.minutes(Settings.dndTo))
    onScheduledChanged: dndOn = scheduled
    Component.onCompleted: if (scheduled) dndOn = true
    // Recording, casting or a fullscreen window turn it on until they end; turning it off by
    // hand meanwhile holds until they do.
    readonly property bool sharing: Recorder.recording || Cast.casting || Cast.connecting
    readonly property bool fullscreen: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool autoQuiet: !!(Settings.dndWhileSharing && sharing || Settings.dndFullscreen && fullscreen)
    property bool autoDismissed: false
    onAutoQuietChanged: if (!autoQuiet) autoDismissed = false
    readonly property bool dnd: dndOn || autoQuiet && !autoDismissed
    readonly property string dndStatus: !dnd ? "Off"
        : dndOn && scheduled ? `Until ${Settings.dndTo} · only critical alerts`
        : dndOn ? "Only critical alerts"
        : sharing && Settings.dndWhileSharing ? "While you share the screen"
        : "While a window is fullscreen"
    function toggleDnd() {
        if (dnd) {
            dndOn = false;
            if (autoQuiet)
                autoDismissed = true;
        } else {
            dndOn = true;
        }
    }

    // The rule for an app: "" (normal), "silent", "mute" or "keep".
    function rule(app) {
        return Settings.notificationRules[app || "Notification"] ?? "";
    }
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
        if (n.transient && rule(n.appName) !== "keep")
            n.expire();
    }

    // A sound for a new popup (Settings → Notifications): the sound the app asks for, or the
    // sound theme's; never for low urgency or when the app asks for silence.
    function chime(n) {
        const hints = n.hints ?? {};
        if (!Settings.notificationSounds || n.urgency === NotificationUrgency.Low || hints["suppress-sound"])
            return;
        const asked = String(hints["sound-file"] ?? "");
        const sound = asked.startsWith("/") ? asked
            : "/usr/share/sounds/freedesktop/stereo/" + (n.urgency === NotificationUrgency.Critical ? "dialog-warning.oga" : "message-new-instant.oga");
        Quickshell.execDetached(["pw-play", sound]);
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
            const rule = root.rule(n.appName);
            // Muted: never tracked, so it is dropped at once.
            if (rule === "mute")
                return;
            n.tracked = true;
            root.received = Object.assign({}, root.received, { [n.id]: Date.now() });
            n.closed.connect(() => {
                root.hidePopup(n);
                const received = Object.assign({}, root.received);
                delete received[n.id];
                root.received = received;
            });
            const shown = rule !== "silent" && (!root.dnd || n.urgency === NotificationUrgency.Critical);
            if (shown)
                root.chime(n);
            if (shown) {
                const stack = [n, ...root.popups];
                root.popups = stack.slice(0, 4);
                // Pushed out of the stack counts as timed out, so transient ones still expire.
                for (const dropped of stack.slice(4))
                    root.retire(dropped);
            } else if (n.transient)
                Qt.callLater(() => n.expire());
            // Oldest first; keep the newest `limit`, apart from apps whose rule is to keep them.
            const all = server.trackedNotifications.values.filter(o => root.rule(o.appName) !== "keep");
            for (const old of all.slice(0, Math.max(0, all.length - root.limit)))
                old.expire();
        }
    }
}
