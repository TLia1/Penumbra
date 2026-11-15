import QtQuick

Panel {
    id: panel
    required property bool requested
    property bool ready: false
    open: ready && requested

    // Start closed so first-open handlers and the entrance animation run after construction.
    Timer { interval: 1; running: true; onTriggered: panel.ready = true }
}
