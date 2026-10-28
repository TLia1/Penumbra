import QtQuick

// A colour to pick, as a chip, ringed when it is the chosen one: round, or square with sharp corners.
Item {
    id: root

    property color color
    property bool selected: false
    signal picked()

    implicitWidth: 30
    implicitHeight: 30

    Rectangle {
        anchors.fill: parent
        radius: Theme.corner(width / 2)
        color: "transparent"
        border.width: 2
        border.color: root.selected ? Theme.text : area.containsMouse ? Theme.lineStrong : "transparent"
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }
    Rectangle {
        anchors { fill: parent; margins: 4 }
        radius: Theme.corner(width / 2)
        color: root.color
        border.color: Theme.overlayStrong
        Behavior on color { ColorAnimation { duration: Theme.slow } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
    }
}
