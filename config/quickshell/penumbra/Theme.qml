pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "palette.js" as P

// PENUMBRA palette, type and geometry, shared by every shell surface.
Singleton {
    id: root

    // Colours start from palette.js, which tools/build-palette.py writes from palette/palette.toml.
    // penumbra-theme writes the chosen palette to palette.json; a new one fades in over `to`, so every
    // colour below, and every binding on them, crossfades instead of snapping.
    readonly property color base: mix("base")
    readonly property color surface: mix("surface")
    readonly property color glass: alpha(surface, level("glass"))
    readonly property color glassStrong: alpha(surface, level("glassStrong"))
    readonly property color raised: alpha(mix("glassRaised"), level("raised"))
    readonly property color hover: mix("hover")
    readonly property color line: alpha(accent, level("line"))
    readonly property color lineStrong: alpha(accent, level("lineStrong"))
    // Behind full-screen overlays (launcher, session menu, polkit, screenshots).
    readonly property color scrim: mix("shade")
    readonly property color accent: mix("accent")
    readonly property color accentBright: mix("accentBright")
    readonly property color accentDeep: mix("accentDeep")
    // Text and glyphs on an accent fill.
    readonly property color onAccent: mix("onAccent")
    readonly property color white: mix("white")
    readonly property color text: mix("text")
    readonly property color textSoft: mix("textSoft")
    readonly property color subtle: mix("subtle")
    readonly property color muted: mix("muted")
    readonly property color dim: mix("dim")
    readonly property color rose: mix("rose")
    readonly property color green: mix("green")
    readonly property color amber: mix("amber")
    // The system monitor's series.
    readonly property color blue: mix("blue")
    readonly property color pink: mix("pink")
    readonly property color cyan: mix("cyan")

    // Overlays that are white or black on dark glass and the other way round on light glass.
    // The lit top edge of glass (GlassEdge scales its strength by highlightGain).
    readonly property color highlight: mix("highlight")
    readonly property real highlightGain: level("highlightGain")
    // The soft shadow under floating surfaces.
    readonly property color shadow: alpha(mix("shadow"), level("shadowAlpha"))
    // Hover and track overlays that work on any fill.
    readonly property color overlay: alpha(mix("overlay"), level("overlayAlpha"))
    readonly property color overlayStrong: alpha(mix("overlay"), level("overlayStrongAlpha"))

    // "dark" or "light", as the palette on screen (or fading in) has it.
    readonly property string mode: to.mode
    readonly property bool light: mode === "light"
    // True while a new palette fades in; components with their own colour Behavior may skip it.
    readonly property bool fading: fade.running

    // A palette colour made translucent.
    function alpha(c, a) {
        const q = Qt.lighter(c, 1);
        return Qt.rgba(q.r, q.g, q.b, a);
    }

    // The levels the derived colours are made with, per mode: dark glass wants faint lines and white
    // light, light glass denser fills and dark overlays.
    readonly property var levels: ({
        dark: { glass: 0.72, glassStrong: 0.88, raised: 0.55, line: 0.16, lineStrong: 0.34,
                highlightGain: 1, shadowAlpha: 0.55, overlayAlpha: 0.08, overlayStrongAlpha: 0.12 },
        light: { glass: 0.78, glassStrong: 0.9, raised: 0.7, line: 0.22, lineStrong: 0.42,
                 highlightGain: 2.7, shadowAlpha: 0.18, overlayAlpha: 0.06, overlayStrongAlpha: 0.1 }
    })

    // A full palette: the given colours over the compiled-in ones, plus the mode's levels and overlays.
    function makePalette(mode, colors) {
        const m = mode === "light" ? "light" : "dark";
        const p = Object.assign({}, P.colors, colors ?? {}, levels[m]);
        p.mode = m;
        p.highlight = "#ffffff";
        p.shadow = m === "light" ? p.shade : "#000000";
        p.overlay = m === "light" ? "#000000" : "#ffffff";
        return p;
    }

    // The palette fading out, the one fading in, and how far along it is.
    property var from: makePalette("dark")
    property var to: from
    property real t: 1
    function mix(key) { return root.t >= 1 ? root.to[key] : Qt.tint(root.from[key], alpha(root.to[key], root.t)); }
    function level(key) { return root.from[key] + (root.to[key] - root.from[key]) * root.t; }

    NumberAnimation {
        id: fade
        target: root
        property: "t"
        from: 0
        to: 1
        easing.type: Easing.InOutQuad
    }

    // Fades to a palette over `duration` ms, starting from whatever is on screen now (even mid-fade).
    function show(next, duration) {
        if (duration > 0) {
            const now = {};
            for (const key in next)
                now[key] = typeof next[key] === "number" ? level(key) : key === "mode" ? root.to.mode : mix(key);
            fade.stop();
            root.from = now;
            root.to = next;
            root.t = 0;
            fade.duration = duration;
            fade.start();
        } else {
            fade.stop();
            root.from = next;
            root.to = next;
            root.t = 1;
        }
    }

    // palette.json: {"mode": "dark"|"light", "duration": ms, "colors": {name: "#rrggbb", …}}.
    // No file (or an unreadable one) means the default palette. Loading blocks and the first load
    // doesn't fade, so the very first frame already has the chosen colours.
    property string paletteSource: ""
    property bool started: false
    function load(text) {
        if (text === paletteSource)
            return;
        paletteSource = text;
        let p = null;
        try {
            p = text ? JSON.parse(text) : null;
        } catch (e) {
            console.warn("Theme: ignoring unreadable palette.json:", e);
        }
        show(makePalette(p?.mode, p?.colors), started ? p?.duration ?? slow : 0);
    }
    FileView {
        id: paletteFile
        path: Quickshell.env("HOME") + "/.local/state/penumbra/palette.json"
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root.load(text())
        onLoadFailed: root.load("")
    }
    Component.onCompleted: {
        load(paletteFile.text());
        started = true;
    }

    readonly property string sans: "Inter"
    // Inter's optical size for large text: tighter spacing and finer detail from about 20 px up.
    readonly property string display: "Inter Display"
    readonly property string mono: "JetBrainsMono Nerd Font"
    // The distribution's logo on the bar's launcher button, set by install.sh from distro/NAME/distro.sh.
    readonly property string distroGlyph: "@@DISTRO_GLYPH@@"

    // The type scale. Every text size in the shell is one of these.
    readonly property int textTiny: 10     // badges, timestamps
    readonly property int textSmall: 11    // subtitles, section labels
    readonly property int textBody: 12     // the default
    readonly property int textMedium: 13   // notification titles, emphasized rows
    readonly property int textLarge: 15    // page titles, the bar clock
    readonly property int textTitle: 18    // the launcher's search, big figures
    readonly property int textHeading: 22  // panel headlines, in the display face
    readonly property int textDisplay: 124 // the lock screen clock

    // Rounded or sharp corners, as penumbra-corners records them. Every radius goes through
    // corner(), so the whole shell follows the choice at once.
    property string corners: "rounded"
    readonly property bool sharp: corners === "sharp"
    function corner(px) { return sharp ? 0 : px; }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/penumbra/corners"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.corners = text().trim() || "rounded"
    }

    readonly property int radiusLarge: corner(22)
    readonly property int radius: corner(16)
    readonly property int radiusSmall: corner(12)
    readonly property int barHeight: 40
    readonly property int gap: 8
    readonly property int edge: 14

    readonly property int fast: 160
    readonly property int normal: 260
    readonly property int slow: 420
}
