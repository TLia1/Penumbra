import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A glass sheet that grows from its bar capsule and closes on Escape or a click outside.
PanelWindow {
    id: panel

    property bool open: false
    property string originKey: ""
    // Screen-local bar coordinates also work for keyboard/IPC opens. Clamp to the sheet when
    // a capsule lies outside it; without a bar (startup), grow from its nearest upper corner.
    readonly property real originX: Math.max(0, Math.min(sheetWidth,
        (Ui.panelOrigins[screen?.name]?.[originKey] ?? (anchors.right ? screen?.width ?? sheetWidth : 0))
        - (anchors.right ? (screen?.width ?? implicitWidth) - margins.right - implicitWidth : margins.left)
        - shadowRoom))
    property real expansion: open ? 1 : 0
    Behavior on expansion {
        enabled: !Theme.reducedMotion
        SpringAnimation { spring: 4.5; damping: 0.82; epsilon: 0.001 }
    }
    property int sheetWidth: 380
    default property alias content: sheet.data
    property alias sheet: sheet
    // Items that see key presses before the sheet does (which closes on Escape).
    property list<Item> keyTargets
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

    // The material, rim and shadow share one transform, so their edges never separate.
    Item {
        id: surface
        x: panel.shadowRoom
        y: panel.shadowRoom
        width: panel.sheetWidth
        height: sheet.height
        transform: Scale {
            origin.x: panel.originX
            origin.y: -Theme.gap - Theme.barHeight / 2
            xScale: 0.86 + 0.14 * panel.expansion
            yScale: xScale
        }

        Shadow { target: sheet }
        Rectangle {
            id: sheet
            width: panel.sheetWidth
            // Content sits at x/y = 18; keep the same padding below it.
            implicitHeight: childrenRect.y + childrenRect.height + 18
            height: implicitHeight
            clip: true
            radius: Theme.corner(Theme.barHeight / 2 + (22 - Theme.barHeight / 2) * panel.expansion)
            color: Theme.glassStrong
            border.color: Theme.line
            opacity: panel.open ? 1 : 0
            focus: panel.open
            Keys.forwardTo: panel.keyTargets
            Keys.onEscapePressed: panel.dismissed()
            Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        }
        // Outside the sheet so it doesn't count toward the content height.
        GlassEdge {
            anchors.fill: sheet
            radius: sheet.radius
            opacity: sheet.opacity
        }
    }
}
