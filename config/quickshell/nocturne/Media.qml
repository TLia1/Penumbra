pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// What's playing, and a small spectrum of it from cava while it plays.
Singleton {
    id: root

    // The player that is playing, else the last one that played, while it lasts.
    readonly property var playing: Mpris.players.values.find(p => p.isPlaying) ?? null
    property var recent: null
    onPlayingChanged: if (playing) recent = playing
    readonly property var player: playing ?? (Mpris.players.values.includes(recent) ? recent : null)
    readonly property int count: 8
    property var bars: new Array(count).fill(0)

    readonly property string config: [
        "[general]", `bars = ${count}`, "framerate = 30", "sleep_timer = 2",
        "[input]", "method = pipewire",
        "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii",
        "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10",
        "[smoothing]", "noise_reduction = 60", ""
    ].join("\n")

    // cava prints one frame per line: "12;40;7;…;".
    Process {
        running: Ui.hasVisualizer && !!root.playing
        command: ["bash", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/nocturne/cava.conf"; mkdir -p "${f%/*}"; printf "%s" "$1" > "$f"; exec cava -p "$f"', "_", root.config]
        stdout: SplitParser {
            onRead: data => root.bars = data.split(";").filter(v => v !== "").map(v => Math.min(1, parseInt(v) / 100))
        }
        onRunningChanged: if (!running) root.bars = new Array(root.count).fill(0)
    }
}
