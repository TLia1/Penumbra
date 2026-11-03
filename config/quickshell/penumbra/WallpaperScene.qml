import QtQuick

// Base for an animated wallpaper scene, laid out in the SVG's own coordinates. Its layers are
// PNGs and a layers.js written by tools/build-wallpapers.py into `folder`, next to this file.
Item {
    id: root
    required property string folder
    required property var layers
    property bool running: true
    // The lock screen leaves out the wordmark.
    property bool clean: false
    // Only the desktop opts in; lock-screen scenes never contain desktop widgets.
    property bool desktop: false
    // Device pixels per scene unit, so layers decode no larger than they are shown.
    property real pixelScale: 1

    // Seconds of animation; ticking at 30 Hz keeps the redraws cheap.
    property real t: 0
    Timer {
        interval: 33
        repeat: true
        running: root.running
        onTriggered: root.t += interval / 1000
    }
    function wave(period, phase = 0) {
        return Math.sin(2 * Math.PI * root.t / period + phase);
    }
}
