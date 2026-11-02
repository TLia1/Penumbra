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
    // On is a violet tint with the accent on the icon's disc; a solid fill outweighed the panel.
    color: on ? Theme.alpha(Theme.accent, body.containsMouse ? 0.3 : 0.22) : body.containsMouse ? Theme.hover : Theme.raised
    border.color: on ? Theme.alpha(Theme.accentBright, 0.55) : Theme.line
    opacity: available ? 1 : 0.45
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 12; rightMargin: root.hasMore ? 6 : 14 }
        spacing: 11
        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.corner(18)
            color: root.on ? Theme.accent : Theme.alpha(Theme.accent, 0.12)
            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
            Glyph {
                anchors.centerIn: parent
                text: root.glyph
                size: 17
                color: root.on ? Theme.onAccent : Theme.accentBright
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Theme.textSmall
                color: root.on ? Theme.accentBright : Theme.muted
            }
        }
        Rectangle {
            visible: root.hasMore
            implicitWidth: 30
            implicitHeight: 44
            radius: Theme.radiusSmall
            color: more.containsMouse ? Theme.overlay : "transparent"
            Glyph {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.on ? Theme.accentBright : Theme.muted
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
