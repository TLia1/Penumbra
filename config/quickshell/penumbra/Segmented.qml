import QtQuick
import QtQuick.Layouts

// A row of choices with the current one lit: power profiles, night light's schedule.
Rectangle {
    id: root

    // [{ value, title, glyph (optional), available (optional, default true) }]
    property var options: []
    property var current
    signal chosen(var value)

    implicitHeight: 42
    radius: Theme.radius
    color: Theme.raised
    border.color: Theme.line

    RowLayout {
        anchors { fill: parent; margins: 4 }
        spacing: 4
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: segment
                required property var modelData
                readonly property bool current: root.current === modelData.value
                readonly property bool available: modelData.available ?? true
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1 // equal shares
                radius: Theme.corner(Theme.radius - 4)
                color: current ? Theme.alpha(Theme.accent, 0.22) : segmentArea.containsMouse ? Theme.hover : "transparent"
                border.color: current ? Theme.alpha(Theme.accentBright, 0.55) : "transparent"
                opacity: available ? 1 : 0.45
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                RowLayout {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    spacing: 6
                    Glyph {
                        visible: !!segment.modelData.glyph
                        text: segment.modelData.glyph ?? ""
                        size: 14
                        color: segment.current ? Theme.accentBright : Theme.muted
                    }
                    Label {
                        Layout.fillWidth: true
                        text: segment.modelData.title
                        font.pixelSize: Theme.textSmall
                        font.weight: segment.current ? Font.DemiBold : Font.Normal
                        color: segment.current ? Theme.text : Theme.textSoft
                    }
                }
                MouseArea {
                    id: segmentArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: segment.available && !segment.current
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chosen(segment.modelData.value)
                }
            }
        }
    }
}
