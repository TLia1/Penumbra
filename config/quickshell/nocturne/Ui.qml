pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Which surfaces are open, and the screen they open on.
Singleton {
    id: root

    property bool controlOpen: false
    property string controlPage: "main" // main, wifi, bluetooth or mixer
    property bool calendarOpen: false
    property bool monitorOpen: false
    property bool updatesOpen: false
    property bool wallpapersOpen: false
    property bool sessionOpen: false
    property bool launcherOpen: false
    property string launcherMode: "apps" // apps or clipboard
    property bool shotOpen: false
    property bool caffeine: false
    property bool nightLight: false

    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    // Panels follow the monitor that has focus.
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    function close() {
        controlOpen = false;
        calendarOpen = false;
        monitorOpen = false;
        updatesOpen = false;
        wallpapersOpen = false;
    }
    // Full-screen overlays replace each other and any open panel.
    function closeOverlays() {
        close();
        sessionOpen = false;
        launcherOpen = false;
        shotOpen = false;
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
    function toggleMonitor() {
        const reopen = !monitorOpen && Date.now() - closedAt > 250;
        close();
        monitorOpen = reopen;
    }
    function toggleUpdates() {
        const reopen = !updatesOpen && Date.now() - closedAt > 250;
        close();
        updatesOpen = reopen;
    }
    function toggleWallpapers() {
        const reopen = !wallpapersOpen && Date.now() - closedAt > 250;
        close();
        wallpapersOpen = reopen;
    }
    function openSession() {
        closeOverlays();
        sessionOpen = true;
    }
    function toggleLauncher(mode) {
        const reopen = !(launcherOpen && launcherMode === mode);
        closeOverlays();
        launcherMode = mode;
        launcherOpen = reopen;
    }
    function openShot() {
        closeOverlays();
        shotOpen = true;
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

    // The chosen wallpaper (wallpaper, wallpaper-dawn…), as nocturne-wallpaper records it.
    property string wallpaper: "wallpaper"
    readonly property string wallpapers: Quickshell.env("HOME") + "/.local/share/nocturne/"
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/nocturne/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().trim() || "wallpaper"
    }

    // Optional tools, found once at startup.
    property bool hasNightLight: false
    property bool hasVisualizer: false
    Process {
        running: true
        command: ["bash", "-c", "command -v hyprsunset; command -v cava"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNightLight = text.includes("/hyprsunset");
                root.hasVisualizer = text.includes("/cava");
            }
        }
    }
    // Night light: hyprsunset warms the screen for as long as it runs.
    readonly property int nightTemperature: 4500
    Process {
        running: root.nightLight && root.hasNightLight
        command: ["hyprsunset", "--temperature", String(root.nightTemperature)]
    }

    function run(command) {
        Quickshell.execDetached(["bash", "-c", command]);
    }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
}
