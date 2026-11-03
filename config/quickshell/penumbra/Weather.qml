pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property var place: Settings.weatherPlace == null ? NightLight.place : NightLight.locate(Settings.weatherPlace)
    readonly property string locationKey: place ? `${place.latitude},${place.longitude}` : ""
    property var result: ({})
    property string loaded: ""
    property double lastAttempt: 0
    readonly property var current: result.current ?? null
    readonly property bool stale: result.stale === true || (!!result.at && Clock.date.getTime() / 1000 - result.at > 3600)
    readonly property string description: {
        const code = current?.weather_code;
        if (code === 0) return "Clear sky";
        if (code <= 3) return "Cloudy";
        if (code === 45 || code === 48) return "Fog";
        if (code >= 51 && code <= 57) return "Drizzle";
        if (code >= 61 && code <= 67) return "Rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
        if (code >= 80 && code <= 82) return "Showers";
        if (code >= 95) return "Thunderstorms";
        return "Weather";
    }
    function refresh() {
        if (!Settings.weatherEnabled || !place || request.running) return;
        if (loaded === locationKey && Date.now() - lastAttempt < 1800000) return;
        request.locationKey = locationKey;
        request.command = [Ui.bin + "penumbra-online", "weather", String(place.latitude), String(place.longitude)];
        loaded = locationKey;
        lastAttempt = Date.now();
        request.running = true;
    }
    onLocationKeyChanged: { result = {}; loaded = ""; settle.restart(); }
    Component.onCompleted: if (Settings.weatherEnabled) { NightLight.citiesWanted = true; settle.restart(); }
    Connections {
        target: Settings
        function onWeatherEnabledChanged() {
            root.result = {}; root.loaded = "";
            if (Settings.weatherEnabled) { NightLight.citiesWanted = true; settle.restart(); }
        }
    }
    Connections { target: Ui; function onCalendarOpenChanged() { if (Ui.calendarOpen) root.refresh(); } }
    Timer { id: settle; interval: 500; onTriggered: root.refresh() }
    Timer { interval: 1800000; repeat: true; running: Settings.weatherEnabled; onTriggered: root.refresh() }
    Process {
        id: request
        property string locationKey
        stdout: StdioCollector {
            onStreamFinished: {
                if (!Settings.weatherEnabled || request.locationKey !== root.locationKey) return;
                try { root.result = JSON.parse(text); } catch (e) { root.result = { status: "offline" }; }
            }
        }
        onExited: {
            if (request.locationKey !== root.locationKey) settle.restart();
            else if (!root.result.status) root.result = { status: "offline" };
        }
    }
}
