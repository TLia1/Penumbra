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
    width: Math.min(348 * Theme.textScale, parent.width - inset * 2,
        stacked ? parent.width * 0.84 : Math.max(220, parent.width * 0.31))
    readonly property alias seekArea: timeline
    readonly property alias transportArea: controls
    height: body.implicitHeight + (verse.text ? body.spacing + verse.implicitHeight : 0)
    x: stacked ? (parent.width - width) / 2 : east ? parent.width - inset - width : inset
    y: Math.max(60, Math.min(parent.height - height - 30,
        lake ? parent.height * (stacked ? 0.89 : 0.86) - body.implicitHeight : parent.height * 0.50 - body.implicitHeight / 2))

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

    // Portrait crops bring the bright middle of the lake directly behind the lettering.
    Rectangle {
        visible: root.stacked
        x: -root.x
        y: -50
        width: root.parent.width
        height: root.parent.height - root.y - y
        gradient: Gradient {
            GradientStop { position: 0; color: "#001b1527" }
            GradientStop { position: 0.34; color: "#941b1527" }
            GradientStop { position: 1; color: "#bd171320" }
        }
    }

    Column {
        id: body
        width: root.width
        spacing: root.lake ? 5 : 3
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
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                Rectangle {
                    anchors.fill: parent
                    visible: root.lake
                    color: "transparent"
                    border.color: Theme.alpha(root.tint, 0.4)
                }
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
                    font.capitalization: root.lake ? Font.AllUppercase : Font.MixedCase
                    color: root.tint
                }
                Caption {
                    id: title
                    text: root.player?.trackTitle || Media.appName(root.player)
                    font.family: root.lake ? "Noto Serif" : Theme.display
                    font.pixelSize: Math.round((root.lake ? 32 : 29) * Theme.textScale)
                    font.weight: root.lake ? Font.Normal : Font.Medium
                }
            }
        }
        Item {
            id: timeline
            width: parent.width
            height: root.lake ? 22 : 18
            visible: root.timed
            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - (root.lake ? 8 : 0)
                height: root.lake ? 1 : 2
                color: Theme.alpha(root.tint, 0.33)
                Rectangle {
                    id: elapsed
                    width: parent.width * root.fraction
                    anchors.verticalCenter: parent.verticalCenter
                    height: root.lake ? 2 : parent.height
                    color: root.tint
                    gradient: root.lake ? moonlight : null
                    Gradient {
                        id: moonlight
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#bba1c9" }
                        GradientStop { position: 1; color: "#ffe3c8" }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: elapsed.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.lake ? 7 : 5
                    height: width
                    radius: root.lake ? 1 : width / 2
                    rotation: root.lake ? 45 : 0
                    color: root.ink
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.lake
                        width: 12; height: width
                        color: "transparent"
                        border.color: Theme.alpha(root.tint, 0.48)
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!root.player?.canSeek
                cursorShape: Qt.PointingHandCursor
                onClicked: event => {
                    const fraction = (event.x - track.x) / track.width;
                    root.player.position = root.player.length * Math.min(1, Math.max(0, fraction));
                }
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
        text: root.lake ? "" : root.lyric
        visible: text !== ""
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }

    Loader {
        id: lakeVerse
        active: root.lake && root.lyric !== "" && root.enabled
        readonly property real screenWidth: root.parent.width
        readonly property real screenHeight: root.parent.height
        readonly property real leftBank: root.stacked ? root.inset : root.x + root.width + 12
        width: Math.max(0, Math.min(620 * Theme.textScale, screenWidth - leftBank - root.inset,
            Math.max(Math.min(280 * Theme.textScale, screenWidth * 0.4), screenWidth - 2 * leftBank)))
        x: Math.max(leftBank, (screenWidth - width) / 2) - root.x
        // The art uses a centered cover crop. Follow its waterline even on ultrawide outputs.
        readonly property real waterline: screenHeight / 2 + (985.6 - 800) * Math.max(screenWidth / 2560, screenHeight / 1600)
        readonly property real nearBank: root.stacked ? root.y : screenHeight
        y: waterline + (nearBank - waterline) * 0.45 - height / 2 - root.y - 20
        sourceComponent: MoonwakeLyrics {
            text: root.lyric
            family: title.font.family
            ink: root.ink
            pixelSize: Math.round(Math.min(30, Math.max(18, lakeVerse.screenWidth * 0.016)) * Theme.textScale)
        }
    }
}
