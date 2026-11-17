import QtQuick
import "moonwake/layers.js" as Moonwake
import "moonwake" as Lake

WallpaperScene {
    id: root
    folder: "moonwake"
    layers: Moonwake.layers
    width: Moonwake.width
    height: Moonwake.height

    Stars { scene: root; stars: Moonwake.stars; color: "#eadcef"; z: 1 }
    SceneLayer {
        scene: root; name: "cirrus"; z: 2
        x: info.x + 18 * root.wave(83)
    }
    DesktopDepth {
        id: depth
        z: 3
        active: root.desktop && !root.clean
        running: root.running
        radialAura: false
        center: Qt.point(1280, 628)
        orbitRadius: 0
        clockY: 520
        clockSize: 168
        clockInk: "#f9e9e8"
        dateInk: "#f1dce6"
    }
    SceneLayer { scene: root; name: "massif"; z: 4 }
    SceneLayer {
        scene: root; name: "haze"; z: 5
        opacity: 0.88 + 0.12 * root.wave(31)
    }
    SceneLayer { scene: root; name: "foothills"; z: 6 }
    SceneLayer { scene: root; name: "lake"; z: 7 }

    // The ambient moon path is independent of playback.
    ShaderEffect {
        y: 985.6; z: 8 // Waterline in the source art.
        width: root.width; height: root.height - y
        property real time: root.t
        fragmentShader: "moonwake/reflection.frag.qsb"
    }
    SceneLayer { scene: root; name: "shores"; z: 9 }
    Loader {
        anchors.fill: parent
        z: 10
        active: depth.live
        sourceComponent: Lake.Fireflies { time: root.t; samples: depth.samples }
    }
    SceneLayer { scene: root; name: "headland"; z: 11 }
}
