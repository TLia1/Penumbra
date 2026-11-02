import QtQuick

// The lit top edge of a glass surface: a hairline bright at the top that fades out halfway down,
// over the surface's own border. It is what makes frosted glass read as glass. Fill the surface.
// One shader pass (shaders/glass-edge.frag): every bar capsule has one, so no layer or mask.
ShaderEffect {
    id: root

    property real radius: 0
    property real strength: 0.22

    anchors.fill: parent
    visible: strength > 0 && width > 0 && height > 0

    property size size: Qt.size(width, height)
    readonly property real edge: Math.min(1, strength * Theme.highlightGain)
    // Passed opaque, with the alpha apart, since the shader gets colours premultiplied.
    readonly property color tint: Qt.rgba(Theme.highlight.r, Theme.highlight.g, Theme.highlight.b, 1)
    fragmentShader: "shaders/glass-edge.frag.qsb"
}
