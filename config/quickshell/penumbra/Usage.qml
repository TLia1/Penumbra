pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resource usage: CPU, memory, GPUs, disks and network, with two minutes of history for the
// monitor's graphs. The /proc counters are cheap and always read, so the graphs already have a
// past when the monitor opens; temperatures, clocks, GPUs and filesystems are only read while
// it is open.
Singleton {
    id: root

    readonly property int interval: 2000
    readonly property int historyLength: 60
    readonly property bool watching: Ui.monitorOpen

    property int cpu: 0
    property int cores: 1
    property var coreLoads: [] // percent, one per thread
    property string cpuModel: ""
    property real cpuGhz: 0
    property int cpuTemp: -1
    property string loadAverage: ""
    property var cpuHistory: []

    // KiB, as /proc/meminfo counts.
    property int memory: 0
    property real memoryUsed: 0
    property real memoryCache: 0 // page cache the kernel gives back when asked
    property real memoryTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property string memoryDetail: ""
    property var memoryHistory: []

    // Bytes per second across the physical disks, and bytes for filesystems.
    property real diskRead: 0
    property real diskWrite: 0
    property var diskHistory: []
    property var filesystems: [] // [{ name, mount, used, size }]

    // The interface with the default route; bytes per second, and bytes since it came up.
    property string netInterface: ""
    property real netDown: 0
    property real netUp: 0
    property real netReceived: 0
    property real netSent: 0
    property var downHistory: []
    property var upHistory: []

    // [{ card, driver, name, integrated, asleep, busy, memUsed, memTotal, temp, power, freq, maxFreq, history }]
    // Memory in MiB, temperature in °C, power in W, clocks in MHz; -1 where the driver says nothing.
    property var gpus: []

    // Previous counters, for rates.
    property var lastCpu: null
    property var lastCores: []
    property var lastDisk: null
    property var lastNet: null
    property var lastGpu: ({})
    property string cpuTempPath: ""

    function push(list, value) {
        return list.concat([value]).slice(-historyLength);
    }

    Timer {
        interval: root.interval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            route.reload();
            netdev.reload();
            diskstats.reload();
            if (root.watching)
                root.readDetails();
        }
    }
    function readDetails() {
        cpuinfo.reload();
        loadavg.reload();
        if (cpuTempPath)
            cpuTemp.reload();
        if (gpus.length && !gpuSample.running)
            gpuSample.running = true;
    }
    // Filesystems change rarely; ask on opening, then every half minute. Intel's GPU busy time
    // is a difference between samples, so a stale sample from the last opening is dropped.
    onWatchingChanged: {
        lastGpu = {};
        if (watching) {
            readDetails();
            df.running = true;
        }
    }
    Timer {
        interval: 30000
        running: root.watching
        repeat: true
        onTriggered: df.running = true
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const lines = text().split("\n").filter(l => l.startsWith("cpu"));
            const times = lines.map(l => {
                const f = l.trim().split(/\s+/).slice(1).map(Number);
                return { idle: f[3] + f[4], total: f.reduce((a, b) => a + b, 0) };
            });
            const busy = (now, before) => {
                const dt = now.total - before.total;
                return dt > 0 ? Math.max(0, Math.min(100, 100 * (1 - (now.idle - before.idle) / dt))) : 0;
            };
            root.cores = times.length - 1 || 1;
            if (root.lastCpu) {
                root.cpu = Math.round(busy(times[0], root.lastCpu));
                root.cpuHistory = root.push(root.cpuHistory, root.cpu);
            }
            if (root.lastCores.length === times.length - 1)
                root.coreLoads = times.slice(1).map((t, i) => busy(t, root.lastCores[i]));
            root.lastCpu = times[0];
            root.lastCores = times.slice(1);
        }
    }

    FileView {
        id: cpuinfo
        path: "/proc/cpuinfo"
        onLoaded: {
            const mhz = (text().match(/^cpu MHz\s*:\s*([\d.]+)/gm) ?? []).map(l => Number(l.split(":")[1]));
            root.cpuGhz = mhz.length ? mhz.reduce((a, b) => a + b, 0) / mhz.length / 1000 : 0;
            if (!root.cpuModel) {
                const model = text().match(/^model name\s*:\s*(.+)$/m)?.[1] ?? "";
                root.cpuModel = model.replace(/\((R|TM)\)/g, "").replace(/ CPU @.*$| \d+-Core Processor$/, "").replace(/\s+/g, " ").trim();
            }
        }
    }

    FileView {
        id: loadavg
        path: "/proc/loadavg"
        onLoaded: root.loadAverage = text().split(" ")[0]
    }

    // The package sensor: coretemp on Intel, k10temp or zenpower on AMD.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in coretemp|k10temp|zenpower|cpu_thermal) echo $h/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTempPath = text.trim()
        }
    }
    FileView {
        id: cpuTemp
        path: root.cpuTempPath
        printErrors: false
        onLoaded: root.cpuTemp = Math.round(Number(text()) / 1000)
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp("^" + key + ":\\s+(\\d+)", "m"))?.[1] ?? 0);
            const total = kb("MemTotal"), available = kb("MemAvailable"), used = total - available;
            root.memoryTotal = total;
            root.memoryUsed = used;
            root.memoryCache = Math.max(0, available - kb("MemFree"));
            root.swapTotal = kb("SwapTotal");
            root.swapUsed = root.swapTotal - kb("SwapFree");
            root.memory = Math.round(100 * used / total);
            root.memoryDetail = `${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GiB`;
            root.memoryHistory = root.push(root.memoryHistory, 100 * used / total);
        }
    }

    // Whole disks only: partitions would count the same bytes twice, and zram is memory.
    FileView {
        id: diskstats
        path: "/proc/diskstats"
        onLoaded: {
            let read = 0, written = 0;
            for (const line of text().split("\n")) {
                const f = line.trim().split(/\s+/);
                if (/^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+|mmcblk\d+)$/.test(f[2] ?? "")) {
                    read += Number(f[5]) * 512;
                    written += Number(f[9]) * 512;
                }
            }
            const now = Date.now(), last = root.lastDisk;
            if (last) {
                const dt = (now - last.time) / 1000;
                root.diskRead = Math.max(0, (read - last.read) / dt);
                root.diskWrite = Math.max(0, (written - last.written) / dt);
                root.diskHistory = root.push(root.diskHistory, root.diskRead + root.diskWrite);
            }
            root.lastDisk = { read, written, time: now };
        }
    }

    Process {
        id: df
        command: ["env", "LC_ALL=C", "df", "--local", "-B1", "--output=source,size,used,target"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Btrfs subvolumes and bind mounts list one device several times; keep its
                // shortest mount point. Boot partitions are not worth a row.
                const found = {};
                for (const line of text.trim().split("\n").slice(1)) {
                    const m = line.match(/^(\/dev\/\S+)\s+(\d+)\s+(\d+)\s+(.+)$/);
                    if (!m || /^\/(boot|efi)(\/|$)/.test(m[4]))
                        continue;
                    if (!found[m[1]] || m[4].length < found[m[1]].mount.length)
                        found[m[1]] = { mount: m[4], size: Number(m[2]), used: Number(m[3]) };
                }
                root.filesystems = Object.values(found).sort((a, b) => a.mount.length - b.mount.length).map(f => Object.assign(f, {
                    name: f.mount === "/" ? "System" : f.mount === "/home" ? "Home" : f.mount.split("/").pop()
                }));
            }
        }
    }

    // The default route's interface: Destination 00000000, lowest metric.
    FileView {
        id: route
        path: "/proc/net/route"
        onLoaded: {
            const routes = text().trim().split("\n").slice(1).map(l => l.trim().split(/\s+/)).filter(f => f[1] === "00000000");
            routes.sort((a, b) => Number(a[6]) - Number(b[6]));
            root.netInterface = routes[0]?.[0] ?? "";
        }
    }
    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const [name, rest] = line.split(":");
                const iface = name?.trim(), f = rest?.trim().split(/\s+/).map(Number);
                if (!f || iface === "lo" || (root.netInterface && iface !== root.netInterface))
                    continue;
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now(), last = root.lastNet;
            root.netReceived = rx;
            root.netSent = tx;
            // A new interface starts from its own counters; skip the jump between them.
            if (last && last.iface === root.netInterface) {
                const dt = (now - last.time) / 1000;
                root.netDown = Math.max(0, (rx - last.rx) / dt);
                root.netUp = Math.max(0, (tx - last.tx) / dt);
            } else {
                root.netDown = root.netUp = 0;
            }
            if (last) {
                root.downHistory = root.push(root.downHistory, root.netDown);
                root.upHistory = root.push(root.upHistory, root.netUp);
            }
            root.lastNet = { rx, tx, time: now, iface: root.netInterface };
        }
    }

    // GPUs come from bin/penumbra-gpus, which never wakes a sleeping one.
    Process {
        running: true
        command: [Ui.bin + "penumbra-gpus", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpus = text.trim().split("\n").filter(l => l).map(line => {
                    const [card, driver, model] = line.split("\t");
                    // "AD107M [GeForce RTX 4060 Max-Q / Mobile]" → "GeForce RTX 4060 Max-Q"
                    const name = (model?.match(/\[(.+)\]/)?.[1] ?? model ?? "").split(" / ")[0].trim();
                    return {
                        card, driver,
                        name: name || "Graphics",
                        integrated: driver === "i915" || driver === "xe",
                        asleep: false, busy: -1, memUsed: -1, memTotal: -1, temp: -1, power: -1, freq: -1, maxFreq: -1,
                        history: []
                    };
                });
            }
        }
    }
    Process {
        id: gpuSample
        command: [Ui.bin + "penumbra-gpus", "sample"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const now = Number(lines[0]?.split(" ")[1]) * 1000;
                const readings = {};
                for (const line of lines.slice(1)) {
                    const [card, ...pairs] = line.split("\t");
                    readings[card] = {};
                    for (const pair of pairs) {
                        const at = pair.indexOf("=");
                        readings[card][pair.slice(0, at)] = pair.slice(at + 1);
                    }
                }
                const seen = {};
                root.gpus = root.gpus.map(gpu => {
                    const r = readings[gpu.card];
                    if (!r)
                        return gpu;
                    const num = key => r[key] === undefined || r[key] === "" || isNaN(Number(r[key])) ? -1 : Number(r[key]);
                    let busy = num("busy");
                    // Intel counts the time spent idle (RC6); busy is the rest.
                    if (num("idle_ms") >= 0) {
                        const before = root.lastGpu[gpu.card];
                        busy = before && now > before.now ? Math.max(0, Math.min(100, 100 * (1 - (num("idle_ms") - before.idle) / (now - before.now)))) : -1;
                        seen[gpu.card] = { idle: num("idle_ms"), now };
                    }
                    const asleep = r.state === "asleep";
                    return Object.assign({}, gpu, {
                        asleep,
                        busy: asleep ? -1 : busy,
                        memUsed: num("mem_used"), memTotal: num("mem_total"),
                        temp: num("temp"), power: num("power"),
                        freq: num("freq"), maxFreq: num("max_freq"),
                        history: busy >= 0 || asleep ? root.push(gpu.history, Math.max(0, busy)) : gpu.history
                    });
                });
                root.lastGpu = seen;
            }
        }
    }
}
