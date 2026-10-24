import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Every workspace on the focused monitor, with live windows in place. Click a window to focus it,
// a workspace to go there, drag a window onto another workspace to move it; middle-click closes.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.overviewOpen || backdrop.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-overview"
    WlrLayershell.keyboardFocus: Ui.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var monitor: Hyprland.monitorFor(screen)
    // Layout size of the monitor, which window positions are measured in.
    readonly property real monitorWidth: monitor ? monitor.width / monitor.scale : width
    readonly property real monitorHeight: monitor ? monitor.height / monitor.scale : height
    // This monitor's workspaces, plus an empty one to start or drop into.
    readonly property var workspaces: {
        const own = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor?.name === monitor?.name).map(w => w.id);
        const next = Math.max(0, ...Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id)) + 1;
        return [...own, next].sort((a, b) => a - b);
    }
    readonly property int columns: Math.min(workspaces.length, workspaces.length > 6 ? 4 : 3)
    readonly property real cardWidth: Math.min(420, (width - 160 - (columns - 1) * 22) / columns)
    readonly property real cardHeight: cardWidth * monitorHeight / monitorWidth
    property int selected: 0

    Connections {
        target: Ui
        function onOverviewOpenChanged() {
            if (!Ui.overviewOpen)
                return;
            // Window positions are only as fresh as the last refresh.
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            root.selected = Math.max(0, root.workspaces.indexOf(root.monitor?.activeWorkspace?.id ?? 1));
        }
    }

    function workspace(id) {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }
    function go(id) {
        Ui.overviewOpen = false;
        const existing = workspace(id);
        if (existing)
            existing.activate();
        else
            Hyprland.dispatch(`hl.dsp.focus({workspace=${id}})`);
    }
    function focusWindow(toplevel) {
        Ui.overviewOpen = false;
        toplevel.wayland?.activate();
    }
    function move(toplevel, id) {
        if (toplevel.workspace?.id !== id)
            Hyprland.dispatch(`hl.dsp.window.move({workspace=${id}, window="address:${toplevel.lastIpcObject.address}", follow=false})`);
        refresh.restart();
    }
    Timer {
        id: refresh
        interval: 120
        onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); }
    }
    GlobalShortcut {
        appid: "nocturne"
        name: "overview"
        description: "Toggle the workspace overview"
        onPressed: Ui.toggleOverview()
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(7 / 255, 7 / 255, 11 / 255, 0.62)
        opacity: Ui.overviewOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        focus: Ui.overviewOpen
        Keys.onPressed: event => {
            const n = root.workspaces.length;
            if (event.key === Qt.Key_Escape)
                Ui.overviewOpen = false;
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                root.selected = (root.selected + 1) % n;
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                root.selected = (root.selected + n - 1) % n;
            else if (event.key === Qt.Key_Down)
                root.selected = Math.min(n - 1, root.selected + root.columns);
            else if (event.key === Qt.Key_Up)
                root.selected = Math.max(0, root.selected - root.columns);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.go(root.workspaces[root.selected]);
            // Number-row keys by position (keycodes 10–18), so AZERTY works too.
            else if (event.nativeScanCode >= 10 && event.nativeScanCode <= 18)
                root.go(event.nativeScanCode - 9);
            else
                return;
            event.accepted = true;
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.overviewOpen = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 22
            scale: Ui.overviewOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "W O R K S P A C E S"
                font.pixelSize: 12
                color: Theme.violet
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                rowSpacing: 22
                columnSpacing: 22

                Repeater {
                    model: Ui.overviewOpen || backdrop.opacity > 0 ? root.workspaces : []
                    delegate: ColumnLayout {
                        id: wsItem
                        required property int modelData
                        required property int index
                        readonly property var ws: root.workspace(modelData)
                        readonly property bool current: root.monitor?.activeWorkspace?.id === modelData
                        readonly property bool chosen: root.selected === index
                        spacing: 8

                        Rectangle {
                            id: card
                            implicitWidth: root.cardWidth
                            implicitHeight: root.cardHeight
                            radius: Theme.radius
                            color: drop.containsDrag ? Theme.hover : Theme.glassStrong
                            border.width: wsItem.chosen || drop.containsDrag ? 2 : 1
                            border.color: wsItem.chosen || drop.containsDrag ? Theme.violet : wsItem.current ? Theme.lineStrong : Theme.line
                            Behavior on color { ColorAnimation { duration: Theme.fast } }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selected = wsItem.index
                                onClicked: root.go(wsItem.modelData)
                            }
                            DropArea {
                                id: drop
                                anchors.fill: parent
                                keys: ["nocturne-window"]
                                onDropped: d => root.move(d.source.toplevel, wsItem.modelData)
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                anchors.margins: 1
                                radius: card.radius - 1
                                color: "transparent"
                                Image {
                                    anchors.fill: parent
                                    source: "file://" + Ui.wallpapers + Ui.wallpaper + ".png"
                                    sourceSize.width: root.cardWidth * 2
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    opacity: wsItem.chosen ? 0.75 : 0.45
                                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                                }
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: !wsItem.ws || wsItem.ws.toplevels.values.length === 0
                                text: wsItem.ws ? "󰖯" : "󰐕"
                                size: 26
                                color: Theme.dim
                            }

                            // Windows at their real size and place, tiled first and floating on top.
                            Item {
                                anchors.fill: parent
                                anchors.margins: 1
                                clip: true
                                Repeater {
                                    model: (wsItem.ws?.toplevels.values ?? []).slice()
                                        .sort((a, b) => (a.lastIpcObject.floating ?? false) - (b.lastIpcObject.floating ?? false))
                                    delegate: Item {
                                        id: slot
                                        required property var modelData
                                        readonly property var toplevel: modelData
                                        readonly property var info: modelData.lastIpcObject
                                        readonly property real k: card.width / root.monitorWidth
                                        x: ((info.at?.[0] ?? 0) - (root.monitor?.x ?? 0)) * k
                                        y: ((info.at?.[1] ?? 0) - (root.monitor?.y ?? 0)) * k
                                        width: Math.max(24, (info.size?.[0] ?? 0) * k)
                                        height: Math.max(18, (info.size?.[1] ?? 0) * k)
                                        visible: !!info.size

                                        ClippingRectangle {
                                            id: tile
                                            width: slot.width
                                            height: slot.height
                                            anchors.centerIn: slot
                                            radius: 8
                                            color: Theme.raised
                                            border.width: hover.containsMouse ? 2 : 1
                                            border.color: hover.containsMouse ? Theme.violetBright : Theme.line
                                            Drag.active: hover.drag.active
                                            Drag.keys: ["nocturne-window"]
                                            Drag.source: slot
                                            Drag.hotSpot: Qt.point(width / 2, height / 2)
                                            states: State {
                                                when: hover.drag.active
                                                ParentChange { target: tile; parent: backdrop }
                                                AnchorChanges { target: tile; anchors.horizontalCenter: undefined; anchors.verticalCenter: undefined }
                                                PropertyChanges { target: tile; opacity: 0.85; z: 10 }
                                            }

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: Ui.overviewOpen ? slot.toplevel.wayland : null
                                                live: true
                                                constraintSize: Qt.size(slot.width * 2, slot.height * 2)
                                            }
                                            IconImage {
                                                readonly property var entry: DesktopEntries.heuristicLookup(slot.toplevel.wayland?.appId ?? "")
                                                anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                                                implicitSize: Math.min(28, slot.height / 3)
                                                source: Quickshell.iconPath(entry?.icon ?? slot.toplevel.wayland?.appId ?? "", "application-x-executable")
                                            }
                                        }
                                        MouseArea {
                                            id: hover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            drag.target: tile
                                            onEntered: root.selected = wsItem.index
                                            onClicked: m => {
                                                if (m.button === Qt.MiddleButton) {
                                                    slot.toplevel.wayland?.close();
                                                    refresh.restart();
                                                } else {
                                                    root.focusWindow(slot.toplevel);
                                                }
                                            }
                                            onReleased: if (drag.active) tile.Drag.drop()
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 6
                            Rectangle {
                                visible: wsItem.current
                                implicitWidth: 6
                                implicitHeight: 6
                                radius: 3
                                color: Theme.violet
                            }
                            Label {
                                text: wsItem.ws ? `Workspace ${wsItem.ws.name}` : "New workspace"
                                font.pixelSize: 12
                                font.weight: wsItem.current ? Font.DemiBold : Font.Normal
                                color: wsItem.chosen ? Theme.text : Theme.muted
                            }
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Click to focus · drag a window to move it · middle-click to close · Esc"
                font.pixelSize: 11
                color: Theme.muted
            }
        }
    }
}
