import QtQuick

// The route lies on the lake, behind both banks. The boat's keel marks playback position.
Item {
    id: voyage
    required property var player
    required property real fraction
    required property bool timed
    required property real waterline
    required property real time
    required property bool stacked
    readonly property real boatWidth: Math.min(155, parent.width * 0.18, parent.height * 0.20)
    readonly property real boatHeight: boatWidth * 156 / 200
    readonly property real keel: boatHeight * 0.94
    readonly property real distance: width - boatWidth
    readonly property real boatX: boatWidth / 2 + distance * (timed ? fraction : 0.5)
    readonly property real swell: 1.4 * Math.sin(time * 0.86)
    readonly property alias seekArea: seek
    readonly property string artwork: player?.trackArtUrl ?? ""
    width: Math.min(parent.width * (stacked ? 0.72 : 0.45), 820)
    height: keel + boatHeight * 0.38
    x: stacked ? (parent.width - width) / 2 : parent.width * 0.46
    y: waterline + (parent.height - waterline) * (stacked ? 0.20 : 0.45) - keel

    // Broken crests show the course and catch more light in the boat's wake.
    Repeater {
        model: voyage.timed ? 34 : 0
        delegate: Rectangle {
            required property int index
            readonly property real progress: index / 33
            x: voyage.boatWidth / 2 + voyage.distance * progress - width / 2
            y: voyage.keel + 2.5 * Math.sin(index * 0.7) + 1.3 * Math.sin(index * 2.3 + voyage.time)
            width: Math.max(2, voyage.distance / 34 * (0.46 + 0.22 * Math.sin(index * 1.7)))
            height: 1.2
            radius: 0.6
            color: progress <= voyage.fraction ? "#f8d6bb" : "#e0ccdb"
            opacity: progress <= voyage.fraction ? 0.8 : 0.36
        }
    }

    // Thin, laterally displaced slices mirror the mainsail in the surface ripples.
    Repeater {
        model: sail.status === Image.Ready ? 9 : 0
        delegate: Item {
            required property int index
            readonly property real strip: voyage.boatHeight * 0.029
            width: voyage.boatWidth * 0.405
            height: Math.max(1, strip * (0.75 - index * 0.042))
            x: voyage.boatX - voyage.boatWidth * 0.12 + (1 + index * 0.35) * Math.sin(index * 2.1 + voyage.time * 1.1)
            y: voyage.keel + voyage.swell + voyage.boatHeight * 0.055 + index * strip
            opacity: 0.36 - index * 0.031
            clip: true
            Image {
                x: 0; y: -index * parent.strip
                width: parent.width; height: 9 * parent.strip
                source: sail.source
                sourceSize: sail.sourceSize
                mirrorVertically: true
                fillMode: Image.Stretch
                asynchronous: true
            }
        }
    }

    Item {
        x: voyage.boatX - width / 2
        y: voyage.swell
        width: voyage.boatWidth
        height: voyage.boatHeight
        rotation: 1.2 * Math.sin(voyage.time * 0.67)
        transformOrigin: Item.Bottom
        Image {
            anchors.fill: parent
            source: "skiff.svg"
            sourceSize: Qt.size(400, 312)
        }
        Image {
            id: sail
            x: parent.width * 72 / 200
            y: parent.height * 19 / 156
            width: parent.width * 81 / 200
            height: parent.height * 78 / 156
            source: voyage.artwork
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.94
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, 0.08, 0, 0, 0.13, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            }
        }
    }

    MouseArea {
        id: seek
        x: voyage.boatWidth / 2 - 8
        y: voyage.keel - 12
        width: voyage.distance + 16
        height: 24
        enabled: voyage.timed && !!voyage.player?.canSeek
        cursorShape: Qt.PointingHandCursor
        onClicked: event => voyage.player.position = voyage.player.length * Math.max(0, Math.min(1, (event.x - 8) / voyage.distance))
    }
}
