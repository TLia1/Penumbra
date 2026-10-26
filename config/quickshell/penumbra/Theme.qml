pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "palette.js" as P

// PENUMBRA palette, type and geometry, shared by every shell surface.
Singleton {
    id: root

    // Colours come from palette.js, which tools/build-palette.py writes from palette/palette.toml.
    readonly property color base: P.base
    readonly property color surface: P.surface
    readonly property color glass: alpha(P.surface, 0.72)
    readonly property color glassStrong: alpha(P.surface, 0.88)
    readonly property color raised: alpha(P.glassRaised, 0.55)
    readonly property color hover: P.hover
    readonly property color line: alpha(P.violet, 0.16)
    readonly property color lineStrong: alpha(P.violet, 0.34)
    // Behind full-screen overlays (launcher, session menu, polkit, screenshots).
    readonly property color scrim: P.shade
    readonly property color violet: P.violet
    readonly property color violetBright: P.violetBright
    readonly property color violetDeep: P.violetDeep
    readonly property color violetInk: P.violetInk
    readonly property color white: P.white
    readonly property color text: P.text
    readonly property color textSoft: P.textSoft
    readonly property color subtle: P.subtle
    readonly property color muted: P.muted
    readonly property color dim: P.dim
    readonly property color rose: P.rose
    readonly property color green: P.green
    readonly property color amber: P.amber
    // The system monitor's series.
    readonly property color blue: P.blue
    readonly property color pink: P.pink
    readonly property color cyan: P.cyan

    // A palette colour made translucent.
    function alpha(c, a) {
        const q = Qt.lighter(c, 1);
        return Qt.rgba(q.r, q.g, q.b, a);
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
