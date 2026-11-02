pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polled system state: backlight, pending updates and the battery's charge limit. Resource usage
// is in Usage.
Singleton {
    id: root

    // Battery care: laptops whose firmware supports it stop charging at Settings.batteryLimit.
    // The file is root's; Penumbra's udev rule (90-penumbra-battery.rules) lets the session write
    // it. Firmware may forget it at power-off, so the shell sets it again at each start.
    property string chargeLimitFile: "" // empty: not supported
    property bool chargeLimitWritable: false
    Process {
        running: true
        command: ["bash", "-c", "for f in /sys/class/power_supply/BAT*/charge_control_end_threshold; do [[ -e $f ]] || continue; [[ -w $f ]] && echo \"w $f\" || echo \"r $f\"; break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /^([rw]) (.+)$/.exec(text.trim());
                root.chargeLimitFile = m ? m[2] : "";
                root.chargeLimitWritable = !!m && m[1] === "w";
                // At start only a limit you set, so one set by other tools (TLP) stays alone.
                if (Settings.batteryLimit < 100)
                    root.applyChargeLimit();
            }
        }
    }
    function applyChargeLimit() {
        if (chargeLimitFile && chargeLimitWritable)
            Quickshell.execDetached(["bash", "-c", 'echo "$1" > "$2"', "bash", String(Settings.batteryLimit), chargeLimitFile]);
    }
    Connections {
        target: Settings
        function onBatteryLimitChanged() { root.applyChargeLimit(); }
    }

    property int brightness: -1 // -1 when the machine has no backlight
    property int updates: 0
    property string updatesDetail: ""
    property var updateSources: [] // [{ name, packages: ["name old -> new" or a Flatpak ref] }]
    property var updateNews: [] // the distribution's latest news: [{ title, link, date, new }]
    property var restartReasons: [] // why a restart is due ("The kernel was updated")
    readonly property bool unreadNews: updateNews.some(n => n.new)
    property bool checkingUpdates: updateCheck.running

    // brightnessctl -m prints: device,class,current,percent%,max
    Process {
        id: backlight
        command: ["brightnessctl", "-m", "--class=backlight", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                root.brightness = parts.length >= 4 ? parseInt(parts[3]) : -1;
            }
        }
    }
    function refreshBrightness() {
        backlight.running = true;
    }
    // Brightness keys: 5% steps, never down to black; the popup shows the result.
    Process {
        id: brightnessStep
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length < 4)
                    return;
                root.brightness = parseInt(parts[3]);
                Ui.showOsd("brightness", root.brightness, false);
            }
        }
    }
    function stepBrightness(action) {
        if (root.brightness < 0)
            return false;
        if (action === "current") {
            Ui.showOsd("brightness", root.brightness, false);
            return true;
        }
        if (action !== "up" && action !== "down")
            return false;
        brightnessStep.command = ["brightnessctl", "-m", "--class=backlight", "--min-value=1", "set", action === "up" ? "5%+" : "5%-"];
        brightnessStep.running = true;
        return true;
    }
    function setBrightness(percent) {
        root.brightness = Math.max(1, Math.round(percent));
        brightnessDebounce.restart();
    }
    Timer {
        id: brightnessDebounce
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "--class=backlight", "--min-value=1", "set", root.brightness + "%"])
    }

    Process {
        id: updateCheck
        command: [Ui.bin + "penumbra-updates", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const status = JSON.parse(text);
                    root.updates = status.count ?? 0;
                    root.updatesDetail = (status.details ?? []).join("\n");
                    root.updateSources = status.sources ?? [];
                    root.updateNews = status.news ?? [];
                    root.restartReasons = status.restart ?? [];
                } catch (e) {
                    root.updates = 0;
                    root.updateSources = [];
                }
            }
        }
    }
    function refreshUpdates() {
        updateCheck.running = true;
    }
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshUpdates()
    }
}
