import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "lyrics.js" as Lrc

ColumnLayout {
    id: root
    property var player: null
    property bool active: false
    property var result: ({})
    readonly property string signature: JSON.stringify([player?.trackTitle ?? "", player?.trackArtist ?? "", player?.trackAlbum ?? "", Math.round(player?.length ?? 0)])
    readonly property var lines: Lrc.parse(result.synced ?? "")
    readonly property int current: Lrc.current(lines, player?.position ?? 0)
    property string loaded: ""
    spacing: 5
    onSignatureChanged: { result = {}; loaded = ""; settle.restart(); }
    onActiveChanged: if (active) settle.restart()
    function fetch() {
        if (!active || !player || request.running || loaded === signature) return;
        if (!player.trackTitle || !player.trackArtist || Media.isLive(player)) {
            result = { status: "missing" }; return;
        }
        request.signature = signature;
        request.command = [Ui.bin + "penumbra-online", "lyrics"].concat(JSON.parse(signature).map(String));
        result = { status: "loading" };
        request.running = true;
    }
    Timer { id: settle; interval: 400; onTriggered: root.fetch() }
    Process {
        id: request
        property string signature
        stdout: StdioCollector {
            onStreamFinished: {
                if (request.signature !== root.signature) return;
                try { root.result = JSON.parse(text); } catch (e) { root.result = { status: "offline" }; }
                root.loaded = request.signature;
            }
        }
        onExited: {
            if (request.signature !== root.signature) settle.restart();
            else if (root.result.status === "loading") root.result = { status: "offline" };
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label { Layout.fillWidth: true; text: "Lyrics · LRCLIB"; color: Theme.textSoft; font.pixelSize: Theme.textTiny }
        PillButton {
            visible: root.result.status === "offline"
            text: "Retry"
            onClicked: { root.loaded = ""; settle.restart(); }
        }
    }
    Item {
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
        Layout.fillWidth: true
        implicitHeight: 100
        visible: !root.lines.length && !!root.result.plain
        contentHeight: plain.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        clip: true
        Label {
            id: plain
            width: parent.width
            text: "Unsynced lyrics\n\n" + (root.result.plain ?? "")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Theme.textSoft
        }
    }
    Label {
        Layout.fillWidth: true
        visible: !root.lines.length && !root.result.plain
        text: root.result.status === "loading" ? "Finding lyrics…" : root.result.status === "offline" ? "Lyrics unavailable offline" : root.result.instrumental ? "Instrumental" : "No lyrics for this track"
        horizontalAlignment: Text.AlignHCenter
        color: Theme.textSoft
    }
}
