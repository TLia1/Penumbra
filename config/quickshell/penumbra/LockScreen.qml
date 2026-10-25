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
        capsLeds.running = true;
        password = "";
        message = "";
        checkCaps();
        lockState.setText("locked\n");
        sessionLock.locked = true;
    }
    function submit() {
        if (busy || password === "")
            return;
        busy = true;
        message = "";
        pam.start();
    }
    // Re-reads the Caps Lock LEDs; cheap enough for every keypress.
    function checkCaps() {
        for (const led of leds.instances)
            led.reload();
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
                lockState.setText("");
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

    // Whether the screen is locked, kept outside the shell: if the shell dies while locked,
    // systemd starts it again (penumbra-shell.service) and it locks straight away. The runtime
    // directory is emptied at logout, so a stale "locked" never outlives the session.
    FileView {
        id: lockState
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/penumbra-locked"
        printErrors: false
        onLoaded: if (text().trim() === "locked") root.lock()
    }

    // Caps Lock lights an LED on every keyboard that has one. The LEDs are listed when locking
    // (a keyboard may have been plugged in since), then read directly.
    property var capsPaths: []
    Process {
        id: capsLeds
        running: true
        command: ["bash", "-c", "printf '%s\\n' /sys/class/leds/*::capslock/brightness"]
        stdout: StdioCollector {
            onStreamFinished: root.capsPaths = text.split("\n").filter(p => p.startsWith("/") && !p.includes("*"))
        }
    }
    Variants {
        id: leds
        model: root.capsPaths
        delegate: FileView {
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: root.capsLock = leds.instances.some(led => led.loaded && parseInt(led.text()) > 0)
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
