import QtQuick
import QtQuick.Effects

// The lit top edge of a glass surface: a hairline bright at the top that fades out halfway down,
// over the surface's own border. It is what makes frosted glass read as glass. Fill the surface.
Item {
    id: root

    property real radius: 0
    property real strength: 0.22

    anchors.fill: parent

    Rectangle {
        id: light
        anchors.fill: parent
        visible: false
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, root.strength) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
        }
    }
    Rectangle {
        id: ring
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: "white"
    }
    MultiEffect {
        anchors.fill: parent
        source: light
        maskEnabled: true
        maskSource: ring
        maskThresholdMin: 0.25
        maskSpreadAtMin: 0.25
    }
}
