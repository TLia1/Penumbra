import QtQuick

ShaderEffect {
    id: root
    anchors.fill: parent
    property real radius: 0
    property point pointer: Qt.point(width / 2, height / 2)
    property bool hovered: false
    property real glow: hovered ? 1 : 0
    Behavior on glow { NumberAnimation { duration: Theme.fast } }
    readonly property size size: Qt.size(width, height)
    readonly property color tint: Theme.accent
    readonly property color light: Theme.highlight
    fragmentShader: "shaders/card-light.frag.qsb"
    GlassEdge { radius: root.radius; strength: 0.14 }
}
