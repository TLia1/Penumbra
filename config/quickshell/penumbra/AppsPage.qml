import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Default apps: the web browser is the XDG default every app asks for (xdg-settings); the file
// manager and terminal are settings.conf's, for Super+E and Super+Enter, and the file manager also
// becomes the XDG default for folders.
ColumnLayout {
    id: root

    spacing: 12

    property string browser: ""
    property string expanded: ""
    onVisibleChanged: {
        expanded = "";
        if (visible)
            current.running = true;
    }

    // Desktop entry ids, with or without ".desktop".
    function bare(id) {
        return (id ?? "").trim().replace(/\.desktop$/, "");
    }
    function apps(category) {
        return DesktopEntries.applications.values.filter(e => !e.noDisplay && e.categories.includes(category))
            .sort((a, b) => a.name.localeCompare(b.name));
    }
    function entry(id) {
        return DesktopEntries.applications.values.find(e => bare(e.id) === bare(id)) ?? null;
    }

    Process {
        id: current
        command: ["xdg-settings", "get", "default-web-browser"]
        stdout: StdioCollector {
            onStreamFinished: root.browser = root.bare(text)
        }
    }
    Process {
        id: change
        onExited: current.running = true
    }
    function choose(kind, id) {
        expanded = "";
        if (kind === "terminal") {
            Config.set({ terminal: bare(id) });
            return;
        }
        if (kind === "files") {
            Config.set({ file_manager: bare(id) });
            change.command = ["xdg-mime", "default", bare(id) + ".desktop", "inode/directory"];
        } else {
            browser = bare(id);
            change.command = ["xdg-settings", "set", "default-web-browser", bare(id) + ".desktop"];
        }
        change.running = true;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Default apps"
        status: "What links, folders and Super+Enter open"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: [
                { kind: "browser", glyph: "󰖟", title: "Web browser", category: "WebBrowser", id: root.browser, keys: "Super+B and links" },
                { kind: "files", glyph: "󰉋", title: "File manager", category: "FileManager", id: Config.values.file_manager ?? "io.github.lia.Files", keys: "Super+E and folders" },
                { kind: "terminal", glyph: "󰆍", title: "Terminal", category: "TerminalEmulator", id: Config.values.terminal ?? "kitty", keys: "Super+Enter" }
            ]
            delegate: ListRow {
                id: row
                required property var modelData
                readonly property var app: root.entry(modelData.id)
                readonly property var others: root.apps(modelData.category)
                Layout.fillWidth: true
                glyph: modelData.glyph
                title: modelData.title
                subtitle: `${app?.name ?? (modelData.id || "None")} · ${modelData.keys}`
                trailing: others.length > 1 ? (expanded ? "󰅃" : "󰅀") : ""
                expanded: root.expanded === modelData.kind
                onClicked: if (others.length > 1) root.expanded = expanded ? "" : modelData.kind

                Repeater {
                    model: row.others
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool chosen: root.bare(modelData.id) === root.bare(row.modelData.id)
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: Theme.radiusSmall
                        color: chosen ? Theme.alpha(Theme.accent, 0.16) : choice.containsMouse ? Theme.hover : "transparent"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                            spacing: 10
                            IconImage {
                                implicitSize: 18
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                asynchronous: true
                            }
                            Label { Layout.fillWidth: true; text: modelData.name; font.weight: chosen ? Font.DemiBold : Font.Normal }
                            Glyph { visible: chosen; text: "󰄬"; size: 13; color: Theme.accentBright }
                        }
                        MouseArea {
                            id: choice
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choose(row.modelData.kind, modelData.id)
                        }
                    }
                }
            }
        }
    }
}
