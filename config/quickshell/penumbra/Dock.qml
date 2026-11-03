import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// One dock per output. A four-pixel edge reveals it; only its visible bounds take input.
PanelWindow {
    id: root
    required property var modelData
    property bool locked: false
    screen: modelData
    anchors { bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "penumbra-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var workspace: monitor?.activeWorkspace ?? null
    visible: Settings.dockMode !== "off" && !locked && !(workspace?.hasFullscreen ?? false)
        && !Ui.overviewOpen && !Ui.launcherOpen && !Ui.sessionOpen && !Ui.shotOpen
    property bool held: false
    readonly property bool shown: held || (Settings.dockMode === "empty" && (workspace?.toplevels.values.length ?? 0) === 0)
    readonly property var windows: Hyprland.workspaces.values
        .filter(w => w.monitor?.name === monitor?.name)
        .reduce((all, w) => all.concat(w.toplevels.values), []).filter(w => !w.lastIpcObject?.hidden)
    readonly property var apps: {
        const groups = [];
        for (const id of Settings.dockPins) {
            const entry = DesktopEntries.heuristicLookup(id);
            if (entry && !groups.some(g => g.key === entry.id))
                groups.push({ key: entry.id, entry, windows: [], pin: id });
        }
        for (const win of windows) {
            const id = win.wayland?.appId || win.lastIpcObject?.class || "";
            const entry = id ? DesktopEntries.heuristicLookup(id) : null;
            const key = entry?.id || id || win.address;
            let group = groups.find(g => g.key === key);
            if (!group) {
                group = { key, entry, windows: [], pin: "" };
                groups.push(group);
            }
            group.windows.push(win);
        }
        return groups;
    }
    readonly property bool previewing: surface.previewing
    implicitWidth: Math.min(screen?.width ?? 800, Math.max(300, apps.length * 56 + 76))
    implicitHeight: 246
    mask: Region { item: inputBounds }
    Item {
        id: inputBounds
        z: 10
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
        width: root.previewing ? root.width : surface.trayWidth
        height: root.previewing ? 246 : root.shown ? 78 : 4
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hide.stop(); root.held = true; }
                else hide.restart();
            }
        }
    }
    Timer { id: hide; interval: 450; onTriggered: { root.held = false; surface.hoveredKey = ""; } }
    onVisibleChanged: if (!visible) { held = false; surface.hoveredKey = ""; }
    DockSurface {
        id: surface
        anchors.fill: parent
        apps: root.apps
        shown: root.shown
        onTogglePin: app => Settings.dockPins = app.pin ? Settings.dockPins.filter(id => id !== app.pin) : Settings.dockPins.concat([app.entry.id])
        onLaunchApp: entry => root.launch(entry)
        onActivateWindow: window => root.focusWindow(window)
        onOpenLauncher: Ui.toggleLauncher("apps")
    }
    function focusWindow(win) {
        const address = win.lastIpcObject?.address ?? "0x" + win.address;
        if (/^0x[0-9a-f]+$/i.test(address)) Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
    }
    function launch(entry) {
        if (!entry) return;
        const command = entry.command.filter(arg => !/^%[a-zA-Z]$/.test(arg));
        Ui.spawn({ command: entry.runInTerminal ? Ui.terminal(command) : command, workingDirectory: entry.workingDirectory || Quickshell.env("HOME") });
    }
}
