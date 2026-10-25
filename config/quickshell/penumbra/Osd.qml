import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Volume / microphone / brightness feedback, floating above the bottom edge.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors.bottom: true
    // Room around the pill for its shadow.
    readonly property int shadowRoom: 16
    margins.bottom: 80 - shadowRoom
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300 + 2 * shadowRoom
    implicitHeight: 58 + 2 * shadowRoom
    visible: Ui.osdVisible || pill.opacity > 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-osd"

    readonly property string glyph: {
        if (Ui.osdKind === "brightness")
            return Ui.osdValue > 66 ? "󰃠" : Ui.osdValue > 33 ? "󰃟" : "󰃞";
        if (Ui.osdKind === "microphone")
            return Ui.osdMuted ? "󰍭" : "󰍬";
        return Ui.osdMuted ? "󰝟" : Ui.osdValue > 60 ? "󰕾" : Ui.osdValue > 25 ? "󰖀" : "󰕿";
    }

    Shadow { target: pill }
    Rectangle {
        id: pill
        anchors { fill: parent; margins: root.shadowRoom }
        radius: Theme.corner(height / 2)
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: Ui.osdVisible ? 1 : 0
        scale: Ui.osdVisible ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }

        GlassEdge { radius: pill.radius }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 14
            Glyph {
                text: root.glyph
                size: 19
                color: Ui.osdMuted ? Theme.dim : Theme.violetBright
                Layout.preferredWidth: 22
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Theme.corner(4)
                color: Theme.raised
                Rectangle {
                    width: parent.width * (Ui.osdMuted ? 0 : Ui.osdValue / 100)
                    height: parent.height
                    radius: Theme.corner(4)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.violetDeep }
                        GradientStop { position: 1; color: Theme.violet }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                }
            }
            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Ui.osdMuted ? "Muted" : Ui.osdValue + "%"
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
        }
    }
}
