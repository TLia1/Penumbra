import QtQuick
import QtQuick.Shapes
import "eclipse/layers.js" as Eclipse

// Eclipse: the nebula drifts, stars twinkle and glint, the corona's streamers sway and shimmer,
// the diamond-ring flare breathes, two backlit moons circle the eclipse, an aurora ripples along
// the near world's horizon, a satellite blinks across the sky and the odd shooting star falls.
WallpaperScene {
    id: root
    folder: "eclipse"
    layers: Eclipse.layers
    width: Eclipse.width
    height: Eclipse.height

    // Geometry from assets/wallpaper-eclipse.svg.
    readonly property point eclipse: Qt.point(1660, 600)
    readonly property real orbitTilt: -18 * Math.PI / 180
    readonly property point world: Qt.point(380, 2950)
    readonly property real worldRadius: 1680

    SceneLayer { scene: root; name: "sky"; z: 0 }
    // Zoomed a touch so its cropped edges never come into view as it turns.
    SceneLayer {
        scene: root
        name: "nebula"
        z: 1
        opacity: (1 + 0.25 * root.wave(17)) / info.boost
        zoom: 1.05 + 0.02 * root.wave(60)
        angle: 0.8 * root.wave(80)
    }
    Stars {
        scene: root
        stars: Eclipse.stars
        color: "#ddd0f5"
        z: 2
    }
    SceneLayer {
        scene: root
        name: "halo"
        z: 3
        pivot: root.eclipse
        opacity: (1 + 0.2 * root.wave(9)) / info.boost
        zoom: 1.02 + 0.02 * root.wave(9)
    }
    // Two sets of streamers swaying against each other read as a living corona.
    SceneLayer {
        scene: root
        name: "corona"
        z: 4
        pivot: root.eclipse
        angle: 2.5 * root.wave(47)
        opacity: 0.85 + 0.15 * root.wave(6.3)
    }
    SceneLayer {
        scene: root
        name: "wisps"
        z: 5
        pivot: root.eclipse
        angle: -3.5 * root.wave(37, 1)
        zoom: 1 + 0.04 * root.wave(11)
        opacity: 0.7 + 0.3 * root.wave(5.1, 2)
    }
    SceneLayer { scene: root; name: "orbits"; z: 6 }
    SceneLayer { scene: root; name: "body"; z: 8 }
    SceneLayer {
        scene: root
        name: "limb"
        z: 9
        opacity: 0.85 + 0.15 * root.wave(4.3)
    }
    SceneLayer {
        scene: root
        name: "bead"
        z: 10
        opacity: 0.8 + 0.2 * root.wave(5.7)
        zoom: 0.85 + 0.25 * (0.5 + 0.5 * root.wave(5.7))
    }
    SceneLayer { scene: root; name: "near"; z: 11 }

    // Moons on the dotted orbits, lit from behind: a rim on the side facing the eclipse that
    // closes into a ring as they cross it. On the far side they pass behind the eclipsing body.
    component Moon: Item {
        id: moon
        required property real orbitX
        required property real orbitY
        required property real period
        required property real phase
        required property real radius
        readonly property real angle: 2 * Math.PI * root.t / period + phase
        readonly property real along: orbitX * Math.cos(angle)
        readonly property real across: orbitY * Math.sin(angle)
        readonly property real toward: Math.atan2(root.eclipse.y - y, root.eclipse.x - x) * 180 / Math.PI
        readonly property real sweep: 110 + 250 * Math.max(0, 1 - Math.hypot(root.eclipse.x - x, root.eclipse.y - y) / 520)
        x: root.eclipse.x + along * Math.cos(root.orbitTilt) - across * Math.sin(root.orbitTilt)
        y: root.eclipse.y + along * Math.sin(root.orbitTilt) + across * Math.cos(root.orbitTilt)
        z: across > 0 ? 12 : 7

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#0b0911"
                strokeColor: "#2a1d3a"
                strokeWidth: 1
                PathAngleArc { radiusX: moon.radius; radiusY: moon.radius; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#efe4ff"
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    radiusX: moon.radius
                    radiusY: moon.radius
                    startAngle: moon.toward - moon.sweep / 2
                    sweepAngle: moon.sweep
                }
            }
        }
    }
    Moon { orbitX: 360; orbitY: 92; period: 55; phase: 0.6; radius: 13 }
    Moon { orbitX: 560; orbitY: 148; period: 95; phase: 3.4; radius: 8 }

    // A satellite crosses in a minute, then the sky stays empty for a while.
    Item {
        readonly property real progress: root.t % 140 / 60
        visible: progress < 1
        z: 13
        x: -40 + 2680 * progress
        y: 230 - 170 * progress
        Rectangle {
            x: -1.3
            y: -1.3
            width: 2.6
            height: 2.6
            radius: 1.3
            color: "#d8cbe8"
            opacity: 0.6
        }
        Rectangle {
            x: -2.5
            y: -2.5
            width: 5
            height: 5
            radius: 2.5
            color: "#ef8fa4"
            visible: root.t % 1.6 < 0.1
        }
    }

    Meteor {
        z: 14
        running: root.running
        area: Qt.rect(700, 60, 800, 250)
        heading: 150
    }

    SceneLayer { scene: root; name: "world"; z: 15 }
    SceneLayer {
        scene: root
        name: "air"
        z: 16
        opacity: 0.8 + 0.2 * root.wave(8)
    }

    // Aurora along the near world's horizon (eclipse/aurora.frag).
    ShaderEffect {
        z: 17
        y: 640
        width: 1600
        height: 960
        property real time: root.t
        property size size: Qt.size(width, height)
        property point center: Qt.point(root.world.x - x, root.world.y - y)
        property real radius: root.worldRadius
        // From the left edge of the scene to where the horizon leaves its bottom edge.
        property real arcFrom: -0.21
        property real arcTo: 0.545
        fragmentShader: "eclipse/aurora.frag.qsb"
    }
}
