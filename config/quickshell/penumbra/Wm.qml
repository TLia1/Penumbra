pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// MangoWM monitors, tags, layouts, keymodes and client states from mmsg.
Singleton {
    id: root

    readonly property bool isMango: Quickshell.env("MANGO_INSTANCE_SIGNATURE") !== ""

    property var rawMonitors: []
    property var rawClients: []
    property string keyboardLayout: ""
    property string keymode: "default"

    readonly property var layoutCatalog: [
        { id: "dwindle", symbol: "DW", glyph: "󰕰", title: "Dwindle", subtitle: "Each new window splits the focused window", vertical: false },
        { id: "tile", symbol: "T", glyph: "󰙀", title: "Master & stack", subtitle: "Main window on the left, stack on the right", vertical: false },
        { id: "scroller", symbol: "S", glyph: "󰔰", title: "Scroller", subtitle: "Horizontal scrolling strip of columns", vertical: false },
        { id: "center_tile", symbol: "CT", glyph: "󰆤", title: "Centered master", subtitle: "Main window centered with stacks on both sides", vertical: false },
        { id: "right_tile", symbol: "RT", glyph: "󰙀", title: "Right master", subtitle: "Main window on the right, stack on the left", vertical: false },
        { id: "grid", symbol: "G", glyph: "󰕳", title: "Grid", subtitle: "Windows arranged in an equal grid", vertical: false },
        { id: "deck", symbol: "K", glyph: "󰘸", title: "Deck", subtitle: "Main window on the left, tabbed deck on the right", vertical: false },
        { id: "monocle", symbol: "M", glyph: "󰊓", title: "Monocle", subtitle: "Every window fills the tag with a native tab bar", vertical: false },
        { id: "fair", symbol: "F", glyph: "󰕲", title: "Fair", subtitle: "Balanced rows and columns of equal area", vertical: false },
        { id: "vertical_scroller", symbol: "VS", glyph: "󰔱", title: "Vertical scroller", subtitle: "Vertical scrolling strip of windows", vertical: true },
        { id: "vertical_tile", symbol: "VT", glyph: "󰘼", title: "Vertical master", subtitle: "Main window at the top, stack below", vertical: true },
        { id: "vertical_grid", symbol: "VG", glyph: "󰕴", title: "Vertical grid", subtitle: "Column-first grid arrangement", vertical: true },
        { id: "vertical_deck", symbol: "VK", glyph: "󰘸", title: "Vertical deck", subtitle: "Main window at the top, tabbed deck below", vertical: true },
        { id: "vertical_fair", symbol: "VF", glyph: "󰕲", title: "Vertical fair", subtitle: "Balanced vertical columns", vertical: true }
    ]

    function layoutBySymbol(symbol) {
        const s = (symbol ?? "").trim();
        return layoutCatalog.find(l => l.symbol === s) ?? layoutCatalog[0];
    }

    function layoutById(id) {
        const k = (id ?? "").trim();
        return layoutCatalog.find(l => l.id === k) ?? layoutCatalog[0];
    }

    function parseMonitorsLine(line) {
        const trimmed = (line ?? "").trim();
        if (!trimmed)
            return;
        try {
            const parsed = JSON.parse(trimmed);
            if (Array.isArray(parsed.monitors)) {
                root.rawMonitors = parsed.monitors;
                const activeMon = parsed.monitors.find(m => m.active) ?? parsed.monitors[0];
                if (activeMon) {
                    if (activeMon.keyboardlayout !== undefined)
                        root.keyboardLayout = activeMon.keyboardlayout || "";
                    if (activeMon.keymode !== undefined)
                        root.keymode = activeMon.keymode || "default";
                }
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

    function parseKeymodeLine(line) {
        const trimmed = (line ?? "").trim();
        if (!trimmed)
            return;
        try {
            const parsed = JSON.parse(trimmed);
            if (typeof parsed.keymode === "string")
                root.keymode = parsed.keymode || "default";
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

    Process {
        id: watchKeymode
        running: root.isMango
        command: ["mmsg", "watch", "keymode"]
        stdout: SplitParser {
            onRead: data => root.parseKeymodeLine(data)
        }
        onExited: if (root.isMango) reconnectTimer.restart()
    }

    Timer {
        id: reconnectTimer
        interval: 1000
        onTriggered: {
            if (!root.isMango)
                return;
            if (!watchMonitors.running)
                watchMonitors.running = true;
            if (!watchClients.running)
                watchClients.running = true;
            if (!watchKeymode.running)
                watchKeymode.running = true;
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

    // Build unified monitor, tag and client objects when running under MangoWM.
    readonly property var mangoState: {
        if (!isMango)
            return { monitors: [], workspaces: [], clients: [] };
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
            const isScratchpad = !!c.is_scratchpad || !!c.is_namedscratchpad;
            const isMinimized = !!c.is_minimized;
            const hidden = isMinimized || (!c.is_visible && isScratchpad);
            return {
                id: c.id,
                pid: c.pid ?? 0,
                address: String(c.id),
                title: c.title ?? "",
                appId: c.appid ?? "",
                activated: !!c.is_focused,
                visible: !!c.is_visible,
                monitorName: c.monitor ?? "",
                tags,
                workspace: { id: tags[0] },
                wayland: wl,
                isFloating: !!c.is_floating,
                isFullscreen: !!c.is_fullscreen,
                isFakeFullscreen: !!c.is_fakefullscreen,
                isMaximized: !!c.is_maximized,
                isGlobal: !!c.is_global,
                isOverlay: !!c.is_overlay,
                isGroup: !!c.is_group,
                isGroupFocus: !!c.is_group_focus,
                isScratchpad,
                isMinimized,
                isSwallowing: !!c.is_swallowing,
                isSwallowedBy: !!c.is_swallowedby,
                isXwayland: !!c.is_xwayland,
                isUrgent: !!c.is_urgent,
                scrollerProportion: Number(c.scroller_proportion ?? 0.8),
                lastIpcObject: {
                    address: String(c.id),
                    class: c.appid ?? "",
                    title: c.title ?? "",
                    at: [c.x ?? 0, c.y ?? 0],
                    size: [c.width ?? 0, c.height ?? 0],
                    floating: !!c.is_floating,
                    fullscreen: !!c.is_fullscreen,
                    maximized: !!c.is_maximized,
                    global: !!c.is_global,
                    overlay: !!c.is_overlay,
                    group: !!c.is_group,
                    scratchpad: isScratchpad,
                    minimized: isMinimized,
                    hidden,
                    focusHistoryID: c.is_focused ? 0 : idx + 1
                }
            };
        });

        const monitors = [];
        const workspaces = [];
        for (const m of rawMonitors) {
            const scale = m.scale > 0 ? m.scale : 1;
            const layoutSymbol = m.layout_symbol || "DW";
            const layoutInfo = root.layoutBySymbol(layoutSymbol);
            const activeTags = Array.isArray(m.active_tags) && m.active_tags.length > 0 ? m.active_tags : [1];
            const monObj = {
                name: m.name ?? "",
                active: !!m.active,
                isHdr: !!m.is_hdr,
                isVrr: !!m.is_vrr,
                x: m.x ?? 0,
                y: m.y ?? 0,
                width: Math.round((m.width ?? 1920) * scale),
                height: Math.round((m.height ?? 1080) * scale),
                scale,
                layoutSymbol,
                layoutIndex: m.layout_index ?? 0,
                layoutInfo,
                activeTags,
                keymode: m.keymode || "default",
                lastIpcObject: { transform: 0 },
                activeWorkspace: null
            };
            const primaryActiveTag = activeTags[0] ?? 1;
            const tags = Array.isArray(m.tags) && m.tags.length > 0 ? m.tags : [1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => ({
                index: i,
                is_active: activeTags.includes(i),
                is_urgent: false,
                layout: layoutSymbol,
                client_count: 0
            }));
            for (const t of tags) {
                const tagId = t.index;
                const tagClients = mappedClients.filter(c => c.monitorName === monObj.name && (c.isGlobal || c.tags.includes(tagId)) && !c.lastIpcObject.hidden);
                const isActive = !!t.is_active;
                const tagLayoutSymbol = t.layout || layoutSymbol;
                const tagLayoutInfo = root.layoutBySymbol(tagLayoutSymbol);
                const ws = {
                    id: tagId,
                    name: String(tagId),
                    active: isActive,
                    focused: monObj.active && isActive,
                    primary: tagId === primaryActiveTag,
                    urgent: !!t.is_urgent,
                    layoutSymbol: tagLayoutSymbol,
                    layoutInfo: tagLayoutInfo,
                    clientCount: t.client_count ?? tagClients.length,
                    monitor: monObj,
                    hasFullscreen: tagClients.some(c => c.lastIpcObject.fullscreen && !c.lastIpcObject.hidden),
                    toplevels: { values: tagClients },
                    activate: () => root.focusWorkspace(tagId, monObj.name),
                    toggleView: () => root.toggleTagView(tagId, monObj.name),
                    tagFocusedWindow: () => root.tagFocusedWindow(tagId),
                    toggleTagFocusedWindow: () => root.toggleTagFocusedWindow(tagId)
                };
                workspaces.push(ws);
                if (isActive && !monObj.activeWorkspace)
                    monObj.activeWorkspace = ws;
            }
            if (!monObj.activeWorkspace && workspaces.length > 0)
                monObj.activeWorkspace = workspaces.find(w => w.monitor === monObj) ?? null;
            monitors.push(monObj);
        }
        return { monitors, workspaces, clients: mappedClients };
    }

    readonly property var monitors: mangoState.monitors
    readonly property var workspaces: mangoState.workspaces
    readonly property var clients: mangoState.clients
    readonly property var focusedMonitor: monitors.find(m => m.active) ?? monitors[0] ?? null
    readonly property var focusedClient: clients.find(c => c.activated) ?? null
    readonly property var stashedClients: clients.filter(c => c.isScratchpad || c.isMinimized)
    readonly property int scratchpadCount: stashedClients.length
    readonly property string activeLayoutSymbol: focusedMonitor?.layoutSymbol ?? "DW"
    readonly property var activeLayout: focusedMonitor?.layoutInfo ?? layoutById(Settings.tilingLayout)

    function monitorFor(screen) {
        if (!screen)
            return null;
        return monitors.find(m => m.name === screen.name) ?? null;
    }

    // Mango reports visible clients and their rectangles in global logical coordinates.
    function screenCovered(monitor, width, height) {
        if (!monitor) return false;
        return clients.some(client => {
            if (!client.visible || client.isMinimized) return false;
            if (client.monitorName === monitor.name &&
                    ((client.isFullscreen && !client.isFakeFullscreen) || client.isMaximized))
                return true;
            const { at, size } = client.lastIpcObject;
            return at[0] <= monitor.x && at[1] <= monitor.y
                && at[0] + size[0] >= monitor.x + width
                && at[1] + size[1] >= monitor.y + height;
        });
    }

    function workspacesFor(screenName) {
        const showAll = Settings.showAllTags;
        return workspaces
            .filter(w => w.id > 0 && w.monitor?.name === screenName && (showAll || w.toplevels.values.length > 0 || w.focused || w.active || w.urgent))
            .sort((a, b) => a.id - b.id);
    }

    function allTagsFor(screenName) {
        return workspaces
            .filter(w => w.id > 0 && w.monitor?.name === screenName)
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
        if (isMango && !pollMonitors.running)
            pollMonitors.running = true;
        refreshToplevels();
    }

    function refreshToplevels() {
        if (isMango && !pollClients.running)
            pollClients.running = true;
    }

    function dispatch(action, targetClient) {
        if (!isMango)
            return;
        const args = ["mmsg", "dispatch", action];
        if (targetClient !== undefined && targetClient !== null)
            args.push(`client,${targetClient}`);
        Quickshell.execDetached(args);
    }

    function focusWindow(toplevel) {
        if (!toplevel)
            return;
        const id = toplevel.id;
        if (id !== undefined) {
            if (toplevel.isMinimized)
                dispatch("restore_minimized", id);
            else if (toplevel.isScratchpad && !toplevel.visible)
                dispatch("toggle_scratchpad");
            dispatch("focusid", id);
        }
    }

    function focusWorkspace(id, monitorName) {
        if (monitorName && focusedMonitor && monitorName !== focusedMonitor.name)
            dispatch(`viewcrossmon,${id},${monitorName}`);
        else
            dispatch(`view,${id},0`);
    }

    function toggleTagView(id, monitorName) {
        if (monitorName && focusedMonitor && monitorName !== focusedMonitor.name)
            dispatch(`focusmon,${monitorName}`);
        dispatch(`toggleview,${id},0`);
    }

    function comboTagView(id) {
        dispatch(`comboview,${id},0`);
    }

    function moveWindowToWorkspace(toplevel, id) {
        if (!toplevel || toplevel.id === undefined)
            return;
        dispatch(`tagsilent,${id}`, toplevel.id);
    }

    function tagFocusedWindow(id) {
        dispatch(`tag,${id},0`);
    }

    function toggleTagFocusedWindow(id) {
        dispatch(`toggletag,${id},0`);
    }

    function toggleWindowTag(toplevel, id) {
        if (!toplevel || toplevel.id === undefined)
            return;
        dispatch(`toggletag,${id},0`, toplevel.id);
    }

    function setLayout(layoutId) {
        if (!layoutId)
            return;
        dispatch(`setlayout,${layoutId}`);
    }

    function nextLayout() {
        dispatch("switch_layout");
    }

    function toggleOverview() {
        dispatch("toggleoverview");
    }

    function toggleJump() {
        dispatch("togglejump");
    }

    function toggleScratchpad() {
        dispatch("toggle_scratchpad");
    }

    function stashWindow(toplevel) {
        dispatch("minimized", toplevel?.id);
    }

    function restoreMinimized() {
        dispatch("restore_minimized");
    }

    function switchProportionPreset() {
        dispatch("switch_proportion_preset");
    }

    function setProportion(ratio) {
        dispatch(`set_proportion,${ratio}`);
    }

    function scrollerStack(direction) {
        dispatch(`scroller_stack,${direction || "left"}`);
    }

    function toggleGroup() {
        dispatch("groupjoin,right");
    }

    function leaveGroup() {
        dispatch("groupleave");
    }

    function toggleGroupBar() {
        dispatch("togglegroupbar");
    }

    function focusGroup(direction) {
        dispatch(`groupfocus,${direction || "next"}`);
    }

    function toggleGlobal(toplevel) {
        dispatch("toggleglobal", toplevel?.id);
    }

    function toggleOverlay(toplevel) {
        dispatch("toggleoverlay", toplevel?.id);
    }

    function toggleMaximizeScreen(toplevel) {
        dispatch("togglemaximizescreen", toplevel?.id);
    }

    function toggleFloating(toplevel) {
        dispatch("togglefloating", toplevel?.id);
    }

    function zoomMaster(toplevel) {
        dispatch("zoom", toplevel?.id);
    }

    function setKeymode(mode) {
        dispatch(`setkeymode,${mode || "default"}`);
    }

    function setReducedMotion(reduced) {
        if (isMango)
            dispatch(`setoption,animations,${reduced ? 0 : 1}`);
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
                root.dispatch(`setlayout,${layout}`);
            }
        }
    }

    function syncTiling() {
        if (tilingInitialized)
            tilingTimer.restart();
    }

    function nextKeyboardLayout() {
        if (isMango)
            dispatch("switch_keyboard_layout");
    }
}
