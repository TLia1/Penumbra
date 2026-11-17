import QtQuick
import "moonwake/layers.js" as Moonwake
import "moonwake" as Lake

WallpaperScene {
    id: root
    folder: "moonwake"
    layers: Moonwake.layers
    width: Moonwake.width
    height: Moonwake.height

    property Item music: null
    property size viewport: Qt.size(width, height)
    readonly property real viewScale: Math.max(viewport.width / width, viewport.height / height)
    readonly property real waterline: 985.6
    readonly property Item voyage: waterMusic.item?.route ?? null

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
        y: root.waterline; z: 8 // Waterline in the source art.
        width: root.width; height: root.height - y
        property real time: root.t
        fragmentShader: "moonwake/reflection.frag.qsb"
    }
    Loader {
        id: waterMusic
        z: 8.5
        anchors.centerIn: parent
        width: root.viewport.width
        height: root.viewport.height
        scale: root.viewScale > 0 ? 1 / root.viewScale : 1
        active: root.desktop && !root.clean && !!root.music
        sourceComponent: Item {
            readonly property alias route: boat
            Lake.MusicVoyage {
                id: boat
                visible: (root.music?.opacity ?? 0) > 0
                player: root.music?.player ?? null
                stacked: root.music?.stacked ?? false
                timed: root.music?.timed ?? false
                fraction: root.music?.fraction ?? 0
                waterline: parent.height / 2 + (root.waterline - root.height / 2) * root.viewScale
                time: 0
                Binding on time {
                    when: boat.visible && root.running && !!boat.player?.isPlaying
                    value: root.t
                    restoreMode: Binding.RestoreNone
                }
            }
        }
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
