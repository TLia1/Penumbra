pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Casting the screen to a TV. penumbra-cast finds the TVs (Chromecast, Google TV and DLNA) and does
// the cast, keeping it in $XDG_RUNTIME_DIR/penumbra/cast so it outlives the shell; the control
// center's Cast page and the bar show it from there.
Singleton {
    id: root

    property var tvs: [] // [{ id, name, kind (chromecast or dlna), model }]
    property bool scanning: false
    property bool scanned: false

    property bool casting: false
    property bool connecting: false
    property string tvId: ""
    property string tvName: ""
    property bool sound: false // whether the TV plays what the computer plays too

    function scan() {
        if (!scanner.running) {
            scanning = true;
            scanner.running = true;
        }
    }
    function start(tv, output) {
        const command = [Ui.bin + "penumbra-cast", "start", tv.id, "--name", tv.name];
        if (output)
            command.push("--output", output);
        if (Settings.castSound)
            command.push("--sound");
        // Shown at once; penumbra-cast confirms it in a moment.
        tvId = tv.id;
        tvName = tv.name;
        sound = Settings.castSound;
        connecting = true;
        casting = true;
        Ui.spawn(command);
    }
    function stop() {
        Quickshell.execDetached([Ui.bin + "penumbra-cast", "stop"]);
    }
    function refresh() {
        state.reload();
    }

    Process {
        id: scanner
        command: [Ui.bin + "penumbra-cast", "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tvs = JSON.parse(text);
                } catch (e) {
                    root.tvs = [];
                }
            }
        }
        onExited: {
            root.scanning = false;
            root.scanned = true;
        }
    }

    FileView {
        id: state
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/penumbra/cast"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const cast = JSON.parse(text());
                root.tvId = cast.id ?? "";
                root.tvName = cast.name ?? "";
                root.sound = cast.sound ?? root.sound;
                root.connecting = cast.phase === "connecting";
                root.casting = true;
            } catch (e) {
                root.casting = false;
            }
        }
        onLoadFailed: {
            root.casting = false;
            root.connecting = false;
        }
    }
}
