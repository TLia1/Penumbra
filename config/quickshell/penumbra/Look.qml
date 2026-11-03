pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "oklch.js" as Oklch
import "sun.js" as Sun

// The theme choice penumbra-theme keeps in ~/.local/state/penumbra/theme.json: dark, light or auto
// (light from sunrise to sunset), and the accent (Penumbra's, your own, or one of the wallpaper's).
// A change shows here at once;
// penumbra-theme saves and applies it (palette.json, which Theme fades to, then every app's
// colours), and the file, read back, has the last word.
Singleton {
    id: root

    property var choice: ({ mode: "dark", colors: "default", hue: 297, vividness: 1, pick: 0, harmonize: false, auto: "dark" })
    // "dark" or "light": the mode, or what auto mode shows now.
    readonly property string mode: choice.mode === "auto" ? (choice.auto === "light" ? "light" : "dark") : choice.mode
    // The accents penumbra-theme found in the current wallpaper, the strongest first: [{ hue, vividness }].
    property var candidates: []
    property var presets: []
    // The one colors=wallpaper uses, or null when the wallpaper has none (the default accent then).
    readonly property var wallpaperAccent: candidates.length ? candidates[Math.min(choice.pick ?? 0, candidates.length - 1)] : null
    property string error: ""
    readonly property bool busy: setter.running

    // "Dark · Default colours · Rounded", for the Settings row.
    readonly property string summary: [({ light: "Light", auto: "Auto" })[choice.mode] ?? "Dark",
        presets.find(p => p.id === choice.preset)?.title ?? ({ custom: "Custom colours", wallpaper: "Wallpaper colours" })[choice.colors] ?? "Default colours",
        Theme.sharp ? "Sharp" : "Rounded"].join(" · ")

    // Change some: { mode: "light" }, faded in over `duration` ms (penumbra-theme's own when
    // left out). `error` says why when one is refused.
    function set(changes, duration) {
        pending = Object.assign({}, pending, changes);
        pendingDuration = duration ?? -1;
        choice = Object.assign({}, choice, changes);
        if (!setter.running)
            flush();
    }
    property var pending: ({})
    property int pendingDuration: -1
    function flush() {
        const changes = pending;
        pending = {};
        const keys = Object.keys(changes);
        if (!keys.length)
            return;
        error = "";
        setter.command = [Ui.bin + "penumbra-theme", "set"].concat(keys.map(key => `${key}=${changes[key]}`),
            pendingDuration >= 0 ? ["--duration", String(pendingDuration)] : []);
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
    // dragged); the latest one wins. Saving the choice on release replaces the preview.
    function preview(changes) {
        if (Object.keys(changes).some(k => ["colors", "hue", "vividness", "harmonize"].includes(k)))
            changes = Object.assign({}, changes, { preset: "" });
        previewing = Object.assign({}, choice, changes);
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
    property bool loaded: false
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
                root.presets = got.presets ?? [];
                delete got.presets;
                // A change still on its way would be undone for a moment.
                if (!setter.running && !Object.keys(root.pending).length)
                    root.choice = Object.assign({}, root.choice, got);
                root.loaded = true;
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

    // ── Auto mode ───────────────────────────────────────────────────
    // Light from sunrise to sunset where night light places you (the place typed there, or your
    // time zone's city); 07:00 to 19:00 while that is unknown. At each change the shell tells
    // penumbra-theme (auto=light or dark), which keeps it for the next login and fades slowly.
    readonly property var place: NightLight.place
    readonly property var day: {
        const sun = place ? Sun.times(Clock.date, place.latitude, place.longitude) : null;
        if (!sun)
            return { from: 7 * 60, to: 19 * 60 };
        return sun.polar ? { polar: sun.polar } : { from: sun.rise, to: sun.set };
    }
    readonly property string daylight: {
        if (day.polar)
            return day.polar === "day" ? "light" : "dark";
        return Sun.between(Clock.date.getHours() * 60 + Clock.date.getMinutes(), day.from, day.to) ? "light" : "dark";
    }
    // "Light until 19:42 · sunrise and sunset in Paris", for the Look page.
    readonly property string autoStatus: {
        const where = place ? `sunrise and sunset in ${place.name}` : "07:00 to 19:00 until night light knows where you are";
        if (day.polar)
            return `${daylight === "light" ? "Light" : "Dark"} all day · ${where}`;
        return `${daylight === "light" ? "Light" : "Dark"} until ${Sun.clock(daylight === "light" ? day.to : day.from)} · ${where}`;
    }
    function followDaylight() {
        if (ready && choice.mode === "auto" && choice.auto !== daylight)
            set({ auto: daylight }, 2000);
    }
    onDaylightChanged: followDaylight()
    onChoiceChanged: followDaylight()
    // The saved choice, and the place (night light's settings and its list of cities), load just
    // after the shell starts; until then the time of day isn't known.
    property bool ready: false
    Timer {
        interval: 1500
        running: root.loaded
        onTriggered: {
            root.ready = true;
            root.followDaylight();
        }
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
