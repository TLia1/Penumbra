pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
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

    // Volume and microphone keys: 5% steps between 0 and 100% ("up", "down"), "mute" toggles,
    // "current" only shows the popup. Held keys repeat faster than PipeWire reports back, so each
    // step starts from the last one asked for while it is recent.
    property var targets: ({})
    // A new output/input must start from its own restored volume, even during key repeat.
    onSinkChanged: targets = Object.assign({}, targets, { volume: null })
    onSourceChanged: targets = Object.assign({}, targets, { microphone: null })
    function adjust(control, action) {
        const node = control === "microphone" ? source : sink;
        if (!node)
            return false;
        const recent = targets[control] && Date.now() - targets[control].at < 600;
        let volume = recent ? targets[control].volume : node.volume;
        let muted = node.muted;
        if (action === "mute") {
            muted = !muted;
            node.muted = muted;
        } else if (action === "up" || action === "down") {
            volume = Math.max(0, Math.min(1, Math.round(volume * 20 + (action === "up" ? 1 : -1)) / 20));
            node.volume = volume;
        }
        targets = Object.assign({}, targets, { [control]: { volume, at: Date.now() } });
        Ui.showOsd(control, Math.round(volume * 100), muted);
        return true;
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

    // Batteries of headsets, mice, keyboards and controllers: UPower's (which also hears Logitech
    // receivers), then Bluetooth's for the rest. ["Name 80%"].
    readonly property var peripheralBatteries: {
        const percent = p => Math.round(p > 1 ? p : p * 100);
        const found = UPower.devices.values
            .filter(d => d.ready && d.isPresent && !d.isLaptopBattery && d.type !== UPowerDeviceType.LinePower && d.type !== UPowerDeviceType.Battery && d.percentage > 0)
            .map(d => ({ name: d.model || d.nativePath, percent: percent(d.percentage) }));
        for (const d of bluetoothConnected)
            if (d.batteryAvailable && !found.some(f => f.name === d.name))
                found.push({ name: d.name, percent: percent(d.battery) });
        return found.map(f => `${f.name} ${f.percent}%`);
    }
    readonly property var battery: UPower.displayDevice
    // Not until UPower has answered: before that the percentage reads 0 and would warn.
    readonly property bool hasBattery: (battery?.ready ?? false) && battery.isPresent && battery.type === UPowerDeviceType.Battery
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
    // Warn once at 10% and again, as a critical notification that stays, at 5%, while
    // discharging; plugging the charger in resets both.
    // Checked later, once every binding has caught up: when hasBattery turns true,
    // batteryPercent and charging still hold their old 0 and false.
    property int batteryWarned: 100
    onBatteryPercentChanged: Qt.callLater(warnBattery)
    onChargingChanged: Qt.callLater(warnBattery)
    onHasBatteryChanged: Qt.callLater(warnBattery)
    function warnBattery() {
        if (!hasBattery || charging) {
            batteryWarned = 100;
            return;
        }
        const level = batteryPercent <= 5 ? 5 : batteryPercent <= 10 ? 10 : 100;
        if (level >= batteryWarned)
            return;
        batteryWarned = level;
        const critical = level === 5;
        Quickshell.execDetached(["notify-send", "--app-name=Battery", "--icon=" + (critical ? "battery-empty" : "battery-caution"),
            "--urgency=" + (critical ? "critical" : "normal"), critical ? "Battery critically low" : "Battery low",
            `${batteryPercent}% · ${batteryDetail}. Plug in the charger${critical ? " now" : " soon"}.`]);
    }

    // Keyboard layouts of the main keyboard, e.g. ["us", "fr"], and the one in use.
    readonly property var layouts: (Config.values.kb_layout ?? "us").split(",").map(l => l.trim()).filter(l => l)
    property int layoutIndex: 0
    readonly property string layoutName: Wm.keyboardLayout || (layouts[0] ?? "")
    readonly property string layoutCode: (layouts.find(l => Wm.keyboardLayout.toLowerCase().includes(l.toLowerCase())) ?? layouts[layoutIndex] ?? Wm.keyboardLayout.slice(0, 2)).toUpperCase()
    function nextLayout() {
        layoutSwitched = true;
        layoutIndex = (layoutIndex + 1) % Math.max(1, layouts.length);
        Wm.nextKeyboardLayout();
    }
    Connections {
        target: Wm
        function onKeyboardLayoutChanged() {
            if (root.layoutSwitched && Wm.keyboardLayout !== "")
                Ui.showOsd("layout", 0, false, Wm.keyboardLayout);
            root.layoutSwitched = false;
        }
    }
    // Whether the next reading follows a layout switch, which shows in the popup.
    property bool layoutSwitched: false

    // Caps Lock: the compositor runs `ipc call osd capsLock` when the key is released,
    // and says whether it is now on. Laptops often have no light for it.
    property bool capsLock: false
    Process {
        id: capsCheck
        command: ["bash", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | grep -qx 1 && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.capsLock = text.trim() === "1";
                Ui.showOsd("capslock", 0, !root.capsLock, root.capsLock ? "Caps Lock on" : "Caps Lock off");
            }
        }
    }
    function showCapsLock() {
        capsCheck.running = true;
    }
}
