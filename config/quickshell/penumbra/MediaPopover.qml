import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: root
    property var player: Media.player
    property bool hovered: hover.hovered
    signal dismissed()
    implicitWidth: 340
    implicitHeight: body.implicitHeight + 32
    color: "transparent"
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 4

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        transformOrigin: Item.Top
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }
        GlassEdge { radius: parent.radius }
        HoverHandler { id: hover }
        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 10
            RowLayout {
                spacing: 12
                ClippingRectangle {
                    implicitWidth: 64; implicitHeight: 64
                    radius: Theme.radiusSmall
                    color: Theme.raised
                    Image {
                        id: art
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(128, 128)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Glyph { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰎆"; size: 26 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: root.player?.trackTitle || "Nothing playing"; font.weight: Font.Bold }
                    Label { Layout.fillWidth: true; text: root.player?.trackArtist ?? ""; color: Theme.muted }
                }
                PillButton { text: "×"; onClicked: root.dismissed() }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                PillButton { text: "󰒮"; available: root.player?.canGoPrevious ?? false; onClicked: root.player?.previous() }
                PillButton { text: root.player?.isPlaying ? "󰏤" : "󰐊"; primary: true; available: root.player?.canTogglePlaying ?? false; onClicked: root.player?.togglePlaying() }
                PillButton { text: "󰒭"; available: root.player?.canGoNext ?? false; onClicked: root.player?.next() }
                PillButton { text: "Lyrics"; primary: lyrics.active; onClicked: lyrics.active = !lyrics.active }
            }
            SliderRow {
                Layout.fillWidth: true
                visible: Media.hasLength(root.player)
                enabled: root.player?.canSeek ?? false
                glyph: "󰎆"
                to: Math.max(1, root.player?.length ?? 1)
                value: root.player?.position ?? 0
                label: Media.time(value)
                labelWidth: 45
                onMoved: value => { if (root.player?.canSeek) root.player.position = value; }
            }
            LyricsView {
                id: lyrics
                Layout.fillWidth: true
                visible: active
                player: root.player
                onVisibleChanged: if (!root.visible) active = false
            }
        }
    }
    onVisibleChanged: if (!visible) lyrics.active = false
    Timer {
        interval: 250; repeat: true
        running: root.visible && !!root.player?.isPlaying
        onTriggered: root.player?.positionChanged()
    }
}
