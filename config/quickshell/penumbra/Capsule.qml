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

    signal clicked(var mouse)
    // One step per wheel notch: +1 up, -1 down. Touchpads send many small deltas, which add up
    // to a notch (120) before anything happens.
    signal scrolled(int step)
    property int wheelRest: 0

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: Theme.corner(height / 2)
    color: active ? Theme.violet : (interactive && hovered ? Theme.hover : Theme.glass)
    border.width: 1
    border.color: active ? Theme.violetBright : Theme.line
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

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
