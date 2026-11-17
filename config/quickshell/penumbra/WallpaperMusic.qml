import QtQuick

// Screen-local coordinates keep the type and controls readable when the artwork is cropped.
Item {
    id: root
    required property var player
    required property var scene
    required property string lyric
    readonly property bool lake: scene?.scene === "moonwake"
    readonly property bool east: scene?.scene === "dawn"
    readonly property bool paleSky: scene?.folder === "starlight"
    readonly property color ink: paleSky ? "#302541" : lake ? "#faeee8" : "#f3edf9"
    readonly property color tint: lake ? "#edd4c6" : scene?.tint ?? "#c8adf1"
    readonly property real inset: Math.min(100, parent.width * 0.064)
    readonly property bool timed: Media.hasLength(player) && !!player?.positionSupported
    readonly property real fraction: timed ? Math.max(0, Math.min(1, player.position / player.length)) : 0
    readonly property bool stacked: lake && parent.width < 700 && parent.width < parent.height
    width: Math.min(348 * Theme.textScale, parent.width - inset * 2, Math.max(220, parent.width * 0.31))
    readonly property alias seekArea: timeline
    readonly property alias transportArea: controls
    height: body.implicitHeight + (lyric ? body.spacing + verse.implicitHeight : 0)
    x: stacked ? (parent.width - width) / 2 : east ? parent.width - inset - width : inset
    y: Math.max(60, Math.min(parent.height - height - 30,
        stacked ? parent.height * 0.92 - body.implicitHeight : lake ? parent.height * 0.85 - body.implicitHeight : parent.height * 0.50 - body.implicitHeight / 2))

    component Caption: Text {
        width: parent.width
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: root.east ? Text.AlignRight : Text.AlignLeft
        color: root.ink
        font.family: Theme.sans
        font.pixelSize: Theme.textBody
        style: Text.Raised
        styleColor: "#55322645"
    }

    Column {
        id: body
        width: root.width
        spacing: 3
        Row {
            width: parent.width
            spacing: 12
            layoutDirection: root.east ? Qt.RightToLeft : Qt.LeftToRight
            Image {
                id: cover
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(56 * Theme.textScale)
                height: width
                visible: status === Image.Ready
                source: root.lake ? "" : root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (cover.visible ? cover.width + parent.spacing : 0)
                spacing: 3
                Caption {
                    text: root.player?.trackArtist ?? ""
                    visible: text !== ""
                    font.pixelSize: Theme.textSmall
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    color: root.tint
                }
                Caption {
                    text: root.player?.trackTitle || Media.appName(root.player)
                    font.family: root.lake ? "serif" : Theme.display
                    font.pixelSize: Math.round((root.lake ? 32 : 29) * Theme.textScale)
                    font.weight: root.lake ? Font.Normal : Font.Medium
                }
            }
        }
        Item {
            id: timeline
            width: parent.width
            height: 18
            visible: root.timed && !root.lake
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2
                color: Theme.alpha(root.tint, 0.33)
                Rectangle {
                    id: elapsed
                    width: parent.width * root.fraction
                    height: parent.height
                    color: root.tint
                }
                Rectangle {
                    anchors.horizontalCenter: elapsed.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: width
                    radius: width / 2
                    color: root.ink
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!root.player?.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: event => root.player.position = root.player.length * Math.min(1, Math.max(0, event.x / width))
            }
        }
        Item {
            width: parent.width
            height: Math.max(26, stamp.implicitHeight)
            Row {
                id: controls
                x: root.east ? parent.width - width : 0
                height: parent.height
                spacing: 4
                component Transport: ActionArea {
                    required property string glyph
                    width: Math.max(24, Theme.textHeading)
                    height: controls.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Glyph {
                        anchors.centerIn: parent
                        text: parent.glyph
                        size: Theme.textLarge
                        color: parent.containsMouse ? root.ink : root.tint
                    }
                }
                Transport {
                    glyph: "󰒮"; actionName: "Previous track"
                    visible: !!root.player?.canGoPrevious
                    onTriggered: root.player?.previous()
                }
                Transport {
                    glyph: root.player?.isPlaying ? "󰏤" : "󰐊"
                    actionName: root.player?.isPlaying ? "Pause" : "Play"
                    visible: !!root.player?.canTogglePlaying
                    onTriggered: root.player?.togglePlaying()
                }
                Transport {
                    glyph: "󰒭"; actionName: "Next track"
                    visible: !!root.player?.canGoNext
                    onTriggered: root.player?.next()
                }
            }
            Caption {
                id: stamp
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: root.east ? Text.AlignLeft : Text.AlignRight
                text: root.timed ? Media.time(root.player.position) + "  /  " + Media.time(root.player.length)
                    : Media.isLive(root.player) ? "Live" : ""
                font.pixelSize: Theme.textTiny
                font.features: { "tnum": 1 }
                color: root.tint
            }
        }
    }

    Caption {
        id: verse
        anchors { top: body.bottom; topMargin: body.spacing }
        visible: text !== ""
        text: root.lyric
        maximumLineCount: 2
        wrapMode: Text.Wrap
        font.italic: root.lake
    }
}
