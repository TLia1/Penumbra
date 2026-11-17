import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    signal back()
    signal restored()
    color: Theme.glassStrong
    radius: Theme.radius
    border.color: Theme.lineStrong
    implicitHeight: Math.ceil(body.anchors.margins * 2 + header.implicitHeight + items.implicitHeight
        + body.spacing + (status.visible ? body.spacing + status.implicitHeight : 0) + 4)

    property var profiles: []
    property var selection: []
    property bool editing: false
    property string replacing: ""
    property string removing: ""
    property string message: ""
    property bool failed: false
    readonly property bool busy: worker.running
    readonly property bool restoring: busy && worker.command[1] === "restore"
    readonly property var outputs: Wm.monitors.filter(m => Quickshell.screens.some(s => s.name === m.name))

    function refresh() {
        editing = false;
        removing = "";
        if (!busy) run("list");
        Qt.callLater(() => backButton.forceActiveFocus());
    }
    function edit(name) {
        replacing = name;
        nameField.text = name;
        const prior = profiles.find(p => p.name === name);
        projectField.text = prior?.project ?? "";
        selection = Wm.workspaces.filter(w => outputs.some(m => m.name === w.monitor.name) && (prior
            ? prior.places.some(p => p[0] === w.monitor.name && p[1] === w.id)
            : w.active)).map(w => [w.monitor.name, w.id]);
        message = "";
        editing = true;
        Qt.callLater(() => nameField.forceActiveFocus());
    }
    function toggle(output, tag) {
        const keep = selection.filter(p => p[0] !== output || p[1] !== tag);
        selection = keep.length === selection.length ? keep.concat([[output, tag]]) : keep;
    }
    function run(action, name) {
        if (busy) return;
        const args = [Ui.bin + "penumbra-workspaces", action];
        if (action === "save" || action === "replace") {
            const entries = Object.create(null);
            for (const c of Wm.clients)
                entries[c.appId] = DesktopEntries.heuristicLookup(c.appId)?.id ?? c.appId;
            args.push("--project", projectField.text.trim(), "--selection", JSON.stringify(selection), "--entries", JSON.stringify(entries));
        }
        if (name !== undefined) args.push("--", name);
        failed = false;
        message = "";
        worker.command = args;
        worker.running = true;
    }
    Process {
        id: worker
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.failed = code !== 0;
            if (root.failed) {
                root.message = err.text.trim() || "Workspace operation failed.";
                return;
            }
            try {
                const result = JSON.parse(out.text);
                root.profiles = result.profiles;
                root.message = result.message || "";
                root.editing = false;
                root.removing = "";
                if (worker.command[1] === "restore" && result.complete && !result.remapped && root.visible)
                    root.restored();
                else if (root.visible)
                    backButton.forceActiveFocus();
            } catch (error) {
                root.failed = true;
                root.message = "Could not read the workspace result.";
            }
        }
    }

    MouseArea { anchors.fill: parent } // Keep clicks inside the card from dismissing Overview.
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            if (root.removing) root.removing = "";
            else if (root.editing) { root.editing = false; root.message = ""; backButton.forceActiveFocus(); }
            else root.back();
        }
    }
    ColumnLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Math.min(22, root.width / 20)
        spacing: 12
        RowLayout {
            id: header
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: root.editing ? (root.replacing ? "Update workspace" : "New workspace") : "Saved workspaces"
                font.family: Theme.display
                font.pixelSize: Theme.textLarge
                font.weight: Font.DemiBold
            }
            PillButton {
                id: backButton
                text: root.editing ? "Cancel" : "Back"
                onClicked: {
                    if (root.editing) { root.editing = false; root.message = ""; }
                    else root.back();
                }
            }
        }
        Controls.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                id: items
                width: scroll.availableWidth
                spacing: 10
                PillButton {
                    visible: !root.editing
                    text: "New workspace"
                    primary: true
                    available: !root.busy
                    onClicked: root.edit("")
                }
                Label {
                    Layout.fillWidth: true
                    visible: !root.editing && !root.profiles.length && !root.busy && !root.failed
                    text: "Save a set of apps and tags to reopen together."
                    wrapMode: Text.Wrap
                    color: Theme.textSoft
                }
                Repeater {
                    model: root.editing ? [] : root.profiles
                    delegate: ColumnLayout {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 5
                        Label {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            textFormat: Text.PlainText
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: row.modelData.windows + (row.modelData.windows === 1 ? " window" : " windows")
                                + " · " + row.modelData.places.length + (row.modelData.places.length === 1 ? " tag" : " tags")
                            color: Theme.muted
                            font.pixelSize: Theme.textSmall
                        }
                        RowLayout {
                            enabled: !root.busy
                            PillButton {
                                primary: true
                                text: "Open"
                                onClicked: root.run("restore", row.modelData.name)
                            }
                            PillButton {
                                text: "Update…"
                                onClicked: root.edit(row.modelData.name)
                            }
                            PillButton {
                                text: root.removing === row.modelData.name ? "Confirm delete" : "Delete"
                                danger: true
                                onClicked: {
                                    if (root.removing === row.modelData.name) root.run("delete", row.modelData.name);
                                    else root.removing = row.modelData.name;
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.editing
                    enabled: !root.busy
                    spacing: 10
                    Field {
                        id: nameField
                        Layout.fillWidth: true
                        maximumLength: 80
                        readOnly: root.replacing !== ""
                        placeholderText: "Workspace name"
                        Accessible.name: "Workspace name"
                        onAccepted: if (saveButton.available) saveButton.clicked()
                    }
                    Field {
                        id: projectField
                        Layout.fillWidth: true
                        placeholderText: "Project folder (optional) · ~/Projects/example"
                        Accessible.name: "Project folder"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Choose the tags whose apps and tiling layouts to save."
                        wrapMode: Text.Wrap
                        color: Theme.textSoft
                    }
                    Repeater {
                        model: root.editing ? root.outputs : []
                        delegate: ColumnLayout {
                            id: output
                            required property var modelData
                            Layout.fillWidth: true
                            Label { text: output.modelData.name }
                            Flow {
                                Layout.fillWidth: true
                                Layout.preferredHeight: childrenRect.height
                                spacing: 5
                                Repeater {
                                    model: Wm.allTagsFor(output.modelData.name)
                                    delegate: PillButton {
                                        required property var modelData
                                        text: modelData.name
                                        primary: root.selection.some(p => p[0] === output.modelData.name && p[1] === modelData.id)
                                        Accessible.name: output.modelData.name + ", tag " + text
                                        Accessible.checkable: true
                                        Accessible.checked: primary
                                        onClicked: root.toggle(output.modelData.name, modelData.id)
                                    }
                                }
                            }
                        }
                    }
                    PillButton {
                        id: saveButton
                        text: root.replacing ? "Replace saved workspace" : "Save workspace"
                        primary: true
                        available: !root.busy && !!nameField.text.trim() && root.selection.length > 0
                        onClicked: root.run(root.replacing ? "replace" : "save", nameField.text.trim())
                    }
                }
            }
        }
        Label {
            id: status
            Layout.fillWidth: true
            visible: root.restoring || root.message !== ""
            text: root.restoring ? "Opening workspace…" : root.message
            textFormat: Text.PlainText
            color: root.failed ? Theme.rose : Theme.textSoft
            wrapMode: Text.Wrap
            maximumLineCount: 5
        }
    }
}
