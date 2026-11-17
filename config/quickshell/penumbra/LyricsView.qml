import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property alias player: lyrics.player
    property alias active: lyrics.active
    readonly property alias result: lyrics.result
    readonly property alias lines: lyrics.lines
    readonly property alias current: lyrics.current
    TrackLyrics { id: lyrics }
    readonly property int maximumContentHeight: Math.max(heading.implicitHeight, retry.implicitHeight)
        + spacing + Math.max(synced.implicitHeight, unsynced.implicitHeight, statusLabel.implicitHeight)
    spacing: 5
    RowLayout {
        id: heading
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: lyrics.embedded ? "Lyrics" : "Lyrics · LRCLIB"; color: Theme.textSoft; font.pixelSize: Theme.textTiny }
        PillButton {
            id: retry
            visible: root.result.status === "offline"
            text: "Retry"
            onClicked: lyrics.retry()
        }
    }
    Item {
        id: synced
        Layout.fillWidth: true
        implicitHeight: 90
        visible: root.lines.length > 0
        clip: true
        Column {
            width: parent.width
            y: 30 - Math.max(-1, root.current) * 30
            Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
            Repeater {
                model: root.lines
                delegate: Label {
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 30
                    text: modelData.text || "♪"
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                    font.weight: index === root.current ? Font.DemiBold : Font.Normal
                    color: index === root.current ? Theme.white : Theme.textSoft
                    opacity: index === root.current ? 1 : 0.5
                }
            }
        }
    }
    Flickable {
        id: unsynced
        Layout.fillWidth: true
        implicitHeight: 100
        visible: !root.lines.length && !!root.result.plain
        contentHeight: plain.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        clip: true
        Label {
            id: plain
            width: unsynced.width
            elide: Text.ElideNone
            text: "Unsynced lyrics\n\n" + (root.result.plain ?? "")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.textSoft
        }
    }
    Label {
        id: statusLabel
        Layout.fillWidth: true
        visible: !root.lines.length && !root.result.plain
        text: (!root.result.status || root.result.status === "loading") ? "Finding lyrics…" : root.result.status === "offline" ? "Lyrics unavailable offline" : root.result.instrumental ? "Instrumental" : "No lyrics for this track"
        horizontalAlignment: Text.AlignHCenter
        color: Theme.textSoft
    }
}
