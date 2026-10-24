import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Alt+Tab: live previews of every window, most recently used first. Tab moves on, releasing Alt
// switches; Escape or a click outside cancels.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.switcherOpen || card.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-switcher"
    WlrLayershell.keyboardFocus: Ui.switcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The order is frozen while the switcher is up, so focus changes don't shuffle it.
    property var windows: []
    property int selected: 0

    // Windows by last focus, most recent first, kept from Hyprland's focus changes; windows not
    // focused since the shell started follow in Hyprland's own order.
    property var history: []
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const active = Hyprland.activeToplevel;
            if (active)
                root.history = [active, ...root.history.filter(t => t !== active && t)];
        }
    }
    function recent() {
        const rank = t => {
            const i = history.indexOf(t);
            return i >= 0 ? i : 1000 + (t.lastIpcObject.focusHistoryID ?? 0);
        };
        return Hyprland.toplevels.values
            .filter(t => t.wayland && t.workspace && t.workspace.id > 0)
            .sort((a, b) => rank(a) - rank(b));
    }
    function step(delta) {
        if (!Ui.switcherOpen) {
            windows = recent();
            if (windows.length === 0)
                return;
            Ui.closeOverlays();
            Ui.switcherOpen = true;
            // Start on the previous window, so a quick Alt+Tab flips between two.
            selected = windows.length > 1 && delta > 0 ? 1 : 0;
            if (delta < 0)
                selected = windows.length - 1;
            return;
        }
        selected = (selected + delta + windows.length) % windows.length;
    }
    function commit() {
        if (!Ui.switcherOpen)
            return;
        const target = windows[selected];
        Ui.switcherOpen = false;
        target?.wayland?.activate();
    }
    // A window that closes while the switcher is up drops out of it.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (Ui.switcherOpen && event.name === "closewindow") {
                root.windows = root.windows.filter(w => w?.wayland);
                root.selected = Math.min(root.selected, root.windows.length - 1);
                if (root.windows.length === 0)
                    Ui.switcherOpen = false;
            }
        }
    }

    GlobalShortcut {
        appid: "nocturne"
        name: "switcher-next"
        description: "Window switcher: next window"
        onPressed: root.step(1)
    }
    GlobalShortcut {
        appid: "nocturne"
        name: "switcher-previous"
        description: "Window switcher: previous window"
        onPressed: root.step(-1)
    }
    // Bound to releasing Alt, which the switcher may not see itself if it was quick.
    GlobalShortcut {
        appid: "nocturne"
        name: "switcher-commit"
        description: "Window switcher: switch to the chosen window"
        onPressed: root.commit()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(7 / 255, 7 / 255, 11 / 255, 0.26)
        opacity: card.opacity
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.switcherOpen = false
        }
    }

    Rectangle {
        id: card
        readonly property int columns: Math.max(1, Math.min(root.windows.length, Math.floor((root.width - 120) / 252)))
        anchors.centerIn: parent
        width: grid.implicitWidth + 32
        height: grid.implicitHeight + 32
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.lineStrong
        opacity: Ui.switcherOpen ? 1 : 0
        scale: Ui.switcherOpen ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutExpo } }

        focus: Ui.switcherOpen
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) root.commit(); }
        Keys.onPressed: event => {
            const back = event.modifiers & Qt.ShiftModifier;
            if (event.key === Qt.Key_Escape)
                Ui.switcherOpen = false;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.commit();
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right)
                root.step(back ? -1 : 1);
            else if (event.key === Qt.Key_Backtab || event.key === Qt.Key_Left)
                root.step(-1);
            else if (event.key === Qt.Key_Down)
                root.step(card.columns);
            else if (event.key === Qt.Key_Up)
                root.step(-card.columns);
            else
                return;
            event.accepted = true;
        }

        GridLayout {
            id: grid
            x: 16
            y: 16
            columns: card.columns
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: Ui.switcherOpen ? root.windows : []
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool current: root.selected === index
                    readonly property var entry: DesktopEntries.heuristicLookup(modelData.wayland?.appId ?? "")
                    implicitWidth: 240
                    implicitHeight: 196
                    radius: Theme.radius
                    color: current ? Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16) : area.containsMouse ? Theme.raised : "transparent"
                    border.width: current ? 2 : 1
                    border.color: current ? Theme.violet : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = tile.index
                        onClicked: { root.selected = tile.index; root.commit(); }
                    }

                    // The window itself, letterboxed into the preview area.
                    Item {
                        id: frame
                        x: 10
                        y: 10
                        width: parent.width - 20
                        height: 140
                        ClippingRectangle {
                            anchors.centerIn: parent
                            readonly property real aspect: preview.sourceSize.width > 0 ? preview.sourceSize.width / preview.sourceSize.height : 16 / 10
                            width: Math.min(frame.width, frame.height * aspect)
                            height: width / aspect
                            radius: 10
                            color: Theme.raised
                            ScreencopyView {
                                id: preview
                                anchors.fill: parent
                                captureSource: tile.modelData.wayland
                                live: Ui.switcherOpen
                                constraintSize: Qt.size(440, 280)
                            }
                            IconImage {
                                anchors.centerIn: parent
                                visible: !preview.hasContent
                                implicitSize: 48
                                source: Quickshell.iconPath(tile.entry?.icon ?? tile.modelData.wayland?.appId ?? "", "application-x-executable")
                            }
                        }
                    }

                    RowLayout {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 10 }
                        spacing: 8
                        IconImage {
                            implicitSize: 20
                            source: Quickshell.iconPath(tile.entry?.icon ?? tile.modelData.wayland?.appId ?? "", "application-x-executable")
                        }
                        Label {
                            Layout.fillWidth: true
                            text: tile.modelData.title || tile.entry?.name || tile.modelData.wayland?.appId || ""
                            font.weight: tile.current ? Font.DemiBold : Font.Normal
                            color: tile.current ? Theme.text : Theme.textSoft
                        }
                        Label {
                            text: tile.modelData.workspace?.name ?? ""
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.dim
                        }
                    }
                }
            }
        }
    }
}
