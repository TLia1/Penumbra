import QtQuick
import QtQuick.Layouts

// Quick-settings toggle: click the body to toggle, the chevron for more.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property bool on: false
    property bool available: true
    property bool hasMore: false
    signal toggled()
    signal more()

    implicitHeight: 62
    radius: Theme.radius
    color: on ? Theme.violet : body.containsMouse ? Theme.hover : Theme.raised
    border.color: on ? Theme.violetBright : Theme.line
    opacity: available ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: root.hasMore ? 6 : 14 }
        spacing: 11
        Glyph {
            text: root.glyph
            size: 19
            color: root.on ? Theme.violetInk : Theme.violetBright
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: root.on ? Theme.violetInk : Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: 11
                color: root.on ? Theme.alpha(Theme.violetInk, 0.7) : Theme.muted
            }
        }
        Rectangle {
            visible: root.hasMore
            implicitWidth: 30
            implicitHeight: 44
            radius: Theme.radiusSmall
            color: more.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Glyph {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.on ? Theme.violetInk : Theme.muted
            }
            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more()
            }
        }
    }
}
