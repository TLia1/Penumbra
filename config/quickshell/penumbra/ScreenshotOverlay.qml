import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Print: the screen freezes; drag a region, click a window or click for the whole screen.
// The overlay then steps aside (no closing animation) and penumbra-shot captures the area.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.shotOpen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-shot"
    WlrLayershell.keyboardFocus: Ui.shotOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string mode: "region" // region, window or screen
    property bool annotate: false
    property rect selection: Qt.rect(0, 0, 0, 0)
    property point origin
    property bool dragging: false
    property var hovered: null // window geometry under the pointer, in window mode

    readonly property var monitor: Hyprland.monitorFor(screen)
    // Windows on this screen's workspace in local coordinates, floating ones first (they're on top).
    readonly property var windows: (monitor?.activeWorkspace?.toplevels.values ?? [])
        .filter(t => t.lastIpcObject.size)
        .sort((a, b) => (b.lastIpcObject.floating ?? false) - (a.lastIpcObject.floating ?? false))
        .map(t => ({
            title: t.title,
            rect: Qt.rect(t.lastIpcObject.at[0] - monitor.x, t.lastIpcObject.at[1] - monitor.y, t.lastIpcObject.size[0], t.lastIpcObject.size[1])
        }))
    // What gets captured if the user confirms now.
    readonly property rect target: mode === "screen" ? Qt.rect(0, 0, width, height)
        : mode === "window" ? (hovered?.rect ?? Qt.rect(0, 0, 0, 0)) : selection

    function open(withAnnotate) {
        Ui.openShot();
        annotate = withAnnotate;
    }
    // Start fresh however it opens (Print, or the control center's tile).
    Connections {
        target: Ui
        function onShotOpenChanged() {
            if (!Ui.shotOpen)
                return;
            Hyprland.refreshToplevels();
            root.annotate = false;
            root.mode = "region";
            root.selection = Qt.rect(0, 0, 0, 0);
            root.hovered = null;
            root.dragging = false;
        }
    }
    function capture() {
        const r = target;
        if (r.width < 4 || r.height < 4)
            return;
        const geometry = `${Math.round(r.x + monitor.x)},${Math.round(r.y + monitor.y)} ${Math.round(r.width)}x${Math.round(r.height)}`;
        Ui.shotOpen = false;
        shoot.args = [Ui.bin + "penumbra-shot", ...(annotate ? ["annotate"] : []), "--geometry", geometry];
        shoot.restart();
    }
    // Let the compositor draw a frame without the overlay before grim reads the screen.
    Timer {
        id: shoot
        property var args: []
        interval: 90
        onTriggered: Quickshell.execDetached(args)
    }
    function windowAt(x, y) {
        return windows.find(w => x >= w.rect.x && x < w.rect.x + w.rect.width && y >= w.rect.y && y < w.rect.y + w.rect.height) ?? null;
    }

    // The frozen frame, taken once as the overlay opens.
    ScreencopyView {
        id: frame
        anchors.fill: parent
        captureSource: Ui.shotOpen ? root.screen : null
        live: false
    }

    Item {
        id: content
        anchors.fill: parent
        visible: frame.hasContent
        focus: Ui.shotOpen
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                Ui.shotOpen = false;
            else if (event.key === Qt.Key_R)
                root.mode = "region";
            else if (event.key === Qt.Key_W)
                root.mode = "window";
            else if (event.key === Qt.Key_S)
                root.mode = "screen";
            else if (event.key === Qt.Key_E)
                root.annotate = !root.annotate;
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                root.capture();
            else
                return;
            event.accepted = true;
        }

        // Dim everything but the target: above, below, left and right of it.
        component Shade: Rectangle {
            color: Qt.rgba(7 / 255, 7 / 255, 11 / 255, 0.5)
        }
        Shade { width: root.width; height: Math.max(0, root.target.y) }
        Shade {
            y: root.target.y + root.target.height
            width: root.width
            height: Math.max(0, root.height - y)
        }
        Shade {
            y: root.target.y
            width: Math.max(0, root.target.x)
            height: root.target.height
        }
        Shade {
            x: root.target.x + root.target.width
            y: root.target.y
            width: Math.max(0, root.width - x)
            height: root.target.height
        }
        Rectangle {
            visible: root.target.width > 0 && root.target.height > 0 && root.mode !== "screen"
            x: root.target.x - 2
            y: root.target.y - 2
            width: root.target.width + 4
            height: root.target.height + 4
            color: "transparent"
            radius: Theme.corner(4)
            border.width: 2
            border.color: Theme.violet
            Rectangle {
                anchors { left: parent.left; top: parent.bottom; topMargin: 8 }
                visible: parent.width > 60
                implicitWidth: size.implicitWidth + 16
                implicitHeight: 22
                radius: Theme.corner(11)
                color: Theme.glassStrong
                Label {
                    id: size
                    anchors.centerIn: parent
                    text: `${Math.round(root.target.width)} × ${Math.round(root.target.height)}`
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.textSoft
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor
            onPressed: m => {
                if (root.mode !== "region")
                    return;
                root.origin = Qt.point(m.x, m.y);
                root.selection = Qt.rect(m.x, m.y, 0, 0);
                root.dragging = true;
            }
            onPositionChanged: m => {
                if (root.mode === "window")
                    root.hovered = root.windowAt(m.x, m.y);
                else if (root.dragging)
                    root.selection = Qt.rect(Math.min(m.x, root.origin.x), Math.min(m.y, root.origin.y),
                        Math.abs(m.x - root.origin.x), Math.abs(m.y - root.origin.y));
            }
            onReleased: {
                const wasDragging = root.dragging;
                root.dragging = false;
                if (root.mode !== "region" || wasDragging)
                    root.capture();
            }
        }

        // Mode and after-capture choices.
        Rectangle {
            id: toolbar
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
            visible: !root.dragging
            implicitWidth: tools.implicitWidth + 16
            implicitHeight: 52
            radius: Theme.corner(26)
            color: Theme.glassStrong
            border.color: Theme.lineStrong

            // Clicks between the buttons stay on the toolbar.
            MouseArea { anchors.fill: parent }

            RowLayout {
                id: tools
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: [
                        { mode: "region", glyph: "󰆞", label: "Region", key: "R" },
                        { mode: "window", glyph: "󰖯", label: "Window", key: "W" },
                        { mode: "screen", glyph: "󰍹", label: "Screen", key: "S" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: root.mode === modelData.mode
                        implicitWidth: toolRow.implicitWidth + 24
                        implicitHeight: 38
                        radius: Theme.corner(19)
                        color: current ? Theme.violet : toolArea.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        RowLayout {
                            id: toolRow
                            anchors.centerIn: parent
                            spacing: 7
                            Glyph { text: modelData.glyph; size: 15; color: current ? Theme.violetInk : Theme.textSoft }
                            Label { text: modelData.label; font.weight: Font.DemiBold; color: current ? Theme.violetInk : Theme.text }
                        }
                        MouseArea {
                            id: toolArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.mode = modelData.mode; root.hovered = null; }
                        }
                    }
                }
                Rectangle {
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    implicitWidth: 1
                    implicitHeight: 24
                    color: Theme.line
                }
                Rectangle {
                    implicitWidth: editRow.implicitWidth + 24
                    implicitHeight: 38
                    radius: Theme.corner(19)
                    color: root.annotate ? Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.2) : editArea.containsMouse ? Theme.hover : "transparent"
                    border.color: root.annotate ? Theme.violet : "transparent"
                    RowLayout {
                        id: editRow
                        anchors.centerIn: parent
                        spacing: 7
                        Glyph { text: "󰏫"; size: 15; color: root.annotate ? Theme.violetBright : Theme.textSoft }
                        Label { text: "Annotate"; color: root.annotate ? Theme.violetBright : Theme.text }
                    }
                    MouseArea {
                        id: editArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.annotate = !root.annotate
                    }
                }
                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: Theme.corner(19)
                    color: closeArea.containsMouse ? Theme.hover : "transparent"
                    Glyph { anchors.centerIn: parent; text: "󰅖"; size: 15; color: Theme.textSoft }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Ui.shotOpen = false
                    }
                }
            }
        }

        Label {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: toolbar.top; bottomMargin: 12 }
            visible: !root.dragging
            text: (root.mode === "region" ? "Drag to select" : root.mode === "window" ? "Click a window" : "Click or press Enter for the whole screen")
                + (root.annotate ? " · opens in Satty" : " · saved and copied") + " · Esc to cancel"
            font.pixelSize: 11
            color: Theme.textSoft
        }
    }
}
