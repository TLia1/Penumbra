import QtQuick

// Pill switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    radius: Theme.corner(12)
    color: checked ? Theme.violet : Theme.raised
    border.color: checked ? Theme.violetBright : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18
        height: 18
        radius: Theme.corner(9)
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.violetInk : Theme.textSoft
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
