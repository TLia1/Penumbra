import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Full-screen session overlay. Destructive choices need a second press to confirm.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.sessionOpen || backdrop.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-session"
    WlrLayershell.keyboardFocus: Ui.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var entries: [
        { glyph: "󰌾", label: "Lock", command: "loginctl lock-session" },
        { glyph: "󰤄", label: "Suspend", command: "systemctl suspend" },
        // Windows are asked to close first, so apps can save or ask about unsaved work (penumbra-exit).
        { glyph: "󰍃", label: "Log out", command: Ui.bin + "penumbra-exit logout", confirm: true },
        { glyph: "󰜉", label: "Restart", command: Ui.bin + "penumbra-exit reboot", confirm: true },
        { glyph: "󰐥", label: "Shut down", command: Ui.bin + "penumbra-exit poweroff", confirm: true }
    ]
    property int selected: 0
    property int armed: -1

    Connections {
        target: Ui
        function onSessionOpenChanged() {
            root.selected = 0;
            root.armed = -1;
        }
    }

    function choose(index) {
        const entry = entries[index];
        if (entry.confirm && armed !== index) {
            armed = index;
            selected = index;
            return;
        }
        Ui.sessionOpen = false;
        Ui.run(entry.command);
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.62)
        opacity: Ui.sessionOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        focus: Ui.sessionOpen
        Keys.onEscapePressed: Ui.sessionOpen = false
        Keys.onLeftPressed: { root.selected = (root.selected + root.entries.length - 1) % root.entries.length; root.armed = -1; }
        Keys.onRightPressed: { root.selected = (root.selected + 1) % root.entries.length; root.armed = -1; }
        Keys.onTabPressed: { root.selected = (root.selected + 1) % root.entries.length; root.armed = -1; }
        Keys.onReturnPressed: root.choose(root.selected)
        Keys.onEnterPressed: root.choose(root.selected)
        Keys.onSpacePressed: root.choose(root.selected)

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.sessionOpen = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 26
            scale: Ui.sessionOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "S E S S I O N"
                font.pixelSize: Theme.textBody
                color: Theme.accent
            }

            RowLayout {
                spacing: 14
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index
                        readonly property bool isArmed: root.armed === index
                        implicitWidth: 132
                        implicitHeight: 140
                        radius: Theme.radiusLarge
                        color: isArmed ? Theme.alpha(Theme.rose, 0.22) : current ? Theme.raised : Theme.glassStrong
                        border.width: current ? 2 : 1
                        border.color: isArmed ? Theme.rose : current ? Theme.accent : Theme.line
                        scale: current ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

                        CardLight { radius: tile.radius; pointer: Qt.point(tileMouse.mouseX, tileMouse.mouseY); hovered: tileMouse.containsMouse }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Glyph {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.glyph
                                size: 34
                                color: tile.isArmed ? Theme.rose : tile.current ? Theme.accentBright : Theme.textSoft
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.isArmed ? "Confirm" : tile.modelData.label
                                font.pixelSize: Theme.textMedium
                                font.weight: tile.current ? Font.DemiBold : Font.Normal
                                color: tile.isArmed ? Theme.rose : Theme.text
                            }
                        }
                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (root.armed !== tile.index) { root.selected = tile.index; root.armed = -1; }
                            onClicked: root.choose(tile.index)
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.armed >= 0 ? `Press again to ${root.entries[root.armed].label.toLowerCase()} · Esc to cancel` : "← → to choose · Enter to select · Esc to close"
                font.pixelSize: Theme.textSmall
                color: root.armed >= 0 ? Theme.rose : Theme.muted
            }
        }
    }
}
