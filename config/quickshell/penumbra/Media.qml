pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "youtube.js" as YouTube

// What's playing, and a small spectrum of it from cava while it plays.
Singleton {
    id: root

    // The player that is playing, else the last one that played, while it lasts.
    readonly property var playing: Mpris.players.values.find(p => p.isPlaying) ?? null
    property var recent: null
    onPlayingChanged: if (playing) recent = playing
    readonly property var player: playing ?? (Mpris.players.values.includes(recent) ? recent : null)
    readonly property int count: 8
    readonly property int bandCount: 20
    property var stereoBars: new Array(2 * bandCount).fill(0)
    // Cava places bass at the centre of stereo output. Pair the channels
    // from the centre out for Moonwake’s low-to-high spectrum.
    readonly property var spectrum: Array.from({ length: bandCount }, (_, i) =>
        (stereoBars[bandCount - 1 - i] + stereoBars[bandCount + i]) / 2)

    // The capsule and the other depth scenes use a compact eight-band spectrum.
    readonly property var bars: Array.from({ length: count }, (_, i) => {
        const first = Math.floor(i * stereoBars.length / count);
        const end = Math.floor((i + 1) * stereoBars.length / count);
        return Math.max(0, ...stereoBars.slice(first, end));
    })

    // The app's own name ("Firefox"), not its MPRIS identity ("Mozilla firefox").
    function appName(p) {
        if (!p)
            return "";
        return DesktopEntries.heuristicLookup(p.desktopEntry || p.identity)?.name || p.identity;
    }
    // Live streams have no real length: Firefox reports an endless one (about 292,000 years).
    function endless(p) {
        return !!p && p.lengthSupported && p.length > 100 * 3600;
    }
    function isLive(p) {
        return endless(p) || (!!p && p === player && videoTiming?.live === true);
    }
    function duration(p) {
        if (!p || isLive(p)) return 0;
        if (p.lengthSupported && p.length > 0) return p.length;
        return p === player ? videoTiming?.seconds ?? 0 : 0;
    }

    readonly property string videoId: YouTube.videoId(player?.metadata?.["xesam:url"])
    readonly property var videoTiming: timing.instances[0] ?? null
    // One metadata lookup shared by every screen. Changing video destroys the old request.
    Variants {
        id: timing
        model: root.videoId && !(root.player?.lengthSupported && root.player.length > 0) ? [root.videoId] : []
        delegate: Process {
            id: lookup
            required property string modelData
            property real seconds: 0
            property bool live: false
            command: ["timeout", "20", "yt-dlp", "--ignore-config", "--no-playlist", "--skip-download",
                "--ignore-no-formats-error", "--socket-timeout", "5", "--retries", "0", "--extractor-retries", "0",
                "--print", "%(.{duration,live_status})j", "--", "https://www.youtube.com/watch?v=" + modelData]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    if (!text.trim()) return;
                    try {
                        const info = JSON.parse(text);
                        lookup.live = info.live_status === "is_live";
                        if (!lookup.live && info.live_status !== "is_upcoming" && Number.isFinite(info.duration) && info.duration > 0)
                            lookup.seconds = info.duration;
                    } catch (error) { return; }
                }
            }
        }
    }
    // 4:05, or 1:02:03 past an hour.
    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds)), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    readonly property string config: [
        "[general]", `bars = ${2 * bandCount}`, "framerate = 30", "sleep_timer = 2",
        "[input]", "method = pipewire",
        "[output]", "channels = stereo", "method = raw", "raw_target = /dev/stdout", "data_format = ascii",
        "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10",
        "[smoothing]", "noise_reduction = 60", ""
    ].join("\n")

    // cava prints one frame per line: "12;40;7;…;".
    Process {
        running: Ui.hasVisualizer && !!root.playing
        command: ["bash", "-c", 'f="${XDG_RUNTIME_DIR:-/tmp}/penumbra/cava.conf"; mkdir -p "${f%/*}"; printf "%s" "$1" > "$f"; exec cava -p "$f"', "_", root.config]
        stdout: SplitParser {
            onRead: data => {
                const frame = data.trim().split(";").filter(v => v !== "").map(v => Number(v) / 100);
                if (frame.length === 2 * root.bandCount && frame.every(Number.isFinite))
                    root.stereoBars = frame.map(v => Math.max(0, Math.min(1, v)));
            }
        }
        onRunningChanged: if (!running) root.stereoBars = new Array(2 * root.bandCount).fill(0)
    }
}
