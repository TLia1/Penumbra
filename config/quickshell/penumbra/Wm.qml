pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Compositor bridge for Hyprland and MangoWM: monitors, workspaces/tags, windows and dispatches.
Singleton {
    id: root

    readonly property bool isMango: Quickshell.env("MANGO_INSTANCE_SIGNATURE") !== ""
    readonly property bool isHyprland: !isMango && Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property string name: isMango ? "mango" : "hyprland"

    property var rawMonitors: []
    property var rawClients: []
    property string keyboardLayout: ""

    function parseMonitorsLine(line) {
        const trimmed = (line ?? "").trim();
        if (!trimmed)
            return;
        try {
            const parsed = JSON.parse(trimmed);
            if (Array.isArray(parsed.monitors)) {
                root.rawMonitors = parsed.monitors;
                const activeMon = parsed.monitors.find(m => m.active) ?? parsed.monitors[0];
                if (activeMon && activeMon.keyboardlayout !== undefined)
                    root.keyboardLayout = activeMon.keyboardlayout || "";
            }
        } catch (e) {}
    }

    function parseClientsLine(line) {
        const trimmed = (line ?? "").trim();
        if (!trimmed)
            return;
        try {
            const parsed = JSON.parse(trimmed);
            if (Array.isArray(parsed.clients))
                root.rawClients = parsed.clients;
        } catch (e) {}
    }

    Process {
        id: watchMonitors
        running: root.isMango
        command: ["mmsg", "watch", "all-monitors"]
        stdout: SplitParser {
            onRead: data => root.parseMonitorsLine(data)
        }
        onExited: if (root.isMango) reconnectTimer.restart()
    }

    Process {
        id: watchClients
        running: root.isMango
        command: ["mmsg", "watch", "all-clients"]
        stdout: SplitParser {
            onRead: data => root.parseClientsLine(data)
        }
        onExited: if (root.isMango) reconnectTimer.restart()
    }

    Timer {
        id: reconnectTimer
        interval: 1000
        onTriggered: {
            if (! root.isMango)
                return;
            if (!watchMonitors.running)
                watchMonitors.running = true;
            if (!watchClients.running)
                watchClients.running = true;
        }
    }

    Process {
        id: pollMonitors
        command: ["mmsg", "get", "all-monitors"]
        stdout: SplitParser {
            onRead: data => root.parseMonitorsLine(data)
        }
    }

    Process {
        id: pollClients
        command: ["mmsg", "get", "all-clients"]
        stdout: SplitParser {
            onRead: data => root.parseClientsLine(data)
        }
    }

    // Build unified monitor and workspace objects when running under MangoWM.
    readonly property var mangoState: {
        if (!isMango)
            return { monitors: [], workspaces: [] };
        const waylandToplevels = ToplevelManager.toplevels?.values ?? [];
        const usedWayland = new Set();
        const matchWayland = c => {
            const appId = (c.appid ?? "").toLowerCase();
            const title = c.title ?? "";
            let hit = waylandToplevels.find(w => !usedWayland.has(w) && (w.appId ?? "").toLowerCase() === appId && w.title === title);
            if (!hit)
                hit = waylandToplevels.find(w => !usedWayland.has(w) && (w.appId ?? "").toLowerCase() === appId);
            if (hit)
                usedWayland.add(hit);
            return hit ?? { appId: c.appid ?? "", title: c.title ?? "", activated: !!c.is_focused };
        };

        const mappedClients = rawClients.map((c, idx) => {
            const wl = matchWayland(c);
            const tags = Array.isArray(c.tags) && c.tags.length > 0 ? c.tags : [1];
            const hidden = !!c.is_minimized || (!c.is_visible && !!c.is_scratchpad);
            return {
                id: c.id,
                address: String(c.id),
                title: c.title ?? "",
                activated: !!c.is_focused,
                monitorName: c.monitor ?? "",
                tags,
                workspace: { id: tags[0] },
                wayland: wl,
                lastIpcObject: {
                    address: String(c.id),
                    class: c.appid ?? "",
                    title: c.title ?? "",
                    at: [c.x ?? 0, c.y ?? 0],
                    size: [c.width ?? 0, c.height ?? 0],
                    floating: !!c.is_floating,
                    fullscreen: !!c.is_fullscreen,
                    hidden,
                    focusHistoryID: c.is_focused ? 0 : idx + 1
                }
            };
        });

        const monitors = [];
        const workspaces = [];
        for (const m of rawMonitors) {
            const scale = m.scale > 0 ? m.scale : 1;
            const monObj = {
                name: m.name ?? "",
                active: !!m.active,
                x: m.x ?? 0,
                y: m.y ?? 0,
                width: Math.round((m.width ?? 1920) * scale),
                height: Math.round((m.height ?? 1080) * scale),
                scale,
                lastIpcObject: { transform: 0 },
                activeWorkspace: null
            };
            const activeTag = Array.isArray(m.active_tags) && m.active_tags.length > 0 ? m.active_tags[0] : 1;
            const tags = Array.isArray(m.tags) && m.tags.length > 0 ? m.tags : [1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => ({
                index: i,
                is_active: i === activeTag,
                is_urgent: false
            }));
            for (const t of tags) {
                const tagId = t.index;
                const tagClients = mappedClients.filter(c => c.monitorName === monObj.name && c.tags.includes(tagId));
                const isActive = !!t.is_active;
                const ws = {
                    id: tagId,
                    name: String(tagId),
                    active: isActive,
                    focused: monObj.active && isActive,
                    urgent: !!t.is_urgent,
                    monitor: monObj,
                    hasFullscreen: tagClients.some(c => c.lastIpcObject.fullscreen && !c.lastIpcObject.hidden),
                    toplevels: { values: tagClients },
                    activate: () => root.focusWorkspace(tagId, monObj.name)
                };
                workspaces.push(ws);
                if (isActive && !monObj.activeWorkspace)
                    monObj.activeWorkspace = ws;
            }
            if (!monObj.activeWorkspace && workspaces.length > 0)
                monObj.activeWorkspace = workspaces.find(w => w.monitor === monObj) ?? null;
            monitors.push(monObj);
        }
        return { monitors, workspaces };
    }

    readonly property var monitors: isMango ? mangoState.monitors : (Hyprland.monitors?.values ?? [])
    readonly property var workspaces: isMango ? mangoState.workspaces : (Hyprland.workspaces?.values ?? [])
    readonly property var focusedMonitor: isMango
        ? (mangoState.monitors.find(m => m.active) ?? mangoState.monitors[0] ?? null)
        : Hyprland.focusedMonitor

    function monitorFor(screen) {
        if (!screen)
            return null;
        if (isMango)
            return mangoState.monitors.find(m => m.name === screen.name) ?? null;
        return Hyprland.monitorFor(screen);
    }

    function workspacesFor(screenName) {
        return workspaces
            .filter(w => w.id > 0 && w.monitor?.name === screenName && (w.toplevels.values.length > 0 || w.focused || w.active))
            .sort((a, b) => a.id - b.id);
    }

    function windowsForMonitor(monitorName) {
        const seen = new Set();
        const result = [];
        for (const w of workspaces) {
            if (w.monitor?.name !== monitorName)
                continue;
            for (const t of w.toplevels.values) {
                const key = t.address ?? t;
                if (!seen.has(key) && !t.lastIpcObject?.hidden) {
                    seen.add(key);
                    result.push(t);
                }
            }
        }
        return result;
    }

    function refresh() {
        if (isMango) {
            if (!pollMonitors.running)
                pollMonitors.running = true;
            if (!pollClients.running)
                pollClients.running = true;
        } else {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    function refreshToplevels() {
        if (isMango) {
            if (!pollClients.running)
                pollClients.running = true;
        } else {
            Hyprland.refreshToplevels();
        }
    }

    function focusWindow(toplevel) {
        if (!toplevel)
            return;
        if (isMango) {
            const id = toplevel.id ?? toplevel.lastIpcObject?.address;
            if (id !== undefined && id !== "")
                Quickshell.execDetached(["mmsg", "dispatch", "focusid", `client,${id}`]);
        } else {
            const address = toplevel.lastIpcObject?.address ?? "0x" + toplevel.address;
            if (/^0x[0-9a-f]+$/i.test(address))
                Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`);
        }
    }

    function focusWorkspace(id, monitorName) {
        if (isMango) {
            if (monitorName && focusedMonitor && monitorName !== focusedMonitor.name)
                Quickshell.execDetached(["mmsg", "dispatch", `viewcrossmon,${id},${monitorName}`]);
            else
                Quickshell.execDetached(["mmsg", "dispatch", `view,${id},0`]);
        } else {
            Hyprland.dispatch(`hl.dsp.focus({workspace = ${id}})`);
        }
    }

    function moveWindowToWorkspace(toplevel, id) {
        if (!toplevel)
            return;
        if (isMango) {
            const cid = toplevel.id ?? toplevel.lastIpcObject?.address;
            if (cid !== undefined && cid !== "")
                Quickshell.execDetached(["mmsg", "dispatch", `tagsilent,${id}`, `client,${cid}`]);
        } else {
            const address = toplevel.lastIpcObject?.address ?? "0x" + toplevel.address;
            Hyprland.dispatch(`hl.dsp.window.move({workspace = ${id}, follow = false, window = "address:${address}"})`);
        }
    }

    function setReducedMotion(reduced) {
        if (isMango) {
            const v = reduced ? 0 : 1;
            Quickshell.execDetached(["mmsg", "dispatch", `setoption,animations,${v}`]);
        } else {
            Quickshell.execDetached(["hyprctl", "eval", `hl.config({animations = {enabled = ${!reduced}}})`]);
        }
    }

    property bool tilingInitialized: false
    Component.onCompleted: Qt.callLater(() => { tilingInitialized = true; })

    Timer {
        id: tilingTimer
        interval: 60
        onTriggered: {
            const layout = Settings.tilingLayout || "dwindle";
            if (root.isMango) {
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/penumbra-settings", "apply", "--no-restart"]);
                Quickshell.execDetached(["mmsg", "dispatch", `setlayout,${layout}`]);
            } else if (root.isHyprland) {
                const hlLayout = layout === "tile" ? "master" : "dwindle";
                const smartSplit = Settings.dwindleSmartSplit ? "true" : "false";
                const mfact = Number(Settings.masterRatio || 0.55).toFixed(2);
                const newStatus = Settings.newWindowMaster ? "master" : "slave";
                const gapsIn = Settings.smartGaps ? 3 : 6;
                const gapsOut = Settings.smartGaps ? 6 : 14;
                Quickshell.execDetached(["hyprctl", "eval",
                    `hl.config({general = {layout = "${hlLayout}", gaps_in = ${gapsIn}, gaps_out = ${gapsOut}}, `
                    + `dwindle = {smart_split = ${smartSplit}}, master = {mfact = ${mfact}, new_status = "${newStatus}"}})`]);
            }
        }
    }

    function syncTiling() {
        if (tilingInitialized)
            tilingTimer.restart();
    }

    function nextKeyboardLayout() {
        if (isMango)
            Quickshell.execDetached(["mmsg", "dispatch", "switch_keyboard_layout"]);
        else
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
    }
}
