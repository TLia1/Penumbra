import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Capsule {
    id: root
    readonly property bool hasArtwork: cover.status === Image.Ready
    shown: !!Media.player
    padding: 12
    spacing: 10
    // The player can disappear during the exit animation.
    onClicked: m => {
        if (m.button === Qt.MiddleButton) Media.player?.togglePlaying();
        else if (Media.player) popup.active = !popup.active;
    }
    onScrolled: step => step > 0 ? Media.player?.previous() : Media.player?.next()

    onShownChanged: if (!shown) popup.active = false
    property LazyLoader popup: LazyLoader {
        id: popupLoader
        source: "MediaPopover.qml"
        onItemChanged: if (item) {
            item.anchor.item = root;
            item.visible = true;
        }
        property Connections closed: Connections {
            target: popupLoader.item
            function onVisibleChanged() { if (target && !target.visible) popupLoader.active = false; }
        }
    }
    ClippingRectangle {
        implicitWidth: 24
        implicitHeight: 24
        radius: Theme.corner(6)
        color: Theme.raised
        MediaCover {
            id: cover
            anchors.fill: parent
            player: Media.player
            sourceSize: Qt.size(48, 48)
        }
        Glyph {
            anchors.centerIn: parent
            visible: !root.hasArtwork
            text: "󰎆"
            size: 15
            color: Theme.accentBright
        }
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
