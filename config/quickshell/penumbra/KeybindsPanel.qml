import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell.Io
import "keybinds.js" as Keybinds

// Refresh from the compositor on each open, so user bindings never need a second list.
Panel {
    id: root
    originKey: "keybinds"
    anchors { top: true; right: true }
    margins.right: edgeMargin - shadowRoom
    preferredSheetWidth: 620
    open: Ui.keybindsOpen
    onDismissed: Ui.dismiss()

    property var bindings: []
    property string error: ""
    readonly property var matches: Keybinds.filter(bindings, search.text)
    function refresh() {
        if (readBindings.running) return;
        error = "";
        bindings = [];
        readBindings.running = true;
    }
    onOpenChanged: if (open) {
        search.text = "";
        refresh();
        Qt.callLater(() => search.forceActiveFocus());
    }

    Process {
        id: readBindings
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.bindings = Keybinds.entries(JSON.parse(text));
                } catch (e) {
                    root.error = "Could not read keyboard shortcuts. Check that Hyprland is running, then retry.";
                }
            }
        }
        onExited: code => {
            if (code !== 0) root.error = "Could not read keyboard shortcuts. Check that Hyprland is running, then retry.";
        }
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: "Keyboard shortcuts"
                font.pixelSize: Theme.textLarge
                font.weight: Font.DemiBold
            }
            PillButton { text: "Close"; onClicked: Ui.dismiss() }
        }
        Label {
            Layout.fillWidth: true
            text: "Super + F1 to toggle · Esc to close · Super is the Windows key"
            font.pixelSize: Theme.textSmall
            color: Theme.muted
            wrapMode: Text.Wrap
        }
        Field {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search keys or actions…"
            onTextChanged: list.positionViewAtBeginning()
            Keys.onEscapePressed: Ui.dismiss()
            Keys.onDownPressed: list.forceActiveFocus()
        }
        Label {
            Layout.fillWidth: true
            visible: readBindings.running || root.error !== "" || root.matches.length === 0
            text: readBindings.running ? "Reading shortcuts…" : root.error || (root.bindings.length ? "No matching shortcuts." : "No active bindings.")
            color: root.error ? Theme.rose : Theme.muted
            wrapMode: Text.Wrap
        }
        PillButton { visible: root.error !== ""; text: "Retry"; onClicked: root.refresh() }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(80, Math.min(520, root.implicitHeight - 240))
            clip: true
            spacing: 4
            model: root.matches
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            Keys.onEscapePressed: Ui.dismiss()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
                    contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + (event.key === Qt.Key_PageDown ? height : -height)));
                    event.accepted = true;
                }
            }
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width - 12
                implicitHeight: row.implicitHeight + 20
                radius: Theme.radiusSmall
                color: index % 2 === 0 ? Theme.glassStrong : "transparent"
                RowLayout {
                    id: row
                    x: 10; y: 10
                    width: parent.width - 20
                    spacing: 16
                    Label {
                        Layout.preferredWidth: row.width * 0.43
                        text: modelData.keys
                        textFormat: Text.PlainText
                        font.family: Theme.mono
                        font.pixelSize: Theme.textSmall
                        color: Theme.accentBright
                        wrapMode: Text.Wrap
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Label { Layout.fillWidth: true; text: modelData.action; textFormat: Text.PlainText; wrapMode: Text.Wrap }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: modelData.details
                            textFormat: Text.PlainText
                            font.pixelSize: Theme.textSmall
                            color: Theme.muted
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.matches.length + " / " + root.bindings.length + " active bindings · Scroll to see more"
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }
}
