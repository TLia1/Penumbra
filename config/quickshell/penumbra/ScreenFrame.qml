import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A click-through bezel on every output. The inner cutout forms concave joins below the bar;
// it hides for fullscreen windows. It reserves no space beyond the bar's existing exclusive zone.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    visible: (Settings.screenFrame || Settings.barStyle === "framed") && !(Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false)
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "screen-frame"
    FrameSurface { anchors.fill: parent }
}
