import QtQuick
import QtQuick.Layouts

// A labelled on/off switch; the whole row toggles.
Rectangle {
    id: row
    property string glyph
    property string title
    property string subtitle
    property bool checked: false
    signal toggled()

    Layout.fillWidth: true
    implicitHeight: Math.max(56, labels.implicitHeight + 20)
    radius: Theme.radiusSmall
    color: rowArea.containsMouse ? Theme.raised : "transparent"
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.toggled()
    }
    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 11
        Glyph { Layout.preferredWidth: 22; text: row.glyph; size: 17 }
        ColumnLayout {
            id: labels
            Layout.fillWidth: true
            spacing: 0
            Label { Layout.fillWidth: true; text: row.title }
            Label { Layout.fillWidth: true; text: row.subtitle; font.pixelSize: Theme.textSmall; color: Theme.textSoft }
        }
        Switch {
            checked: row.checked
            onToggled: row.toggled()
        }
    }
}
