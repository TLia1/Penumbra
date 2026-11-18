import QtQuick
import Quickshell
import Quickshell.Io
import "lyrics.js" as Lrc

Scope {
    id: root
    property var player: null
    property bool active: false
    property var response: ({})
    readonly property string embedded: String(player?.metadata?.["xesam:asText"] ?? "").trim()
    readonly property var result: embedded ? {status: "ok", synced: embedded, plain: embedded} : response
    readonly property string signature: JSON.stringify([player?.trackTitle ?? "", player?.trackArtist ?? "", player?.trackAlbum ?? "", Math.round(Media.duration(player))])
    readonly property var lines: Lrc.parse(result.synced ?? "")
    readonly property int current: Lrc.current(lines, player?.position ?? 0)
    property string loaded: ""
    onSignatureChanged: { response = {}; loaded = ""; settle.restart(); }
    onEmbeddedChanged: if (!embedded && active) settle.restart()
    onActiveChanged: if (active) settle.restart()
    function retry() { loaded = ""; settle.restart(); }
    function fetch() {
        if (!active || embedded || !player || request.running || loaded === signature) return;
        if (!player.trackTitle || !player.trackArtist || Media.isLive(player)) {
            response = { status: "missing" }; return;
        }
        request.signature = signature;
        request.command = [Ui.bin + "penumbra-online", "lyrics"].concat(JSON.parse(signature).map(String));
        response = { status: "loading" };
        request.running = true;
    }
    Timer { id: settle; interval: 400; onTriggered: root.fetch() }
    Process {
        id: request
        property string signature
        stdout: StdioCollector {
            onStreamFinished: {
                if (request.signature !== root.signature) return;
                try { root.response = JSON.parse(text); } catch (e) { root.response = { status: "offline" }; }
                root.loaded = request.signature;
            }
        }
        onExited: {
            if (request.signature !== root.signature) settle.restart();
            else if (root.result.status === "loading") root.response = { status: "offline" };
        }
    }
}
