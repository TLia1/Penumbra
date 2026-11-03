import QtQuick
import QtQuick.Layouts
import "sun.js" as Sun

Rectangle {
    id: root
    property date date: Clock.date
    readonly property var moon: Sun.moon(date)
    implicitHeight: content.implicitHeight + 24
    radius: Theme.radius
    color: Theme.raised
    border.color: Theme.line
    GlassEdge { anchors.fill: parent; radius: parent.radius; strength: 0.14 }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 6
        RowLayout {
            Layout.fillWidth: true
            Label { text: root.moon.glyph; font.pixelSize: 28 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { Layout.fillWidth: true; text: root.moon.name; color: Theme.accentBright; font.weight: Font.DemiBold }
                Label { text: `${Math.round(root.moon.illumination * 100)}% illuminated`; color: Theme.textSoft; font.pixelSize: Theme.textSmall }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: Settings.weatherEnabled
            spacing: 4
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.line }
            Label {
                Layout.fillWidth: true
                text: Weather.place?.name ?? "Choose a location in Settings → Look → Weather"
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
            Label {
                Layout.fillWidth: true
                text: Weather.current ? `${Math.round(Weather.current.temperature_2m)}°C · ${Weather.description}` : Weather.result.status === "offline" ? "Weather unavailable offline" : Weather.place ? "Loading weather…" : ""
                font.pixelSize: Theme.textHeading
                wrapMode: Text.Wrap
            }
            Label {
                Layout.fillWidth: true
                visible: !!Weather.current
                text: Weather.current ? `Feels ${Math.round(Weather.current.apparent_temperature)}° · Wind ${Math.round(Weather.current.wind_speed_10m)} km/h` : ""
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
                wrapMode: Text.Wrap
            }
            Label {
                Layout.fillWidth: true
                text: "Open-Meteo · " + (Weather.stale ? "Cached · " : "") + (Weather.result.at ? Qt.formatTime(new Date(Weather.result.at * 1000), "HH:mm") : "30 min updates")
                color: Theme.dim
                font.pixelSize: Theme.textTiny
            }
            PillButton {
                visible: Weather.result.status === "offline"
                text: "Retry"
                onClicked: { Weather.lastAttempt = 0; Weather.refresh(); }
            }
        }
    }
}
