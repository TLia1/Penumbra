pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The settings install.sh asks for, kept in ~/.config/penumbra/settings.conf: keyboard, scale,
// terminal and idle timings. penumbra-settings checks, saves and applies each change, so the
// installer and the Settings pages always agree. Shell-only preferences are in Settings instead.
Singleton {
    id: root

    property var values: ({})
    property string error: ""
    readonly property bool busy: setter.running

    // Change some: { idle_lock: "15" }. `error` says why when one is refused.
    function set(changes) {
        pending = Object.assign({}, pending, changes);
        if (!setter.running)
            flush();
    }
    property var pending: ({})
    function flush() {
        const changes = pending;
        pending = {};
        const keys = Object.keys(changes);
        if (!keys.length)
            return;
        error = "";
        // Shown at once; the file, read back, has the last word.
        values = Object.assign({}, values, changes);
        setter.command = [Ui.bin + "penumbra-settings", "set"].concat(keys.map(key => `${key}=${changes[key]}`));
        setter.running = true;
    }
    Process {
        id: setter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
        onExited: {
            getter.running = true;
            root.flush();
        }
    }

    // Every setting with its default filled in, whenever the file changes.
    Process {
        id: getter
        running: true
        command: [Ui.bin + "penumbra-settings", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text);
                } catch (e) {}
            }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/penumbra/settings.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: getter.running = true
    }

    // Keyboard layouts and their variants from the XKB rules, the first time a page asks.
    property var layouts: [] // [[code, name]]
    property var variants: ({}) // layout → [[code, name]]
    function loadLayouts() {
        if (!layouts.length && !layoutList.running)
            layoutList.running = true;
    }
    Process {
        id: layoutList
        command: [Ui.bin + "penumbra-settings", "layouts"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text);
                    root.layouts = all.layouts;
                    root.variants = all.variants;
                } catch (e) {}
            }
        }
    }
    function layoutName(code) {
        return layouts.find(l => l[0] === code)?.[1] ?? code;
    }

    // Minutes, or "never", as the idle rows show them: "9 min 30 s".
    function duration(value) {
        if (value === "never" || value === undefined)
            return "Never";
        const s = Math.round(Number(value) * 60), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
        return [h ? `${h} h` : "", m ? `${m} min` : "", r ? `${r} s` : ""].filter(t => t).join(" ");
    }
}
