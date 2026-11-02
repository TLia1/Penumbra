pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recordings and capture countdowns. penumbra-record does the recording and keeps it in
// $XDG_RUNTIME_DIR/penumbra/recording ("started-at\nfile\npaused"; the start moves on by the time
// spent paused), so a recording outlives the shell; the bar shows it from there. A capture with a
// timer counts down here first, shown in the bar too.
Singleton {
    id: root

    property bool recording: false
    property real startedAt: 0 // seconds since the epoch
    property string file: ""
    property bool paused: false
    property int elapsed: 0 // seconds
    readonly property string elapsedText: `${Math.floor(elapsed / 60)}:${String(elapsed % 60).padStart(2, "0")}`

    function refresh() {
        state.reload();
    }
    function stop() {
        Quickshell.execDetached([Ui.bin + "penumbra-record", "stop"]);
    }
    function togglePause() {
        Quickshell.execDetached([Ui.bin + "penumbra-record", paused ? "resume" : "pause"]);
    }

    FileView {
        id: state
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/penumbra/recording"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const [started, file, paused] = text().split("\n");
            root.startedAt = Number(started) || 0;
            root.file = file ?? "";
            root.paused = paused === "paused";
            root.recording = root.startedAt > 0;
        }
        onLoadFailed: { root.recording = false; root.paused = false; }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.recording && !root.paused
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.max(0, Math.floor(Date.now() / 1000 - root.startedAt))
    }

    // Run `command` after `delay` seconds of countdown. The countdown leaves the bar a moment before
    // the command runs, so a screenshot of the bar doesn't show it.
    property int countdown: 0
    property var pending: []
    function after(delay, command) {
        pending = command;
        countdown = delay;
        if (delay > 0)
            tick.restart();
        else
            go.restart();
    }
    function cancel() {
        tick.stop();
        countdown = 0;
        pending = [];
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                tick.stop();
                go.restart();
            }
        }
    }
    // Also lets the compositor draw a frame without the overlay before the capture starts.
    Timer {
        id: go
        interval: 90
        onTriggered: {
            if (root.pending.length)
                Ui.spawn(root.pending);
            root.pending = [];
        }
    }
}
