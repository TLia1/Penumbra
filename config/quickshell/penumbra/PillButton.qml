import QtQuick

// Small text button used inside expanded rows.
Rectangle {
    id: root

    property string text
    property bool primary: false
    property bool danger: false
    property bool available: true
    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30
    radius: Theme.corner(height / 2)
    opacity: available ? 1 : 0.45
    color: primary ? (area.containsMouse ? Theme.violetBright : Theme.violet) : area.containsMouse ? Theme.hover : Theme.raised
    border.color: danger ? Qt.rgba(239 / 255, 143 / 255, 164 / 255, 0.5) : primary ? Theme.violetBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.primary ? Theme.violetInk : root.danger ? Theme.rose : Theme.text
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
