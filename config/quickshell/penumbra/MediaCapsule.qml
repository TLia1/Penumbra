import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Capsule {
    id: root
    property real titleWidth: 140
    shown: !!Media.playing
    padding: 12
    spacing: 10
    tip: Media.player ? [Media.player.trackTitle, Media.player.trackArtist].filter(t => t).join(" · ") + "\nMiddle-click to pause · scroll to skip" : ""
    // The player can disappear during the exit animation.
    onClicked: m => m.button === Qt.MiddleButton ? Media.player?.togglePlaying() : Ui.toggle("control")
    onScrolled: step => step > 0 ? Media.player?.previous() : Media.player?.next()

    ClippingRectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.corner(6)
        color: Theme.raised
        Image {
            id: cover
            anchors.fill: parent
            source: Media.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(48, 48)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Glyph {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰎆"
            size: 15
            color: Theme.accentBright
        }
    }
    Label {
        visible: root.titleWidth >= 40
        Layout.maximumWidth: root.titleWidth
        text: Media.player?.trackTitle || Media.appName(Media.player)
        font.weight: Font.DemiBold
        color: Theme.textSoft
    }
    Row {
        visible: Ui.hasVisualizer
        spacing: 2
        Layout.preferredHeight: 18
        Repeater {
            model: Media.count
            delegate: Rectangle {
                required property int index
                anchors.verticalCenter: parent?.verticalCenter
                width: 3
                height: 5 + (Media.bars[index] ?? 0) * 13
                radius: Theme.corner(1.5)
                color: Theme.accentBright
                Behavior on height { NumberAnimation { duration: 60 * Theme.motion } }
            }
        }
    }
}
