import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    spacing: 12

    Component.onCompleted: NightLight.citiesWanted = true

    PageHeader {
        Layout.fillWidth: true
        title: "Weather"
        status: Settings.weatherEnabled ? Weather.place?.name ?? "Choose a location" : "Off"
        checked: Settings.weatherEnabled
        onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
        onBack: Ui.controlPage = "look"
    }

    Overline { Layout.fillWidth: true; text: "Location" }
    Field {
        id: location
        Layout.fillWidth: true
        text: Settings.weatherPlace ?? Settings.nightPlace
        placeholderText: "City or latitude, longitude"
        invalid: text.trim() !== "" && !NightLight.locate(text)
        onEditingFinished: if (!invalid) Settings.weatherPlace = text.trim()
    }
    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: location.invalid ? "City not found. Try a nearby time zone city, or latitude, longitude (for example, 48.86, 2.35)."
            : location.text.trim() === "" ? "Uses your computer's time zone city. Enter a city or coordinates for a more precise location."
            : "Location: " + (NightLight.locate(location.text)?.name ?? location.text)
        color: location.invalid ? Theme.rose : Theme.muted
        font.pixelSize: Theme.textSmall
        wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        PillButton {
            text: "Apply location"
            primary: true
            available: !location.invalid
            onClicked: Settings.weatherPlace = location.text.trim()
        }
        PillButton {
            text: "Use time zone"
            onClicked: { location.text = ""; Settings.weatherPlace = ""; }
        }
    }

    Overline { Layout.fillWidth: true; text: "Display" }
    SwitchRow {
        Layout.fillWidth: true
        title: "Weather beside the clock"
        subtitle: "Temperature and sky conditions in the bar"
        glyph: "󰖐"
        checked: Settings.weatherInBar
        onToggled: Settings.weatherInBar = !Settings.weatherInBar
    }
    WeatherCard {
        Layout.fillWidth: true
        visible: Settings.weatherEnabled
    }
    Label {
        Layout.fillWidth: true
        text: "Open-Meteo · Updates every 30 minutes while weather is enabled."
        color: Theme.dim
        font.pixelSize: Theme.textSmall
        wrapMode: Text.Wrap
    }
}
