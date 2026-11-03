import QtQuick

// Small text button used inside expanded rows.
Rectangle {
    id: root
    scale: Theme.reducedMotion ? 1 : (available ? (area.pressed ? 0.96 : area.containsMouse ? 1.02 : 1) : 1)
    Behavior on scale { enabled: !Theme.reducedMotion; SpringAnimation { spring: 5; damping: 0.7 } }

    property string text
    property bool primary: false
    property bool danger: false
    property bool available: true
    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: Math.max(34, label.implicitHeight + 16)
    radius: Theme.corner(height / 2)
    opacity: available ? 1 : 0.45
    color: primary ? (area.containsMouse ? Theme.accentBright : Theme.accent) : area.containsMouse ? Theme.hover : Theme.control
    border.color: danger ? Theme.alpha(Theme.rose, 0.5) : primary ? Theme.accentBright : Theme.line
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.textSmall
        font.weight: Font.DemiBold
        color: root.primary ? Theme.accentInk : root.danger ? Theme.rose : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
