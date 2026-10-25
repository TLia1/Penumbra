pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polled system state: CPU, memory, backlight and pending updates.
Singleton {
    id: root

    property int cpu: 0
    property int cores: 1
    property int memory: 0
    property string memoryDetail: ""
    property int brightness: -1 // -1 when the machine has no backlight
    property int updates: 0
    property string updatesDetail: ""
    property var updateSources: [] // [{ name, packages: ["name old -> new" or a Flatpak ref] }]
    property bool checkingUpdates: updateCheck.running

    property var lastCpu: null

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            root.cores = (text().match(/^cpu\d+ /gm) ?? []).length || 1;
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root.lastCpu.idle) / dt)) : 0;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memory = Math.round(100 * used / total);
            root.memoryDetail = `${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GiB`;
        }
    }

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
                    root.updates = parseInt(status.text.replace(/\D/g, "")) || 0;
                    root.updatesDetail = status.tooltip.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
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
