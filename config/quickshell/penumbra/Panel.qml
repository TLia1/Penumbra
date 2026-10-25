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

    // Room around the sheet for its shadow; panels anchor with Theme.edge - shadowRoom, so the
    // sheet itself still sits Theme.edge from the screen's edge.
    readonly property int shadowRoom: Theme.edge

    screen: Ui.screen
    visible: open || sheet.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sheetWidth + 2 * shadowRoom
    // A fixed-height surface; only the sheet takes input, so it can grow and shrink smoothly.
    implicitHeight: (screen?.height ?? 1080) - margins.top - Theme.edge
    mask: Region { item: sheet }
    margins.top: Theme.barHeight + 10 + Theme.gap - shadowRoom
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "penumbra-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.dismissed()
    }

    Shadow { target: sheet }

    Rectangle {
        id: sheet
        x: panel.shadowRoom
        width: panel.sheetWidth
        // Content sits at x/y = 18; keep the same padding below it.
        implicitHeight: childrenRect.y + childrenRect.height + 18
        height: implicitHeight
        clip: true
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: panel.open ? 1 : 0
        y: panel.shadowRoom + (panel.open ? 0 : -14)
        focus: panel.open
        Keys.onEscapePressed: panel.dismissed()
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
    // Over the sheet rather than inside it, where it would count towards the sheet's height.
    GlassEdge {
        anchors.fill: sheet
        radius: sheet.radius
        opacity: sheet.opacity
    }
}
