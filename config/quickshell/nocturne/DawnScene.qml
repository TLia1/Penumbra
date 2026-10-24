import QtQuick
import QtQuick.Shapes
import "dawn/layers.js" as Dawn

// Dawn: stars twinkle, the glow breathes, light creeps along the planet's rim, a moonlet rides
// the ring and a shooting star crosses now and then.
WallpaperScene {
    id: root
    folder: "dawn"
    layers: Dawn.layers
    width: Dawn.width
    height: Dawn.height

    // Ring geometry from assets/wallpaper-dawn.svg.
    readonly property point planet: Qt.point(820, 1010)
    readonly property real ringX: 760
    readonly property real ringY: 172
    readonly property real ringTilt: 16 * Math.PI / 180

    SceneLayer { scene: root; name: "sky"; z: 0 }
    // Rendered brighter than the still image, so it can swell and ebb around it.
    SceneLayer {
        scene: root
        name: "glow"
        z: 1
        opacity: (1 + 0.3 * root.wave(11)) / info.boost
    }
    Stars {
        scene: root
        stars: Dawn.stars
        z: 2
    }
    SceneLayer { scene: root; name: "back"; z: 3 }
    SceneLayer { scene: root; name: "planet"; z: 5 }
    SceneLayer {
        scene: root
        name: "rim"
        z: 6
        opacity: 0.85 + 0.15 * root.wave(7, 1)
        pivot: root.planet
        angle: 3 * root.wave(23)
    }
    SceneLayer { scene: root; name: "front"; z: 7 }

    // A moonlet on the ring: behind the planet on the far side, brightest where the ring is lit.
    Item {
        readonly property real angle: 2 * Math.PI * root.t / 80 + 2.2
        readonly property real along: root.ringX * Math.cos(angle)
        readonly property real across: root.ringY * Math.sin(angle)
        x: root.planet.x + along * Math.cos(root.ringTilt) - across * Math.sin(root.ringTilt)
        y: root.planet.y + along * Math.sin(root.ringTilt) + across * Math.cos(root.ringTilt)
        z: across > 0 ? 8 : 4
        scale: 0.85 + 0.15 * Math.sin(angle)
        opacity: Math.max(0.2, 1 - Math.abs(Math.cos(angle)))

        Shape {
            x: -24
            y: -24
            width: 48
            height: 48
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 24; centerY: 24; focalX: 24; focalY: 24
                    centerRadius: 24
                    GradientStop { position: 0; color: Qt.rgba(243 / 255, 180 / 255, 214 / 255, 0.55) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc { centerX: 24; centerY: 24; radiusX: 24; radiusY: 24; sweepAngle: 360 }
            }
        }
        Rectangle {
            x: -2.5
            y: -2.5
            width: 5
            height: 5
            radius: 2.5
            color: "#ffe3f1"
        }
    }

    // Shooting stars cross the open sky to the right.
    Meteor {
        z: 9
        running: root.running
        area: Qt.rect(1700, 80, 700, 300)
    }
}
