import QtQuick
import QtQuick.Layouts

// Back arrow, title, optional status text and an on/off switch.
RowLayout {
    id: root

    property string title
    property string status
    property bool checked: false
    property bool showSwitch: true
    signal back()
    signal toggled()

    spacing: 10

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        radius: Theme.corner(17)
        color: backArea.containsMouse ? Theme.hover : Theme.raised
        border.color: Theme.line
        Glyph { anchors.centerIn: parent; text: "󰁍"; size: 15; color: Theme.textSoft }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        // fillWidth on the labels lets the column (and so the row) stretch to the switch.
        Label { Layout.fillWidth: true; text: root.title; font.pixelSize: Theme.textLarge; font.weight: Font.DemiBold }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.status; font.pixelSize: Theme.textSmall; color: Theme.muted }
    }
    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
