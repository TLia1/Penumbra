import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Push the pointer into the top-right corner for the control center. A short dwell keeps a
// passing pointer from opening it; the corner rests while a window is fullscreen, or when it's
// turned off in settings.
Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: corner
        required property var modelData
        screen: modelData
        visible: Settings.hotCorner && !(Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false)
        anchors { top: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 3
        implicitHeight: 3
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        // Not penumbra-*: nothing here to blur.
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
            onTriggered: Ui.toggle("control")
        }
    }
}
