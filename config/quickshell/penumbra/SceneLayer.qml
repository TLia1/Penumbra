import QtQuick

// One pre-rendered layer of a scene, placed where tools/build-wallpapers.py cropped it.
// `angle` turns it and `zoom` scales it around `pivot`, in scene coordinates.
Image {
    id: root
    required property WallpaperScene scene
    required property string name
    readonly property var info: scene.layers.find(layer => layer.name === name)
    property point pivot: Qt.point(info.x + info.width / 2, info.y + info.height / 2)
    property real angle: 0
    property real zoom: 1

    x: info.x
    y: info.y
    width: info.width
    height: info.height
    source: scene.folder + "/" + name + ".png"
    sourceSize: Qt.size(Math.ceil(info.width * scene.pixelScale), Math.ceil(info.height * scene.pixelScale))
    smooth: true
    transform: [
        Scale {
            origin.x: root.pivot.x - root.x
            origin.y: root.pivot.y - root.y
            xScale: root.zoom
            yScale: root.zoom
        },
        Rotation {
            origin.x: root.pivot.x - root.x
            origin.y: root.pivot.y - root.y
            angle: root.angle
        }
    ]
}
