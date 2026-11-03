import QtQuick
import Quickshell
import Quickshell.Widgets

// Desktop entries can name a themed icon, an absolute file, or an image URL.
// Keep the logo's aspect ratio and a single, centered fallback across all app surfaces.
IconImage {
    id: root
    property string icon: ""
    property string fallbackGlyph: "󰣆"
    implicitSize: 32
    source: !icon ? "" : icon.startsWith("/") ? "file://" + encodeURI(icon).replace(/#/g, "%23").replace(/\?/g, "%3F")
        : icon.includes("://") ? icon : Quickshell.iconPath(icon, true)
    asynchronous: true
    Glyph {
        anchors.centerIn: parent
        visible: root.status !== Image.Ready
        text: root.fallbackGlyph
        size: Math.min(root.width, root.height) * 0.8
        color: Theme.textSoft
    }
}
