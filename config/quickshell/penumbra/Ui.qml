pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Which surfaces are open, and the screen they open on.
Singleton {
    id: root

    // At most one panel is open: control, calendar, monitor, updates, wallpapers, or "".
    property string openPanel: ""
    readonly property bool controlOpen: openPanel === "control"
    readonly property bool calendarOpen: openPanel === "calendar"
    readonly property bool monitorOpen: openPanel === "monitor"
    readonly property bool updatesOpen: openPanel === "updates"
    readonly property bool wallpapersOpen: openPanel === "wallpapers"
    property string controlPage: "main" // main, wifi, bluetooth, mixer, night, cast, notifications, settings or a settings page
    property bool sessionOpen: false
    property bool launcherOpen: false
    property string launcherMode: "apps" // apps, windows, clipboard, emoji or symbols
    property bool shotOpen: false
    property bool overviewOpen: false
    property bool caffeine: false
    // Open apps from Settings → Idle and sleep that keep the screen awake (by app id).
    readonly property var awakeApps: ToplevelManager.toplevels.values.map(t => t.appId).filter(a => Settings.idleInhibitApps.includes(a))
    readonly property bool stayAwake: caffeine || awakeApps.length > 0

    property string osdKind: "volume" // volume, microphone, brightness, or capslock and layout (text only)
    property int osdValue: 0
    property bool osdMuted: false
    property string osdText: ""
    property bool osdVisible: false

    // Panels follow the monitor that has focus.
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // Capsule centers in screen-local coordinates, published by each monitor's bar.
    property var panelOrigins: ({})
    function setPanelOrigins(name, origins) {
        panelOrigins = Object.assign({}, panelOrigins, { [name]: origins });
    }

    function close() {
        openPanel = "";
    }
    // Full-screen overlays replace each other and any open panel.
    function closeOverlays() {
        close();
        sessionOpen = false;
        launcherOpen = false;
        shotOpen = false;
        overviewOpen = false;
    }
    // A click outside a panel closes it; ignore that same click reopening it from the bar.
    property double closedAt: 0
    function dismiss() {
        closedAt = Date.now();
        close();
    }
    // Open panel `name`, or close it if it is open. The control center always opens on its main page.
    function toggle(name) {
        const reopen = openPanel !== name && Date.now() - closedAt > 250;
        if (reopen && name === "control")
            controlPage = "main";
        openPanel = reopen ? name : "";
    }
    function openControl(page) {
        controlPage = page;
        openPanel = "control";
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
    function toggleOverview() {
        const reopen = !overviewOpen;
        closeOverlays();
        overviewOpen = reopen;
    }
    function openShot() {
        closeOverlays();
        shotOpen = true;
    }

    function showOsd(kind, value, muted, text) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(100, value));
        osdMuted = muted;
        osdText = text ?? "";
        osdVisible = true;
        osdTimer.restart();
    }
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    // The chosen wallpaper, as penumbra-wallpaper records it: one of Penumbra's (wallpaper,
    // wallpaper-dawn…), or the path of your own image, GIF or video.
    property string wallpaper: "wallpaper"
    readonly property string wallpapers: Quickshell.env("HOME") + "/.local/share/penumbra/"
    readonly property string wallpaperFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property var wallpaperTitles: ({ "wallpaper": "Night", "wallpaper-dawn": "Dawn", "wallpaper-eclipse": "Eclipse" })
    function wallpaperTitle(name) {
        return wallpaperTitles[name] ?? name.replace(/^.*\//, "").replace(/\.[^.]*$/, "");
    }
    // scene (dawn, eclipse), still (night or an image), gif or video.
    function wallpaperKind(name) {
        if (name === "wallpaper-dawn" || name === "wallpaper-eclipse")
            return "scene";
        const ext = name.startsWith("/") ? name.replace(/^.*\./, "").toLowerCase() : "";
        if (ext === "gif")
            return "gif";
        return ["mp4", "webm", "mkv", "mov", "m4v"].includes(ext) ? "video" : "still";
    }
    // The first frame penumbra-wallpaper saves of a GIF, video or non-PNG image.
    function wallpaperPoster(path) {
        return Quickshell.env("HOME") + "/.cache/penumbra/wallpapers/" + Qt.md5(path) + ".png";
    }
    // The still the lock screen shows: the wordmark-free scene, or your image or its first frame.
    readonly property string wallpaperStill: !wallpaper.startsWith("/") ? wallpapers + wallpaper + "-clean.png"
        : wallpaperKind(wallpaper) === "still" && wallpaper.toLowerCase().endsWith(".png") ? wallpaper : wallpaperPoster(wallpaper)
    // A file:// URL for a path that may hold spaces, # or ?.
    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/penumbra/wallpaper"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().trim() || "wallpaper"
    }

    // Optional tools, found once at startup.
    property bool hasNightLight: false
    property bool hasVisualizer: false
    property bool hasTyping: false // wtype types emoji and symbols into the focused window
    property bool hasPowerProfiles: false // power-profiles-daemon (or another daemon with its D-Bus API)
    Process {
        running: true
        command: ["bash", "-c", "command -v hyprsunset; command -v cava; command -v wtype; busctl --system list --no-pager 2>/dev/null | grep -qE \"^(org.freedesktop.UPower.PowerProfiles|net.hadess.PowerProfiles) \" && echo /power-profiles"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNightLight = text.includes("/hyprsunset");
                root.hasVisualizer = text.includes("/cava");
                root.hasTyping = text.includes("/wtype");
                root.hasPowerProfiles = text.includes("/power-profiles");
            }
        }
    }

    // Start a program in its own systemd scope (under app.slice), so it outlives the shell: the
    // shell runs as penumbra-shell.service, and restarting it must not take the apps along.
    // `command` is an argument list, or { command, workingDirectory }.
    function spawn(command) {
        // Without the shell's allocator tuning (penumbra-shell.service).
        const scope = ["systemd-run", "--user", "--scope", "--slice=app.slice", "--collect", "--quiet", "--", "env", "-u", "MALLOC_CONF"];
        if (Array.isArray(command))
            Quickshell.execDetached(scope.concat(command));
        else
            Quickshell.execDetached({ command: scope.concat(command.command), workingDirectory: command.workingDirectory });
    }
    function run(command) {
        spawn(["bash", "-c", command]);
    }
    // The argument list for running `command` (a list) in the terminal from Settings → Default
    // apps; `options` are penumbra-terminal's, such as ["--class", "penumbra-monitor", "--hold"].
    function terminal(command, options) {
        return [bin + "penumbra-terminal", ...(options ?? []), "--", ...command];
    }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
}
