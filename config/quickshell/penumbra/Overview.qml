import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Every workspace at a glance, with live previews of its windows. Click a workspace to go there or
// a window to focus it, drag a window onto another workspace to move it, type to find a window by
// its title or app (Tab steps through the matches, Enter goes to one). Super and the key left of 1,
// or four fingers up on a touchpad, opens it.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.overviewOpen || backdrop.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-overview"
    WlrLayershell.keyboardFocus: Ui.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: Ui
        function onOverviewOpenChanged() {
            if (!Ui.overviewOpen)
                return;
            search.text = "";
            search.forceActiveFocus();
            root.picking = false;
            // Window positions come from Hyprland's last report; ask for a fresh one.
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
            root.selected = Math.max(0, root.matches.findIndex(t => t.activated));
        }
    }

    // Workspaces with windows or on screen, then the first free number, to drop a window into.
    readonly property var workspaces: {
        const list = Hyprland.workspaces.values.filter(w => w.id > 0 && (w.toplevels.values.length > 0 || w.active))
            .sort((a, b) => a.id - b.id).map(w => ({ id: w.id, workspace: w }));
        let free = 1;
        while (list.some(w => w.id === free))
            free++;
        return list.concat([{ id: free, workspace: null }]);
    }
    function entry(toplevel) {
        return DesktopEntries.heuristicLookup(toplevel.lastIpcObject?.class ?? "");
    }
    readonly property string query: search.text.trim().toLowerCase()
    function found(toplevel) {
        if (query === "")
            return true;
        const o = toplevel.lastIpcObject ?? {};
        return [toplevel.title, o.class, entry(toplevel)?.name].some(t => (t ?? "").toLowerCase().includes(query));
    }
    // The windows that match, in workspace order: Tab and Enter move through these.
    readonly property var matches: workspaces.filter(w => w.workspace)
        .reduce((all, w) => all.concat(w.workspace.toplevels.values.slice().sort((a, b) => (a.lastIpcObject?.at?.[0] ?? 0) - (b.lastIpcObject?.at?.[0] ?? 0))), [])
        .filter(t => found(t))
    property int selected: 0
    // Whether Tab or the arrows have been used: only then, or while searching, is the pick outlined.
    property bool picking: false
    readonly property var chosen: matches[Math.min(selected, matches.length - 1)] ?? null
    onQueryChanged: selected = 0
    function step(by) {
        picking = true;
        selected = (selected + by + matches.length) % Math.max(1, matches.length);
    }

    function address(toplevel) {
        return toplevel.lastIpcObject?.address ?? "0x" + toplevel.address;
    }
    function focusWindow(toplevel) {
        Ui.overviewOpen = false;
        Hyprland.dispatch(`hl.dsp.focus({window = "address:${address(toplevel)}"})`);
    }
    function goTo(id) {
        Ui.overviewOpen = false;
        Hyprland.dispatch(`hl.dsp.focus({workspace = ${id}})`);
    }
    function moveWindow(toplevel, id) {
        Hyprland.dispatch(`hl.dsp.window.move({workspace = ${id}, follow = false, window = "address:${address(toplevel)}"})`);
        refresh.restart();
    }
    Timer {
        id: refresh
        interval: 150
        onTriggered: { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); }
    }

    // A tile is this wide; its height follows its screen's shape.
    readonly property int columns: Math.max(1, Math.min(workspaces.length, width > 2400 ? 5 : 4))
    readonly property real tileWidth: Math.min(380, (width - 160 - (columns - 1) * 22) / columns)

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.62)
        opacity: Ui.overviewOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.overviewOpen = false
        }

        // Typing goes here; the field itself shows only once something is typed.
        TextInput {
            id: search
            width: 0
            height: 0
            opacity: 0
            function pick() {
                if (root.chosen && (root.picking || root.query !== ""))
                    root.focusWindow(root.chosen);
                else
                    Ui.overviewOpen = false;
            }
            Keys.onEscapePressed: {
                if (text !== "")
                    text = "";
                else
                    Ui.overviewOpen = false;
            }
            Keys.onReturnPressed: pick()
            Keys.onEnterPressed: pick()
            Keys.onTabPressed: root.step(1)
            Keys.onBacktabPressed: root.step(-1)
            Keys.onRightPressed: root.step(1)
            Keys.onLeftPressed: root.step(-1)
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 28
            scale: Ui.overviewOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            // The search, or the hint.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.max(260, searchRow.implicitWidth + 36)
                implicitHeight: 40
                radius: Theme.corner(20)
                color: Theme.glassStrong
                border.color: root.query !== "" ? Theme.accent : Theme.line
                RowLayout {
                    id: searchRow
                    anchors.centerIn: parent
                    spacing: 10
                    Glyph { text: "󰍉"; size: 15; color: root.query !== "" ? Theme.accentBright : Theme.dim }
                    Label {
                        text: search.text !== "" ? search.text : "Type to find a window"
                        font.pixelSize: Theme.textMedium
                        color: search.text !== "" ? Theme.text : Theme.dim
                    }
                    Label {
                        visible: root.query !== ""
                        text: root.matches.length === 1 ? "1 window" : `${root.matches.length} windows`
                        font.pixelSize: Theme.textSmall
                        color: root.matches.length ? Theme.muted : Theme.rose
                    }
                }
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                rowSpacing: 22
                columnSpacing: 22

                Repeater {
                    model: root.workspaces
                    delegate: ColumnLayout {
                        id: tile
                        required property var modelData
                        readonly property var workspace: modelData.workspace
                        readonly property var monitor: workspace?.monitor ?? Hyprland.focusedMonitor
                        readonly property bool turned: (monitor?.lastIpcObject?.transform ?? 0) % 2 === 1
                        // The screen's size in layout pixels, which window positions use too.
                        readonly property real screenWidth: (turned ? monitor?.height : monitor?.width) / (monitor?.scale || 1) || 1920
                        readonly property real screenHeight: (turned ? monitor?.width : monitor?.height) / (monitor?.scale || 1) || 1080
                        readonly property real fit: root.tileWidth / screenWidth
                        readonly property bool current: !!workspace && workspace.active && workspace.monitor?.name === root.screen?.name
                        Layout.alignment: Qt.AlignTop
                        spacing: 8

                        Rectangle {
                            id: frame
                            Layout.preferredWidth: root.tileWidth
                            Layout.preferredHeight: tile.screenHeight * tile.fit
                            radius: Theme.radius
                            clip: true
                            color: drop.containsDrag ? Theme.alpha(Theme.accent, 0.2) : Theme.alpha(Theme.base, 0.55)
                            border.width: tile.current || drop.containsDrag ? 2 : 1
                            border.color: tile.current || drop.containsDrag ? Theme.accent : Theme.line
                            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

                            // The wallpaper behind the windows.
                            Image {
                                anchors.fill: parent
                                source: Ui.fileUrl(Ui.wallpaperStill)
                                sourceSize.width: root.tileWidth * 2
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: 0.55
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.goTo(tile.modelData.id)
                            }
                            DropArea {
                                id: drop
                                anchors.fill: parent
                                onDropped: drag => {
                                    if (drag.source?.toplevel && drag.source.toplevel.workspace?.id !== tile.modelData.id)
                                        root.moveWindow(drag.source.toplevel, tile.modelData.id);
                                }
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: !tile.workspace
                                text: "󰐕"
                                size: 26
                                color: drop.containsDrag ? Theme.accentBright : Theme.dim
                            }

                            Repeater {
                                model: tile.workspace?.toplevels.values ?? []
                                delegate: Item {
                                    id: win
                                    required property var modelData
                                    readonly property var info: modelData.lastIpcObject ?? {}
                                    readonly property bool hit: root.found(modelData)
                                    readonly property bool isChosen: root.chosen === modelData && (root.query !== "" || root.picking)
                                    x: ((info.at?.[0] ?? 0) - (tile.monitor?.x ?? 0)) * tile.fit
                                    y: ((info.at?.[1] ?? 0) - (tile.monitor?.y ?? 0)) * tile.fit
                                    width: Math.max(12, (info.size?.[0] ?? 0) * tile.fit)
                                    height: Math.max(12, (info.size?.[1] ?? 0) * tile.fit)
                                    // Floating windows over tiled ones, the most recently used on top.
                                    z: (info.floating ? 100 : 0) + 50 - (info.focusHistoryID ?? 0)
                                    opacity: hit ? (pressArea.dragging ? 0.35 : 1) : 0.22
                                    visible: !info.hidden
                                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: Theme.corner(6)
                                        color: Theme.raised
                                        border.width: win.isChosen || pressArea.containsMouse ? 2 : 0
                                        border.color: Theme.accentBright
                                        ScreencopyView {
                                            anchors.fill: parent
                                            captureSource: root.visible ? win.modelData.wayland : null
                                            live: Ui.overviewOpen
                                            constraintSize: Qt.size(width, height)
                                        }
                                    }
                                    IconImage {
                                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Math.min(10, parent.height / 6) }
                                        implicitSize: Math.max(14, Math.min(32, Math.min(parent.width, parent.height) / 3))
                                        source: root.entry(win.modelData)?.icon ? Quickshell.iconPath(root.entry(win.modelData).icon, true) : ""
                                        asynchronous: true
                                    }
                                    MouseArea {
                                        id: pressArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        property point start
                                        property bool dragging: false
                                        onPressed: m => start = Qt.point(m.x, m.y)
                                        onPositionChanged: m => {
                                            if (!pressed)
                                                return;
                                            const p = mapToItem(backdrop, m.x, m.y);
                                            if (!dragging && Math.hypot(m.x - start.x, m.y - start.y) > 6) {
                                                dragging = true;
                                                ghost.toplevel = win.modelData;
                                                ghost.width = win.width;
                                                ghost.height = win.height;
                                                ghost.grab = start;
                                            }
                                            if (dragging) {
                                                ghost.x = p.x - ghost.grab.x;
                                                ghost.y = p.y - ghost.grab.y;
                                            }
                                        }
                                        onReleased: {
                                            if (dragging) {
                                                ghost.Drag.drop();
                                                ghost.toplevel = null;
                                                dragging = false;
                                            } else {
                                                root.focusWindow(win.modelData);
                                            }
                                        }
                                        onCanceled: { ghost.toplevel = null; dragging = false; }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.preferredWidth: root.tileWidth
                            spacing: 8
                            Label {
                                text: tile.workspace ? tile.workspace.name : "New workspace"
                                font.weight: tile.current ? Font.Bold : Font.DemiBold
                                color: tile.current ? Theme.accentBright : Theme.textSoft
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: !!tile.workspace
                                text: {
                                    const n = tile.workspace?.toplevels.values.length ?? 0;
                                    return n === 0 ? "Empty" : n === 1 ? "1 window" : `${n} windows`;
                                }
                                font.pixelSize: Theme.textSmall
                                color: Theme.muted
                            }
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Click to go there · drag a window to move it · Tab and Enter pick a match · Esc to close"
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }
        }

        // The window being dragged, following the pointer over the tiles.
        Item {
            id: ghost
            property var toplevel: null
            property point grab
            visible: !!toplevel
            z: 10
            Drag.active: !!toplevel
            Drag.hotSpot.x: grab.x
            Drag.hotSpot.y: grab.y
            Drag.source: ghost
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.corner(6)
                color: Theme.raised
                border.width: 2
                border.color: Theme.accent
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: ghost.toplevel?.wayland ?? null
                    live: true
                    constraintSize: Qt.size(width, height)
                }
            }
        }
    }
}
