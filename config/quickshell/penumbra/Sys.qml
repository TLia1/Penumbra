pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polled system state: backlight and pending updates. Resource usage is in Usage.
Singleton {
    id: root

    property int brightness: -1 // -1 when the machine has no backlight
    property int updates: 0
    property string updatesDetail: ""
    property var updateSources: [] // [{ name, packages: ["name old -> new" or a Flatpak ref] }]
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
