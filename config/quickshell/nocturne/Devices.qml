pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Live device state, with the glyphs the bar and control center show for it.
Singleton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    readonly property int volume: sink ? Math.round(sink.volume * 100) : 0
    readonly property bool muted: sink?.muted ?? true
    readonly property string volumeGlyph: muted ? "󰝟" : volume > 60 ? "󰕾" : volume > 25 ? "󰖀" : "󰕿"
    readonly property bool micMuted: source?.muted ?? true
    function setVolume(percent) {
        if (!sink)
            return;
        sink.muted = false;
        sink.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property string networkName: wifiNetwork ? wifiNetwork.name : wired ? "Wired" : "Offline"
    // Signal strength as 0–1, whichever scale the backend reports.
    function strength(network) {
        return network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength;
    }
    function signalGlyph(network) {
        const s = strength(network);
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }
    readonly property string networkGlyph: {
        if (wifiNetwork)
            return signalGlyph(wifiNetwork);
        return wired ? "󰈀" : Networking.wifiEnabled ? "󰤯" : "󰤭";
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property var bluetoothConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string bluetoothGlyph: !adapter ? "󰂲" : !bluetoothOn ? "󰂲" : bluetoothConnected.length ? "󰂱" : "󰂯"
    readonly property string bluetoothName: !adapter ? "No adapter" : !bluetoothOn ? "Off" : bluetoothConnected.length ? bluetoothConnected[0].name : "On"

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isPresent && battery.type === UPowerDeviceType.Battery
    readonly property int batteryPercent: !hasBattery ? 0 : Math.round(battery.percentage > 1 ? battery.percentage : battery.percentage * 100)
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge)
    readonly property string batteryGlyph: charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(batteryPercent / 20))]
    readonly property color batteryColor: charging ? Theme.green : batteryPercent <= 10 ? Theme.rose : batteryPercent <= 25 ? Theme.amber : Theme.textSoft
    readonly property string batteryDetail: {
        if (!hasBattery)
            return "";
        const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!seconds)
            return charging ? "Charging" : "On battery";
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return `${h ? h + " h " : ""}${m} min ${charging ? "until full" : "left"}`;
    }
}
