import QtQuick
import QtQuick.Layouts

// Quick-settings toggle: click the body to toggle, the chevron for more.
Rectangle {
    id: root
    scale: Theme.reducedMotion ? 1 : (available ? (body.pressed ? 0.96 : body.containsMouse ? 1.02 : 1) : 1)
    Behavior on scale { enabled: !Theme.reducedMotion; SpringAnimation { spring: 5; damping: 0.7 } }

    property string glyph
    property string title
    property string subtitle
    property bool on: false
    property bool available: true
    property bool hasMore: false
    signal toggled()
    signal more()

    implicitHeight: Math.max(68, labels.implicitHeight + 24)
    radius: Theme.radius
    // Selected controls carry the accent; the surrounding panel stays quiet.
    color: on ? (body.containsMouse ? Theme.accentBright : Theme.accent) : body.containsMouse ? Theme.hover : Theme.control
    border.color: "transparent"
    opacity: available ? 1 : 0.45
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    CardLight { radius: root.radius; pointer: Qt.point(body.mouseX, body.mouseY); hovered: body.containsMouse }
    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: Theme.controlPadding; rightMargin: root.hasMore ? 6 : 14 }
        spacing: 11
        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.corner(18)
            color: root.on ? Theme.alpha(Theme.accentInk, 0.10) : Theme.alpha(Theme.accent, 0.10)
            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
            Glyph {
                anchors.centerIn: parent
                text: root.glyph
                size: 17
                color: root.on ? Theme.accentInk : Theme.accentBright
            }
        }
        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                wrapMode: Text.Wrap
                maximumLineCount: 2
                font.weight: Font.DemiBold
                color: root.on ? Theme.accentInk : Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Theme.textSmall
                color: root.on ? Theme.accentInk : Theme.textSoft
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
                color: root.on ? Theme.accentInk : Theme.textSoft
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
