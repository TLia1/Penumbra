pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "oklch.js" as Oklch

// The theme choice penumbra-theme keeps in ~/.local/state/penumbra/theme.json: dark or light, and
// the accent (Penumbra's, your own, or one of the wallpaper's). A change shows here at once;
// penumbra-theme saves and applies it (palette.json, which Theme fades to, then every app's
// colours), and the file, read back, has the last word.
Singleton {
    id: root

    property var choice: ({ mode: "dark", colors: "default", hue: 297, vividness: 1, pick: 0 })
    // The accents penumbra-theme found in the current wallpaper, the strongest first: [{ hue, vividness }].
    property var candidates: []
    // The one colors=wallpaper uses, or null when the wallpaper has none (the default accent then).
    readonly property var wallpaperAccent: candidates.length ? candidates[Math.min(choice.pick ?? 0, candidates.length - 1)] : null
    property string error: ""
    readonly property bool busy: setter.running

    // "Dark · Default colours · Rounded", for the Settings row.
    readonly property string summary: [choice.mode === "light" ? "Light" : "Dark",
        ({ custom: "Custom colours", wallpaper: "Wallpaper colours" })[choice.colors] ?? "Default colours",
        Theme.sharp ? "Sharp" : "Rounded"].join(" · ")

    // Change some: { mode: "light" }. `error` says why when one is refused.
    function set(changes) {
        pending = Object.assign({}, pending, changes);
        choice = Object.assign({}, choice, changes);
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
        setter.command = [Ui.bin + "penumbra-theme", "set"].concat(keys.map(key => `${key}=${changes[key]}`));
        setter.running = true;
    }
    Process {
        id: setter
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
        onExited: {
            root.flush();
            if (!setter.running)
                root.refresh();
        }
    }

    // Show a choice in the shell only, without saving it or touching the apps (while a slider is
    // dragged); the latest one wins. endPreview() shows the saved choice again.
    function preview(changes) {
        previewing = Object.assign({}, choice, changes);
        if (!previewer.running)
            showPreview();
    }
    function endPreview() {
        previewing = {};
        if (!previewer.running)
            showPreview();
    }
    property var previewing: null
    function showPreview() {
        if (previewing === null)
            return;
        const shown = previewing;
        previewing = null;
        previewer.command = [Ui.bin + "penumbra-theme", "preview"].concat(Object.keys(shown).map(key => `${key}=${shown[key]}`));
        previewer.running = true;
    }
    Process {
        id: previewer
        onExited: root.showPreview()
    }

    // The saved choice with its defaults filled in, and the wallpaper's accents, whenever the file
    // or the wallpaper changes.
    function refresh() {
        if (getter.running)
            stale = true;
        else
            getter.running = true;
    }
    property bool stale: false
    Process {
        id: getter
        running: true
        command: [Ui.bin + "penumbra-theme", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                let got;
                try {
                    got = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.candidates = got.candidates ?? [];
                delete got.candidates;
                // A change still on its way would be undone for a moment.
                if (!setter.running && !Object.keys(root.pending).length)
                    root.choice = got;
            }
        }
        onExited: {
            if (root.stale) {
                root.stale = false;
                getter.running = true;
            }
        }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/penumbra/theme.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }
    Connections {
        target: Ui
        function onWallpaperChanged() { root.refresh(); }
    }

    // The default accent family's OKLCH in each mode (palette.toml's accentDeep, accent, accentBright);
    // a custom accent turns their hues and scales their chroma, as penumbra-theme does.
    readonly property var accents: ({
        dark: [[0.491, 0.241, 292.6], [0.747, 0.134, 296.9], [0.783, 0.129, 299.3]],
        light: [[0.420, 0.200, 292.8], [0.520, 0.170, 296.8], [0.450, 0.170, 299.3]]
    })
    // [deep, accent, bright] for a choice, close to what penumbra-theme will make of it. The
    // wallpaper's colours take their hue and vividness from wallpaperAccent.
    function swatches(mode, colors, hue, vividness) {
        if (colors === "wallpaper")
            return wallpaperAccent ? swatches(mode, "custom", wallpaperAccent.hue, wallpaperAccent.vividness) : swatches(mode, "default");
        const turn = colors === "custom" ? hue - 297 : 0;
        const scale = colors === "custom" ? vividness : 1;
        return accents[mode === "light" ? "light" : "dark"].map(([L, C, H]) => Oklch.color(L, Math.max(C * scale, 0.02), (H + turn + 360) % 360));
    }
}
