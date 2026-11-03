import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io

// Month view under the clock, with week numbers if you like (click "Wk") and the events of your
// calendars (penumbra-calendar reads their .ics files): a dot under each day that has some, and
// the chosen day's list below.
Panel {
    id: root
    originKey: "calendar"
    anchors { top: true; left: true }
    margins.left: edgeMargin - shadowRoom
    preferredSheetWidth: 360
    open: Ui.calendarOpen
    onDismissed: Ui.dismiss()

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    property date selected: today
    onOpenChanged: if (open) { today = new Date(); selected = today; month = today.getMonth(); year = today.getFullYear(); loadEvents(); }
    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
        loadEvents();
    }

    // The events of the six weeks on show: { "YYYY-MM-DD": [{ time, title }] }.
    property var events: ({})
    function iso(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }
    function loadEvents() {
        const first = new Date(year, month, 1 - 7), last = new Date(year, month + 1, 7);
        eventList.command = [Ui.bin + "penumbra-calendar", iso(first), iso(last)];
        eventList.running = true;
    }
    Process {
        id: eventList
        stdout: StdioCollector {
            onStreamFinished: {
                const byDay = {};
                try {
                    for (const e of JSON.parse(text))
                        (byDay[e.date] = byDay[e.date] ?? []).push(e);
                } catch (error) {}
                root.events = byDay;
            }
        }
    }
    readonly property var dayEvents: events[iso(selected)] ?? []

    Flickable {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        height: Math.min(calendarContent.implicitHeight, root.implicitHeight - 2 * root.shadowRoom - 36)
        contentHeight: calendarContent.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: calendarContent
            width: parent.width
            spacing: 10

            Overline {
                text: Qt.formatDate(root.today, "dddd")
                color: Theme.accent
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
                // Week numbers on or off.
                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 28
                    radius: Theme.corner(14)
                    color: Settings.calendarWeekNumbers ? Theme.alpha(Theme.accent, 0.2) : weekArea.containsMouse ? Theme.hover : "transparent"
                    Label { anchors.centerIn: parent; text: "Wk"; font.pixelSize: Theme.textTiny; font.weight: Font.DemiBold; color: Settings.calendarWeekNumbers ? Theme.accent : Theme.dim }
                    MouseArea {
                        id: weekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.calendarWeekNumbers = !Settings.calendarWeekNumbers
                    }
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
                Layout.leftMargin: Settings.calendarWeekNumbers ? weeks.width + 4 : 0
                locale: grid.locale
                delegate: Label {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.textTiny
                    color: Theme.dim
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                WeekNumberColumn {
                    id: weeks
                    visible: Settings.calendarWeekNumbers
                    Layout.preferredHeight: grid.Layout.preferredHeight
                    implicitWidth: 22
                    month: root.month
                    year: root.year
                    locale: grid.locale
                    spacing: 2
                    delegate: Label {
                        required property int weekNumber
                        text: weekNumber
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
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
                    onClicked: d => root.selected = d
                    delegate: Rectangle {
                        required property var model
                        readonly property bool isToday: model.today
                        readonly property bool isSelected: root.iso(model.date) === root.iso(root.selected) && !isToday
                        readonly property bool busy: (root.events[root.iso(model.date)] ?? []).length > 0
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Theme.corner(17)
                        color: isToday ? Theme.accent : isSelected ? Theme.raised : "transparent"
                        border.color: isSelected ? Theme.lineStrong : "transparent"
                        Label {
                            anchors.centerIn: parent
                            text: model.day
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                            color: parent.isToday ? Theme.accentInk : model.month === root.month ? Theme.text : Theme.dim
                        }
                        Rectangle {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            visible: parent.busy
                            width: 4
                            height: 4
                            radius: 2
                            color: parent.isToday ? Theme.accentInk : Theme.accentBright
                        }
                    }
                }
            }

            WeatherCard { Layout.fillWidth: true }

            // The chosen day's events.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: root.dayEvents.length > 0
                spacing: 4
                Overline {
                    Layout.fillWidth: true
                    text: root.iso(root.selected) === root.iso(root.today) ? "Today" : Qt.formatDate(root.selected, "dddd d MMMM")
                }
                Repeater {
                    model: root.dayEvents
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 10
                        Label {
                            Layout.preferredWidth: 46
                            text: modelData.time || "All day"
                            font.family: Theme.mono
                            font.pixelSize: Theme.textTiny
                            color: Theme.accent
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
