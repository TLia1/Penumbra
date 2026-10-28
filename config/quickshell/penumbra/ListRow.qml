import QtQuick
import QtQuick.Layouts

// A device or network row; `expanded` reveals the extra content below it.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property string trailing: "" // glyph on the right, e.g. a lock
    property bool highlighted: false
    property bool busy: false
    property bool expanded: false
    property bool danger: false
    default property alias extra: extraColumn.data
    signal clicked()

    implicitHeight: column.implicitHeight + 16
    radius: Theme.radiusSmall
    color: highlighted ? Theme.line : area.containsMouse || expanded ? Theme.raised : "transparent"
    border.color: highlighted ? Theme.lineStrong : expanded ? Theme.line : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    clip: true

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 11
            Glyph {
                Layout.preferredWidth: 22
                text: root.glyph
                size: 17
                color: root.highlighted ? Theme.accentBright : Theme.textSoft
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: root.title; font.weight: root.highlighted ? Font.DemiBold : Font.Normal }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: Theme.textSmall
                    color: root.danger ? Theme.rose : root.highlighted ? Theme.accent : Theme.muted
                }
            }
            Glyph {
                visible: root.busy
                text: "󰔟"
                size: 14
                color: Theme.accent
                RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
            }
            Glyph {
                visible: root.trailing !== "" && !root.busy
                text: root.trailing
                size: 13
                color: Theme.dim
            }
        }

        ColumnLayout {
            id: extraColumn
            Layout.fillWidth: true
            Layout.leftMargin: 33
            visible: root.expanded
            spacing: 8
        }
    }
}
