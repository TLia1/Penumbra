pragma Singleton
import QtQuick
import Quickshell

// NOCTURNE palette, type and geometry, shared by every shell surface.
Singleton {
    readonly property color base: "#0d0a12"
    readonly property color surface: "#100d18"
    readonly property color glass: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.72)
    readonly property color glassStrong: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.88)
    readonly property color raised: Qt.rgba(40 / 255, 30 / 255, 58 / 255, 0.55)
    readonly property color hover: "#38264f"
    readonly property color line: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16)
    readonly property color lineStrong: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.34)
    readonly property color violet: "#b69af7"
    readonly property color violetBright: "#c4a5ff"
    readonly property color violetDeep: "#6d28d9"
    readonly property color violetInk: "#100b1b"
    readonly property color text: "#e9e1f5"
    readonly property color textSoft: "#c8bbde"
    readonly property color muted: "#8f809f"
    readonly property color dim: "#6c627b"
    readonly property color rose: "#ef8fa4"
    readonly property color green: "#a5ccb3"
    readonly property color amber: "#e5c89a"

    readonly property string sans: "Inter"
    readonly property string mono: "JetBrainsMono Nerd Font"

    readonly property int radiusLarge: 22
    readonly property int radius: 16
    readonly property int radiusSmall: 12
    readonly property int barHeight: 40
    readonly property int gap: 8
    readonly property int edge: 14

    readonly property int fast: 160
    readonly property int normal: 260
    readonly property int slow: 420
}
