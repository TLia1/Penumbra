import QtQuick

// A scene's stars, each twinkling on its own rhythm; glint stars flash a four-point sparkle at their brightest.
Item {
    id: root
    required property WallpaperScene scene
    required property var stars
    property color color: "#e9c8f2"

    Repeater {
        model: root.stars

        delegate: Item {
            id: star
            required property var modelData
            required property int index
            readonly property real twinkle: 0.8 + 0.45 * root.scene.wave(3.5 + index * 0.73 % 4, index * 2.4)
            readonly property real flash: Math.max(0, twinkle - 0.85) / 0.4
            x: modelData.x
            y: modelData.y

            Rectangle {
                x: -width / 2
                y: -height / 2
                width: star.modelData.r * 2
                height: width
                radius: width / 2
                color: root.color
                opacity: star.modelData.opacity * star.twinkle
            }

            Item {
                visible: star.modelData.glint && star.flash > 0
                opacity: star.flash
                scale: 0.6 + 0.6 * star.flash
                Rectangle {
                    x: -width / 2
                    y: -height / 2
                    width: 56
                    height: 1.2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.color }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Rectangle {
                    x: -width / 2
                    y: -height / 2
                    width: 1.2
                    height: 40
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.color }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }
}
