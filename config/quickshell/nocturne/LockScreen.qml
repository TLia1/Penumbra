import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen, on every monitor. hypridle locks through `ipc call lock lock` (which
// `loginctl lock-session` triggers); hyprlock takes over when the shell is not running.
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property string message: ""
    property bool capsLock: false
    readonly property bool locked: sessionLock.locked
    signal rejected()

    function lock() {
        if (sessionLock.locked)
            return;
        Ui.closeOverlays();
        password = "";
        message = "";
        checkCaps();
        sessionLock.locked = true;
    }
    function submit() {
        if (busy || password === "")
            return;
        busy = true;
        message = "";
        pam.start();
    }
    function checkCaps() {
        caps.running = true;
    }

    // The default "login" PAM stack, the same one hyprlock includes.
    PamContext {
        id: pam
        onPamMessage: {
            if (responseRequired)
                respond(root.password);
            else if (message)
                root.message = message;
        }
        onCompleted: result => {
            root.busy = false;
            root.password = "";
            if (result === PamResult.Success) {
                sessionLock.locked = false;
                return;
            }
            if (result === PamResult.MaxTries)
                root.message = "Too many attempts; wait a moment";
            else if (!root.message)
                root.message = "Wrong password";
            root.rejected();
        }
        onError: error => {
            root.busy = false;
            root.password = "";
            root.message = "Could not check the password (" + PamError.toString(error) + ")";
            root.rejected();
        }
    }

    // Caps Lock lights an LED on every keyboard that has one.
    Process {
        id: caps
        command: ["bash", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = text.split("\n").some(v => parseInt(v) > 0)
        }
    }

    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            id: surface
            color: Theme.base
            LockContent {
                anchors.fill: parent
                lock: root
                pixelRatio: surface.screen?.devicePixelRatio ?? 1
            }
        }
    }
}
