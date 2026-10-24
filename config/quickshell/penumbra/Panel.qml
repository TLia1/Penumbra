import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A glass sheet that drops in under the bar and closes on Escape or a click outside.
PanelWindow {
    id: panel

    property bool open: false
    property int sheetWidth: 380
    default property alias content: sheet.data
    property alias sheet: sheet
    signal dismissed()

    screen: Ui.screen
    visible: open || sheet.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sheetWidth
    // A fixed-height surface; only the sheet takes input, so it can grow and shrink smoothly.
    implicitHeight: (screen?.height ?? 1080) - margins.top - Theme.edge
    mask: Region { item: sheet }
    margins.top: Theme.barHeight + 10 + Theme.gap
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "penumbra-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.dismissed()
    }

    Rectangle {
        id: sheet
        width: parent.width
        // Content sits at x/y = 18; keep the same padding below it.
        implicitHeight: childrenRect.y + childrenRect.height + 18
        height: implicitHeight
        clip: true
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: panel.open ? 1 : 0
        y: panel.open ? 0 : -14
        focus: panel.open
        Keys.onEscapePressed: panel.dismissed()
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
}
