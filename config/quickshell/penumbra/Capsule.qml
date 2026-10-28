import QtQuick
import QtQuick.Layouts

// A floating glass pill; children are laid out in a row.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 13
    property string tip: ""
    property bool interactive: true
    property bool active: false
    readonly property bool hovered: mouse.containsMouse
    // Set instead of `visible`: the capsule fades and narrows away, and its neighbours glide.
    property bool shown: true
    property real reveal: shown ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    visible: reveal > 0
    opacity: reveal
    Layout.preferredWidth: Math.round(implicitWidth * reveal)
    clip: reveal < 1

    signal clicked(var mouse)
    // One step per wheel notch: +1 up, -1 down. Touchpads send many small deltas, which add up
    // to a notch (120) before anything happens.
    signal scrolled(int step)
    property int wheelRest: 0

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: Theme.corner(height / 2)
    color: active ? Theme.accent : (interactive && hovered ? Theme.hover : Theme.glass)
    border.width: 1
    border.color: active ? Theme.accentBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // Declared before the row so it sits underneath: children with their own
    // mouse handling (tray icons) receive their clicks, plain contents fall through.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => {
            root.wheelRest += w.angleDelta.y;
            while (Math.abs(root.wheelRest) >= 120) {
                const step = root.wheelRest > 0 ? 1 : -1;
                root.wheelRest -= step * 120;
                root.scrolled(step);
            }
        }
        onExited: root.wheelRest = 0
    }

    // An active capsule takes the focused window's border: accent shading towards accentDeep.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        opacity: root.active ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accentBright }
            GradientStop { position: 1; color: Qt.tint(Theme.accent, Theme.alpha(Theme.accentDeep, 0.4)) }
        }
    }
    // The lit top edge the panels have, so the bar reads as the same glass.
    GlassEdge {
        radius: root.radius
        strength: root.active ? 0.55 : 0.2
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
