import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland

// The lock screen, on every monitor. hypridle locks through `ipc call lock lock` (which
// `loginctl lock-session` triggers); hyprlock takes over when the shell is not running. With a
// finger enrolled in fprintd, a touch of the reader unlocks it too, while the password still works.
Scope {
    id: root

    property string password: ""
    property bool busy: false
    property string message: ""
    property bool capsLock: false
    readonly property bool locked: sessionLock.locked
    signal rejected()

    // Fingerprint: whether a finger is enrolled (fprintd-list, checked at each lock), the reader
    // is waiting, and what it last said.
    property bool fingerprint: false
    readonly property bool fingerWaiting: fingerPam.active
    property string fingerMessage: ""
    property int fingerTries: 0

    function lock() {
        if (sessionLock.locked)
            return;
        Ui.closeOverlays();
        capsLeds.running = true;
        password = "";
        message = "";
        fingerTries = 0;
        fingerMessage = "";
        fingers.running = true;
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
    function unlock() {
        if (pam.active)
            pam.abort();
        if (fingerPam.active)
            fingerPam.abort();
        sessionLock.locked = false;
        lockState.setText("");
    }
    // Wait for a finger; a click on the fingerprint glyph tries again after giving up.
    function startFinger() {
        if (fingerprint && sessionLock.locked && !fingerPam.active && fingerTries < 5)
            fingerPam.start();
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
                root.unlock();
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

    // The fingerprint check, through the shell's own PAM stack (pam/fingerprint): one scan each
    // time, so a miss can say so and the next scan starts afresh. Five misses or timeouts stop it.
    PamContext {
        id: fingerPam
        configDirectory: Quickshell.shellDir + "/pam"
        config: "fingerprint"
        onPamMessage: {
            if (responseRequired)
                respond("");
            else if (message)
                root.fingerMessage = /finger|swipe|reader/i.test(message) && !messageIsError ? "Touch the fingerprint reader, or type your password" : message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.fingerTries += 1;
            root.fingerMessage = root.fingerTries >= 5 ? "Fingerprint paused · click it to try again" : "Fingerprint not recognised";
            if (root.fingerTries < 5)
                fingerRetry.restart();
        }
        onError: error => {
            // No reader, or fprintd missing: the password alone.
            root.fingerprint = false;
            root.fingerMessage = "";
        }
    }
    Timer {
        id: fingerRetry
        interval: 900
        onTriggered: root.startFinger()
    }
    Process {
        id: fingers
        command: ["bash", "-c", "command -v fprintd-list >/dev/null && fprintd-list \"$USER\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fingerprint = /#\d+:/.test(text);
                root.startFinger();
            }
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
