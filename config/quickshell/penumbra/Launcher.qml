import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "search.js" as Search
import "symbols.js" as Symbols

// Applications, clipboard history, emoji and symbols, over a dimmed screen. Type to search; `>` runs
// a command, a sum (or `=`) is worked out and copied; Tab moves to the next mode.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.launcherOpen || card.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-launcher"
    WlrLayershell.keyboardFocus: Ui.launcherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var modes: [
        { mode: "apps", label: "Apps", glyph: "󰀻" },
        { mode: "clipboard", label: "Clipboard", glyph: "󰅍" },
        { mode: "emoji", label: "Emoji", glyph: "󰇵" },
        { mode: "symbols", label: "Symbols", glyph: "󰒠" }
    ]
    readonly property bool clipboard: Ui.launcherMode === "clipboard"
    // Emoji and symbols are a grid of characters.
    readonly property bool characters: Ui.launcherMode === "emoji" || Ui.launcherMode === "symbols"
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    // Emoji and symbols are read the first time either opens, not at startup.
    property bool charactersUsed: false
    onCharactersChanged: if (characters) charactersUsed = true
    onSymbolsChanged: if (Ui.launcherOpen) refresh()
    readonly property var symbols: charactersUsed ? Symbols.groups.reduce((all, g) => all.concat(g[1].map(s => ({ char: s[0], name: s[1], group: g[0] }))), []) : []
    property var emoji: []
    property var results: []
    property var clips: []
    property var usage: ({}) // desktop entry id → launches
    property var picks: ({}) // emoji or symbol → times picked
    property var pointer: null // where the mouse last was, in window coordinates

    Connections {
        target: Ui
        function onLauncherOpenChanged() {
            if (Ui.launcherOpen) {
                root.pointer = null;
                root.reset();
            }
        }
        function onLauncherModeChanged() { if (Ui.launcherOpen) root.reset(); }
    }
    onAppsChanged: refresh()

    function reset() {
        search.text = "";
        search.forceActiveFocus();
        if (clipboard)
            clipList.running = true;
        refresh();
    }

    // Hover follows the mouse only when it moves: opening under a still cursor, the card growing or
    // results shifting beneath it leave the selection alone. Positions are the pointer's own window
    // coordinates, never mapped back through the scaling card, so a still cursor reads the same each
    // time. The first sighting only records where it is.
    function pointerAt(x, y) {
        if (pointer === null)
            pointer = Qt.point(x, y);
        if (Math.hypot(x - pointer.x, y - pointer.y) < 2)
            return;
        pointer = Qt.point(x, y);
        const list = characters ? grid : view;
        const p = list.mapFromItem(null, x, y);
        if (!list.contains(p))
            return;
        const i = list.indexAt(p.x + list.contentX, p.y + list.contentY);
        if (i >= 0)
            list.currentIndex = i;
    }

    // ── Results ─────────────────────────────────────────────────────
    function refresh() {
        const text = search.text, q = text.trim().toLowerCase();
        let list = [];
        if (characters) {
            const terms = q.split(/\s+/).filter(t => t);
            const pool = Ui.launcherMode === "emoji" ? emoji : symbols;
            const scored = pool.map((c, i) => ({ c, i, score: Search.charScore(c, terms, picks[c.char]) })).filter(s => s.score > 0);
            scored.sort((a, b) => b.score - a.score || a.i - b.i);
            list = scored.map(s => ({ kind: "char", char: s.c }));
        } else if (clipboard) {
            list = clips.filter(c => !q || c.text.toLowerCase().includes(q)).map(c => ({ kind: "clip", clip: c }));
        } else if (text.startsWith(">")) {
            if (text.slice(1).trim())
                list = [{ kind: "run", command: text.slice(1).trim() }];
        } else {
            const sum = Search.calculate(text);
            if (sum !== null)
                list.push({ kind: "calc", value: sum });
            const scored = apps.map(e => ({ entry: e, score: Search.score(e, q, usage[e.id]) })).filter(s => s.score > 0);
            scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
            list = list.concat(scored.slice(0, 60).map(s => ({ kind: "app", entry: s.entry })));
            // Nothing runs unless asked for with `>`: a typo like "reboot" must not reboot.
        }
        results = list;
        view.currentIndex = 0;
        view.positionViewAtBeginning();
        grid.currentIndex = 0;
        grid.positionViewAtBeginning();
    }

    // ── Actions ─────────────────────────────────────────────────────
    function activate(index, alternate) {
        const item = results[index];
        if (!item)
            return;
        Ui.launcherOpen = false;
        if (item.kind === "app") {
            launch(item.entry);
        } else if (item.kind === "run") {
            Ui.spawn(alternate ? Ui.terminal(["bash", "-c", item.command], ["--hold"]) : ["bash", "-c", item.command]);
        } else if (item.kind === "calc") {
            Ui.spawn(["wl-copy", String(item.value)]);
        } else if (item.kind === "clip") {
            Ui.spawn(["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", item.clip.line]);
        } else if (item.kind === "char") {
            // Typed into the focused window once the launcher lets go of the keyboard, else copied.
            Ui.spawn(["bash", "-c",
                'if [ "$2" = type ] && command -v wtype >/dev/null; then sleep 0.15; printf "%s" "$1" | wtype -; else printf "%s" "$1" | wl-copy; fi',
                "_", item.char.char, alternate || !Ui.hasTyping ? "copy" : "type"]);
            picks = Object.assign({}, picks, { [item.char.char]: (picks[item.char.char] ?? 0) + 1 });
            picksFile.setText(JSON.stringify(picks));
        }
    }
    function launch(entry) {
        // Field codes (%u, %F…) stand for files and URLs; there are none to pass.
        const command = entry.command.filter(arg => !/^%[a-zA-Z]$/.test(arg));
        Ui.spawn({
            command: entry.runInTerminal ? Ui.terminal(command) : command,
            workingDirectory: entry.workingDirectory || Quickshell.env("HOME")
        });
        usage = Object.assign({}, usage, { [entry.id]: (usage[entry.id] ?? 0) + 1 });
        usageFile.setText(JSON.stringify(usage));
    }
    function forget(index) {
        const item = results[index];
        if (item?.kind !== "clip")
            return;
        Quickshell.execDetached(["bash", "-c", 'printf "%s" "$1" | cliphist delete', "_", item.clip.line]);
        clips = clips.filter(c => c !== item.clip);
        const keep = view.currentIndex;
        refresh();
        view.currentIndex = Math.min(keep, results.length - 1);
    }

    function gridKey(key) {
        const page = grid.columns * 4;
        if (key === Qt.Key_Left)
            grid.moveCurrentIndexLeft();
        else if (key === Qt.Key_Right)
            grid.moveCurrentIndexRight();
        else if (key === Qt.Key_Up)
            grid.moveCurrentIndexUp();
        else if (key === Qt.Key_Down)
            grid.moveCurrentIndexDown();
        else if (key === Qt.Key_PageDown)
            grid.currentIndex = Math.min(results.length - 1, grid.currentIndex + page);
        else if (key === Qt.Key_PageUp)
            grid.currentIndex = Math.max(0, grid.currentIndex - page);
        else
            return false;
        return true;
    }

    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/penumbra/launcher.json"
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text());
            } catch (e) {
                root.usage = {};
            }
        }
    }

    FileView {
        id: picksFile
        path: Quickshell.env("HOME") + "/.local/state/penumbra/characters.json"
        printErrors: false
        onLoaded: {
            try {
                root.picks = JSON.parse(text());
            } catch (e) {
                root.picks = {};
            }
        }
    }

    // Unicode's emoji list (the unicode-emoji package), one per line:
    // "1F600 ; fully-qualified # 😀 E1.0 grinning face", under "# group: …" headings.
    // Skin-tone variants are left out.
    FileView {
        path: root.charactersUsed ? "/usr/share/unicode/emoji/emoji-test.txt" : ""
        printErrors: false
        onLoaded: {
            let group = "";
            const list = [];
            for (const line of text().split("\n")) {
                if (line.startsWith("# group: ")) {
                    group = line.slice(9);
                    continue;
                }
                const m = line.match(/; fully-qualified\s+# (\S+) E[\d.]+ (.+)$/);
                if (m && !m[2].includes("skin tone"))
                    list.push({ char: m[1], name: m[2], group });
            }
            root.emoji = list;
            if (Ui.launcherOpen)
                root.refresh();
        }
    }

    // cliphist lists "id<TAB>preview", newest first; images preview as
    // "[[ binary data 52 KiB png 800x600 ]]".
    Process {
        id: clipList
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.clips = text.split("\n").filter(line => line.includes("\t")).map(line => {
                    const tab = line.indexOf("\t"), preview = line.slice(tab + 1);
                    const image = preview.match(/^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/);
                    return {
                        line,
                        id: line.slice(0, tab),
                        text: image ? `${image[2].toUpperCase()} image · ${image[3]}×${image[4]} · ${image[1]}` : preview.replace(/\s+/g, " ").trim(),
                        image: image ? image[2] : ""
                    };
                });
                root.refresh();
            }
        }
    }
    readonly property string thumbs: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/penumbra/clipboard"

    // ── Surface ─────────────────────────────────────────────────────
    // Faint enough that the glass rule leaves it unblurred; only the card is frosted.
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.scrim, 0.26)
        opacity: card.opacity
        MouseArea {
            anchors.fill: parent
            onClicked: Ui.launcherOpen = false
        }
    }

    Shadow { target: card }
    Rectangle {
        id: card
        width: 640
        x: (parent.width - width) / 2
        y: Math.round(parent.height * 0.17)
        implicitHeight: column.implicitHeight + 24
        height: implicitHeight
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.lineStrong
        clip: true
        opacity: Ui.launcherOpen ? 1 : 0
        scale: Ui.launcherOpen ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

        // Swallow clicks so they don't reach the backdrop.
        MouseArea { anchors.fill: parent }
        // Handlers hear hover even when a row's MouseArea takes it.
        HoverHandler {
            onPointChanged: if (hovered) root.pointerAt(point.scenePosition.x, point.scenePosition.y)
        }

        ColumnLayout {
            id: column
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            // Search field and mode switch.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.preferredHeight: 48
                spacing: 12
                Glyph {
                    text: root.clipboard || root.characters ? root.modes.find(m => m.mode === Ui.launcherMode).glyph : search.text.startsWith(">") ? "󰆍" : "󰍉"
                    size: 20
                    color: Theme.accentBright
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.text
                    selectionColor: Theme.accentDeep
                    selectedTextColor: Theme.text
                    font.family: Theme.sans
                    font.pixelSize: Theme.textTitle
                    clip: true
                    focus: true
                    onTextChanged: root.refresh()
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: ({ clipboard: "Search clipboard history…", emoji: "Search emoji…", symbols: "Search symbols…" })[Ui.launcherMode]
                            ?? "Search applications, > run, = calculate…"
                        font.pixelSize: Theme.textTitle
                        color: Theme.dim
                    }
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier;
                        if (event.key === Qt.Key_Escape) {
                            Ui.launcherOpen = false;
                        } else if (root.characters && root.gridKey(event.key)) {
                            // Arrows and pages move around the grid.
                        } else if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_N)) {
                            view.incrementCurrentIndex();
                        } else if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_P)) {
                            view.decrementCurrentIndex();
                        } else if (event.key === Qt.Key_PageDown) {
                            view.currentIndex = Math.min(root.results.length - 1, view.currentIndex + 6);
                        } else if (event.key === Qt.Key_PageUp) {
                            view.currentIndex = Math.max(0, view.currentIndex - 6);
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            const at = root.modes.findIndex(m => m.mode === Ui.launcherMode), step = event.key === Qt.Key_Tab ? 1 : -1;
                            Ui.launcherMode = root.modes[(at + step + root.modes.length) % root.modes.length].mode;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.characters ? grid.currentIndex : view.currentIndex, event.modifiers & Qt.ShiftModifier);
                        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            root.forget(view.currentIndex);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }
                // Only the current mode shows its name; the others are icons.
                Repeater {
                    model: root.modes
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: Ui.launcherMode === modelData.mode
                        implicitWidth: current ? modeRow.implicitWidth + 22 : 30
                        implicitHeight: 30
                        radius: Theme.corner(15)
                        color: current ? Theme.accent : modeArea.containsMouse ? Theme.hover : Theme.raised
                        border.color: current ? Theme.accentBright : Theme.line
                        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
                        RowLayout {
                            id: modeRow
                            anchors.centerIn: parent
                            spacing: 6
                            Glyph { text: modelData.glyph; size: 13; color: current ? Theme.onAccent : Theme.textSoft }
                            Label { visible: current; text: modelData.label; font.pixelSize: Theme.textSmall; font.weight: Font.DemiBold; color: current ? Theme.onAccent : Theme.text }
                        }
                        MouseArea {
                            id: modeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { Ui.launcherMode = modelData.mode; search.forceActiveFocus(); }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.line
            }

            ListView {
                id: view
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 7 * 56)
                visible: root.results.length > 0 && !root.characters
                clip: true
                spacing: 2
                model: root.characters ? [] : root.results
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.fast
                highlight: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.line
                    border.color: Theme.lineStrong
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool isImage: modelData.kind === "clip" && modelData.clip.image !== ""
                    width: ListView.view.width
                    implicitHeight: isImage ? 84 : 54

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activate(row.index, false)
                    }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
                        spacing: 14

                        // App icon, or a glyph for commands, sums and text clips.
                        Item {
                            visible: !row.isImage
                            implicitWidth: 32
                            implicitHeight: 32
                            IconImage {
                                anchors.fill: parent
                                visible: row.modelData.kind === "app"
                                source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                                asynchronous: true
                            }
                            // Picked colors (#rrggbb) show as a swatch.
                            Rectangle {
                                readonly property bool swatch: row.modelData.kind === "clip" && /^#[0-9a-fA-F]{6}$/.test(row.modelData.clip.text)
                                anchors.fill: parent
                                visible: row.modelData.kind !== "app"
                                radius: Theme.corner(10)
                                color: swatch ? row.modelData.clip.text : Theme.raised
                                border.color: swatch ? Theme.lineStrong : "transparent"
                                Glyph {
                                    anchors.centerIn: parent
                                    visible: !parent.swatch
                                    text: ({ run: "󰆍", calc: "󰃬", clip: "󰅍" })[row.modelData.kind] ?? ""
                                    size: 16
                                    color: Theme.accentBright
                                }
                            }
                        }

                        // Image clips show a thumbnail, decoded once into the runtime directory.
                        ClippingRectangle {
                            visible: row.isImage
                            implicitWidth: 112
                            implicitHeight: 68
                            radius: Theme.corner(10)
                            color: Theme.raised
                            Image {
                                id: thumb
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize: Qt.size(224, 136)
                            }
                            Process {
                                running: row.isImage
                                command: ["bash", "-c", 'f=$1; [ -s "$f" ] || { mkdir -p "${f%/*}"; printf "%s" "$2" | cliphist decode > "$f"; }',
                                    "_", `${root.thumbs}/${row.modelData.clip?.id}.${row.modelData.clip?.image}`, row.modelData.clip?.line ?? ""]
                                onExited: thumb.source = `file://${root.thumbs}/${row.modelData.clip.id}.${row.modelData.clip.image}`
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: {
                                    const m = row.modelData;
                                    if (m.kind === "app")
                                        return m.entry.name;
                                    if (m.kind === "run")
                                        return m.command;
                                    if (m.kind === "calc")
                                        return "= " + m.value;
                                    return m.clip.text;
                                }
                                font.pixelSize: row.modelData.kind === "calc" ? 17 : 13
                                font.family: row.modelData.kind === "run" || row.modelData.kind === "calc" ? Theme.mono : Theme.sans
                                font.weight: row.current ? Font.DemiBold : Font.Normal
                                color: row.modelData.kind === "calc" ? Theme.accentBright : Theme.text
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: {
                                    const m = row.modelData;
                                    if (m.kind === "app")
                                        return m.entry.genericName || m.entry.comment;
                                    if (m.kind === "run")
                                        return "Run command · Shift+Enter in a terminal";
                                    if (m.kind === "calc")
                                        return "Enter copies the result";
                                    return "";
                                }
                                font.pixelSize: Theme.textSmall
                                color: Theme.muted
                            }
                        }

                        Glyph {
                            visible: row.current
                            text: "󰌑"
                            size: 14
                            color: Theme.accent
                        }
                    }
                }
            }

            GridView {
                id: grid
                readonly property int columns: 10
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.ceil(count / columns), 5) * cellHeight
                visible: root.results.length > 0 && root.characters
                clip: true
                cellWidth: Math.floor(width / columns)
                cellHeight: 56
                model: root.characters ? root.results : []
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: Theme.fast
                highlight: Rectangle {
                    radius: Theme.radiusSmall
                    color: Theme.line
                    border.color: Theme.lineStrong
                }
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.char?.char ?? ""
                        font.family: Ui.launcherMode === "emoji" ? "Noto Color Emoji" : Theme.sans
                        font.pixelSize: Ui.launcherMode === "emoji" ? 28 : 24
                        color: Theme.text
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => root.activate(cell.index, mouse.modifiers & Qt.ShiftModifier)
                    }
                }
            }

            // The chosen character's name.
            RowLayout {
                readonly property var current: root.characters ? root.results[grid.currentIndex]?.char : null
                Layout.fillWidth: true
                Layout.leftMargin: 10
                visible: !!current
                spacing: 10
                Label {
                    text: parent.current?.name ?? ""
                    font.pixelSize: Theme.textMedium
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: 420
                }
                Label {
                    Layout.fillWidth: true
                    text: parent.current?.group ?? ""
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Layout.bottomMargin: 10
                visible: root.results.length === 0
                spacing: 4
                Glyph {
                    Layout.fillWidth: true
                    text: root.clipboard || root.characters ? root.modes.find(m => m.mode === Ui.launcherMode).glyph : "󰍉"
                    size: 26
                    color: Theme.dim
                }
                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (root.clipboard)
                            return search.text ? "Nothing copied matches" : "Nothing copied yet";
                        if (Ui.launcherMode === "emoji" && root.emoji.length === 0)
                            return "Install the unicode-emoji package for the emoji list";
                        if (root.characters)
                            return "Nothing matches";
                        if (search.text.trim() && !search.text.startsWith(">"))
                            return "No application matches · start with > to run it as a command";
                        return "Type to search";
                    }
                    color: Theme.muted
                }
            }

            // Hints, and clearing the clipboard.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                Label {
                    Layout.fillWidth: true
                    text: {
                        if (root.clipboard)
                            return "↑↓ choose · Enter copy · Shift+Del forget · Tab emoji · Esc close";
                        if (root.characters)
                            return (Ui.hasTyping ? "Arrows choose · Enter type · Shift+Enter copy" : "Arrows choose · Enter copy")
                                + (Ui.launcherMode === "emoji" ? " · Tab symbols" : " · Tab apps") + " · Esc close";
                        return "↑↓ choose · Enter open · Tab clipboard · Esc close";
                    }
                    font.pixelSize: Theme.textSmall
                    color: Theme.dim
                }
                PillButton {
                    visible: root.clipboard && root.clips.length > 0
                    text: "Clear history"
                    danger: true
                    onClicked: {
                        Ui.launcherOpen = false;
                        Ui.run(Ui.bin + "penumbra-clipboard clear");
                    }
                }
            }
        }
    }
    GlassEdge {
        anchors.fill: card
        radius: card.radius
        opacity: card.opacity
        scale: card.scale
    }
}
