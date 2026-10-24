import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Push the pointer into the top-left corner for the overview, the top-right one for the
// control center. A short dwell keeps a passing pointer from opening them; corners rest
// while a window is fullscreen.
Variants {
    model: Quickshell.screens

    delegate: Scope {
        id: output
        required property var modelData
        readonly property bool fullscreen: Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false

        component Corner: PanelWindow {
            id: corner
            property bool left: true
            signal reached()
            screen: output.modelData
            visible: !output.fullscreen
            anchors { top: true; left: corner.left; right: !corner.left }
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 3
            implicitHeight: 3
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            // Not nocturne-*: nothing here to blur.
            WlrLayershell.namespace: "hot-corner"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: dwell.restart()
                onExited: dwell.stop()
            }
            Timer {
                id: dwell
                interval: 160
                onTriggered: corner.reached()
            }
        }

        Corner {
            left: true
            onReached: Ui.toggleOverview()
        }
        Corner {
            left: false
            onReached: Ui.toggleControl()
        }
    }
}
