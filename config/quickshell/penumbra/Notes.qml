pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Keep the draft and pending save alive when the sidebar page closes.
Singleton {
    id: root
    property string draft: ""
    property bool ready: false
    property bool dirty: false
    property string error: ""
    property string writing: ""
    function edit(text) {
        draft = text;
        dirty = true;
        settle.restart();
    }
    function save() {
        if (!ready || !dirty) return;
        error = "";
        writing = draft;
        file.setText(writing);
    }
    Timer { id: settle; interval: 400; onTriggered: root.save() }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.local/state/penumbra/notes.txt"
        printErrors: false
        onLoaded: { root.draft = text(); root.ready = true; }
        onLoadFailed: code => {
            root.ready = code === FileViewError.FileNotFound;
            if (!root.ready) root.error = "Couldn't read notes";
        }
        onSaved: {
            root.dirty = root.draft !== root.writing;
            if (root.dirty) settle.restart();
        }
        onSaveFailed: root.error = "Couldn't save notes. Your draft is still here; retry when storage is available."
    }
}
