pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which surfaces are open, and the screen they open on.
Singleton {
    id: root

    property bool controlOpen: false
    property string controlPage: "main" // main, wifi or bluetooth
    property bool calendarOpen: false
    property bool sessionOpen: false
    property bool caffeine: false

    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    // Panels follow the monitor that has focus.
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    function close() {
        controlOpen = false;
        calendarOpen = false;
    }
    // A click outside a panel closes it; ignore that same click reopening it from the bar.
    property double closedAt: 0
    function dismiss() {
        closedAt = Date.now();
        close();
    }
    function toggleControl() {
        const reopen = !controlOpen && Date.now() - closedAt > 250;
        close();
        if (reopen)
            controlPage = "main";
        controlOpen = reopen;
    }
    function openControl(page) {
        close();
        controlPage = page;
        controlOpen = true;
    }
    function toggleCalendar() {
        const reopen = !calendarOpen && Date.now() - closedAt > 250;
        close();
        calendarOpen = reopen;
    }
    function openSession() {
        close();
        sessionOpen = true;
    }

    function showOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(100, value));
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    function run(command) {
        Quickshell.execDetached(["bash", "-c", command]);
    }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
}
