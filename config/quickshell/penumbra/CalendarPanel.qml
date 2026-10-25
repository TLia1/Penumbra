import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Month view under the clock.
Panel {
    id: root
    anchors { top: true; left: true }
    margins.left: Theme.edge - shadowRoom
    sheetWidth: 320
    open: Ui.calendarOpen
    onDismissed: Ui.dismiss()

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    onOpenChanged: if (open) { today = new Date(); month = today.getMonth(); year = today.getFullYear(); }
    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 10

        Overline {
            text: Qt.formatDate(root.today, "dddd")
            color: Theme.violet
        }
        Label {
            text: Qt.formatDate(root.today, "d MMMM yyyy")
            font.family: Theme.display
            font.pixelSize: Theme.textHeading
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                font.weight: Font.DemiBold
                color: Theme.textSoft
            }
            Repeater {
                model: [{ glyph: "󰅁", delta: -1 }, { glyph: "󰅂", delta: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Theme.corner(14)
                    color: navArea.containsMouse ? Theme.hover : "transparent"
                    Glyph { anchors.centerIn: parent; text: modelData.glyph; color: Theme.textSoft }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shift(modelData.delta)
                    }
                }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Label {
                required property string shortName
                text: shortName.slice(0, 2)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.textTiny
                color: Theme.dim
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 34 + 5 * 2
            month: root.month
            year: root.year
            locale: Qt.locale()
            spacing: 2
            delegate: Rectangle {
                required property var model
                readonly property bool isToday: model.today
                implicitWidth: 34
                implicitHeight: 34
                radius: Theme.corner(17)
                color: isToday ? Theme.violet : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: model.day
                    font.weight: parent.isToday ? Font.Bold : Font.Normal
                    color: parent.isToday ? Theme.violetInk : model.month === root.month ? Theme.text : Theme.dim
                }
            }
        }
    }
}
