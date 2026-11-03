import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "search.js" as Search
import "symbols.js" as Symbols

// Applications, open windows, clipboard history, emoji and symbols, over a dimmed screen. Type to
// search; `>` runs a command, `?` searches the web, `/` finds files; a sum (or `=`), "10 km in mi"
// or "100 usd in eur" is worked out and copied. Tab moves to the next mode.
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
        { mode: "windows", label: "Windows", glyph: "󰖯" },
        { mode: "clipboard", label: "Clipboard", glyph: "󰅍" },
        { mode: "emoji", label: "Emoji", glyph: "󰇵" },
        { mode: "symbols", label: "Symbols", glyph: "󰒠" }
    ]
    readonly property bool clipboard: Ui.launcherMode === "clipboard"
    readonly property bool windows: Ui.launcherMode === "windows"
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
    readonly property var selectedResult: results[view.currentIndex] ?? null
    readonly property bool showPreview: width >= 1080 && !characters
        && ["app", "action", "window", "clip", "pin"].includes(selectedResult?.kind)
    property var readyThumbs: ({})
    property var clips: []
    property var usage: ({}) // desktop entry id → { score, at } (frecency, see search.js)
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
            loadClips();
        refresh();
    }
    function loadClips() {
        if (Settings.clipboardDays > 0) {
            prune.running = true; // lists the clips once it has expired the old ones
        } else {
            clipList.running = true;
        }
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
            // Pinned texts first; Clear history leaves them.
            list = Settings.clipboardPins.filter(t => !q || t.toLowerCase().includes(q)).map(t => ({ kind: "pin", text: t }))
                .concat(clips.filter(c => !q || c.text.toLowerCase().includes(q)).map(c => ({ kind: "clip", clip: c })));
        } else if (windows) {
            const open = ToplevelManager.toplevels.values.filter(t => !q || (t.title + " " + t.appId).toLowerCase().includes(q));
            list = open.map(t => ({ kind: "window", toplevel: t, entry: DesktopEntries.heuristicLookup(t.appId) }));
        } else if (text.startsWith(">")) {
            if (text.slice(1).trim())
                list = [{ kind: "run", command: text.slice(1).trim() }];
        } else if (text.startsWith("?")) {
            if (text.slice(1).trim())
                list = [{ kind: "web", query: text.slice(1).trim() }];
        } else if (text.startsWith("/")) {
            list = files; // findFiles fills them in as you type
        } else {
            const sum = Search.calculate(text);
            if (sum !== null)
                list.push({ kind: "calc", value: sum });
            const units = Search.convert(text);
            if (units)
                list.push({ kind: "convert", value: units.value, unit: units.unit });
            const money = Search.currency(text);
            if (money) {
                const answer = exchange(money);
                if (answer)
                    list.push(answer);
            }
            const now = Date.now();
            const scored = apps.map(e => ({ entry: e, score: Search.score(e, q, Search.frecency(usage[e.id], now)) })).filter(s => s.score > 0);
            // Desktop actions ("New Private Window") join in when the query names them.
            for (const e of apps)
                for (const a of e.actions ?? []) {
                    const score = Search.actionScore(e.name, a.name, q);
                    if (score)
                        scored.push({ entry: e, action: a, score: score + Search.boost(Search.frecency(usage[e.id], now)) });
                }
            scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
            list = list.concat(scored.slice(0, 60).map(s => s.action ? { kind: "action", entry: s.entry, action: s.action } : { kind: "app", entry: s.entry }));
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
        } else if (item.kind === "action") {
            const command = item.action.command.filter(arg => !/^%[a-zA-Z]$/.test(arg));
            Ui.spawn({ command, workingDirectory: item.entry.workingDirectory || Quickshell.env("HOME") });
            usage = Object.assign({}, usage, { [item.entry.id]: Search.launched(usage[item.entry.id], Date.now()) });
            usageFile.setText(JSON.stringify(usage));
        } else if (item.kind === "window") {
            item.toplevel.activate();
        } else if (item.kind === "web") {
            Ui.spawn(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(item.query)]);
        } else if (item.kind === "file") {
            // Shift+Enter opens the folder it is in.
            Ui.spawn(["xdg-open", alternate ? item.path.replace(/\/[^/]*$/, "") || "/" : item.path]);
        } else if (item.kind === "calc" || item.kind === "convert" || item.kind === "currency" && !item.pending) {
            Ui.spawn(["wl-copy", String(item.value)]);
        } else if (item.kind === "pin") {
            Ui.spawn(["wl-copy", "--", item.text]);
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
        usage = Object.assign({}, usage, { [entry.id]: Search.launched(usage[entry.id], Date.now()) });
        usageFile.setText(JSON.stringify(usage));
    }
    function forget(index) {
        const item = results[index];
        if (item?.kind === "pin") {
            Settings.clipboardPins = Settings.clipboardPins.filter(t => t !== item.text);
        } else if (item?.kind === "clip") {
            Quickshell.execDetached(["bash", "-c", 'printf "%s" "$1" | cliphist delete', "_", item.clip.line]);
            clips = clips.filter(c => c !== item.clip);
        } else {
            return;
        }
        const keep = view.currentIndex;
        refresh();
        view.currentIndex = Math.min(keep, results.length - 1);
    }

    // Alt+P pins a text clip (the whole text: cliphist's list only has a preview) or unpins a pin.
    function togglePin(index) {
        const item = results[index];
        if (item?.kind === "pin") {
            forget(index);
        } else if (item?.kind === "clip" && !item.clip.image) {
            pinner.command = ["bash", "-c", 'printf "%s" "$1" | cliphist decode', "_", item.clip.line];
            pinner.running = true;
        }
    }
    Process {
        id: pinner
        stdout: StdioCollector {
            onStreamFinished: {
                if (text && !Settings.clipboardPins.includes(text))
                    Settings.clipboardPins = [text, ...Settings.clipboardPins];
                root.refresh();
            }
        }
    }

    // Files for `/name`: fd when it is installed (it skips hidden and ignored files), else find,
    // in the home folder; asked again a moment after typing stops.
    property var files: []
    Timer {
        id: findFiles
        interval: 150
        onTriggered: {
            const name = search.text.slice(1).trim();
            fileSearch.running = false;
            if (!name) {
                root.files = [];
                root.refresh();
                return;
            }
            fileSearch.command = ["bash", "-c",
                'cd "$HOME" && if command -v fd >/dev/null; then fd -i --absolute-path --max-results 40 -- "$1"; '
                + 'else find "$HOME" -mindepth 1 -name ".*" -prune -o -iname "*$1*" -print 2>/dev/null | head -n 40; fi', "_", name];
            fileSearch.running = true;
        }
    }
    Process {
        id: fileSearch
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(l => l).map(path => ({ kind: "file", path: path.replace(/\/$/, "") }));
                if (search.text.startsWith("/"))
                    root.refresh();
            }
        }
    }

    // Exchange rates from the European Central Bank (frankfurter.dev), asked for only when a
    // query names two currencies and kept for 12 hours.
    property var rates: ({}) // base → { rates, date, at }
    function exchange(money) {
        const known = rates[money.from];
        if (!known || Date.now() - known.at > 12 * 3600000) {
            if (!rateFetch.running) {
                rateFetch.base = money.from;
                rateFetch.command = ["curl", "-sfL", "--max-time", "5", "https://api.frankfurter.dev/v1/latest?base=" + money.from];
                rateFetch.running = true;
            }
            return known ? null : { kind: "currency", pending: true, value: "", text: `${money.amount} ${money.from} in ${money.to}` };
        }
        const rate = known.rates[money.to];
        if (!rate)
            return null;
        const value = Number((money.amount * rate).toFixed(rate * money.amount >= 100 ? 2 : 4));
        return { kind: "currency", value, text: `${value} ${money.to}`, date: known.date, from: money };
    }
    Process {
        id: rateFetch
        property string base: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (data.rates)
                        root.rates = Object.assign({}, root.rates, { [rateFetch.base]: { rates: data.rates, date: data.date, at: Date.now() } });
                } catch (e) {
                    root.rates = Object.assign({}, root.rates, { [rateFetch.base]: { rates: {}, date: "", at: Date.now() } });
                }
                if (Ui.launcherOpen)
                    root.refresh();
            }
        }
    }

    // Clipboard history older than Settings → Clipboard history goes, every hour and before the
    // clipboard opens.
    Process {
        id: prune
        command: [Ui.bin + "penumbra-clipboard", "prune", String(Settings.clipboardDays)]
        onExited: if (Ui.launcherOpen && root.clipboard) clipList.running = true
    }
    Timer {
        interval: 3600000
        running: Settings.clipboardDays > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!prune.running) prune.running = true
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
        width: root.showPreview ? 960 : Math.min(640, root.width - 32)
        x: (parent.width - width) / 2
        y: Math.min(100, Math.round(parent.height * 0.12))
        implicitHeight: Math.max(root.showPreview ? 370 : 0, column.implicitHeight + 24)
        height: implicitHeight
        radius: Theme.radiusLarge
        color: Theme.panel
        border.color: Theme.lineStrong
        clip: true
        opacity: Ui.launcherOpen ? 1 : 0
        scale: Ui.launcherOpen ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

        LauncherPreview {
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom; margins: 12 }
            width: 304
            visible: root.showPreview
            active: visible && Ui.launcherOpen
            result: root.selectedResult
            clipImage: root.selectedResult?.kind === "clip" ? root.readyThumbs[root.selectedResult.clip.id] ?? "" : ""
        }

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
            width: root.showPreview ? 616 : parent.width - 24
            spacing: 8

            // Search field and mode switch.
            RowLayout {
                StaggerReveal { shown: Ui.launcherOpen; order: 0 }
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.preferredHeight: 48
                spacing: 12
                Glyph {
                    text: Ui.launcherMode !== "apps" ? root.modes.find(m => m.mode === Ui.launcherMode).glyph
                        : search.text.startsWith(">") ? "󰆍" : search.text.startsWith("?") ? "󰖟" : search.text.startsWith("/") ? "󰈞" : "󰍉"
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
                    onTextChanged: {
                        root.refresh();
                        if (text.startsWith("/") && Ui.launcherMode === "apps")
                            findFiles.restart();
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !search.text
                        text: ({ windows: "Search open windows…", clipboard: "Search clipboard history…", emoji: "Search emoji…", symbols: "Search symbols…" })[Ui.launcherMode]
                            ?? "Search apps, > run, ? web, / files, = calculate…"
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
                        } else if (root.clipboard && event.key === Qt.Key_P && (event.modifiers & Qt.AltModifier)) {
                            root.togglePin(view.currentIndex);
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
                            Glyph { text: modelData.glyph; size: 13; color: current ? Theme.accentInk : Theme.textSoft }
                            Label { visible: current; text: modelData.label; font.pixelSize: Theme.textSmall; font.weight: Font.DemiBold; color: current ? Theme.accentInk : Theme.text }
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
                Layout.preferredHeight: Math.min(contentHeight, 7 * 64, Math.max(64, root.height - card.y - 210 * Theme.textScale))
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
                    StaggerReveal { shown: Ui.launcherOpen; order: 1 + row.index }
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    readonly property bool isImage: modelData.kind === "clip" && modelData.clip.image !== ""
                    width: ListView.view.width
                    implicitHeight: isImage ? 84 : Math.max(60, Theme.textMedium + Theme.textSmall + 26)

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
                            readonly property bool hasIcon: ["app", "action", "window"].includes(row.modelData.kind)
                            AppIcon {
                                anchors.fill: parent
                                visible: parent.hasIcon
                                icon: parent.hasIcon ? row.modelData.action?.icon || row.modelData.entry?.icon || row.modelData.toplevel?.appId || "" : ""
                                asynchronous: true
                            }
                            // Picked colors (#rrggbb) show as a swatch.
                            Rectangle {
                                readonly property bool swatch: row.modelData.kind === "clip" && /^#[0-9a-fA-F]{6}$/.test(row.modelData.clip.text)
                                anchors.fill: parent
                                visible: !parent.hasIcon
                                radius: Theme.corner(10)
                                color: swatch ? row.modelData.clip.text : Theme.raised
                                border.color: swatch ? Theme.lineStrong : "transparent"
                                Glyph {
                                    anchors.centerIn: parent
                                    visible: !parent.swatch
                                    text: ({ run: "󰆍", calc: "󰃬", clip: "󰅍", pin: "󰐃", web: "󰖟", file: "󰈔", convert: "󰁔", currency: "󰄉" })[row.modelData.kind] ?? ""
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
                                onExited: exitCode => {
                                    if (exitCode !== 0) return;
                                    const source = Ui.fileUrl(`${root.thumbs}/${row.modelData.clip.id}.${row.modelData.clip.image}`);
                                    thumb.source = source;
                                    root.readyThumbs = Object.assign({}, root.readyThumbs, { [row.modelData.clip.id]: source });
                                }
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
                                    if (m.kind === "convert")
                                        return `= ${m.value} ${m.unit}`;
                                    if (m.kind === "currency")
                                        return m.pending ? m.text : "≈ " + m.text;
                                    if (m.kind === "action")
                                        return m.action.name;
                                    if (m.kind === "window")
                                        return m.toplevel.title || m.toplevel.appId;
                                    if (m.kind === "web")
                                        return m.query;
                                    if (m.kind === "file")
                                        return m.path.replace(/^.*\//, "");
                                    if (m.kind === "pin")
                                        return m.text.replace(/\s+/g, " ").trim();
                                    return m.clip.text;
                                }
                                readonly property bool answer: ["calc", "convert", "currency"].includes(row.modelData.kind)
                                font.pixelSize: answer ? Theme.textTitle - 1 : Theme.textMedium
                                font.family: row.modelData.kind === "run" || answer ? Theme.mono : Theme.sans
                                font.weight: row.current ? Font.DemiBold : Font.Normal
                                color: answer ? Theme.accentBright : Theme.text
                                elide: Text.ElideRight
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
                                    if (m.kind === "calc" || m.kind === "convert")
                                        return "Enter copies the result";
                                    if (m.kind === "currency")
                                        return m.pending ? "Asking the European Central Bank for today's rate…" : `${m.from.amount} ${m.from.from} · ECB rate of ${m.date} · Enter copies`;
                                    if (m.kind === "action")
                                        return m.entry.name;
                                    if (m.kind === "window")
                                        return (m.entry?.name || m.toplevel.appId) + (m.toplevel.activated ? " · focused" : "");
                                    if (m.kind === "web")
                                        return "Search the web · DuckDuckGo in your browser";
                                    if (m.kind === "file")
                                        return m.path.replace(Quickshell.env("HOME"), "~").replace(/\/[^/]*$/, "") + " · Shift+Enter opens the folder";
                                    if (m.kind === "pin")
                                        return "Pinned · Alt+P unpins";
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
                Layout.preferredHeight: Math.min(Math.min(Math.ceil(count / columns), 5) * cellHeight, Math.max(cellHeight, root.height - card.y - 210 * Theme.textScale))
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
                    StaggerReveal { shown: Ui.launcherOpen; order: 1 + Math.floor(cell.index / grid.columns) }
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
                        if (root.windows)
                            return search.text ? "No open window matches" : "No windows are open";
                        if (search.text.startsWith("/"))
                            return search.text.slice(1).trim() ? (fileSearch.running || findFiles.running ? "Looking…" : "No file in your home folder matches") : "Type part of a file or folder name";
                        if (search.text.trim() && !search.text.startsWith(">") && !search.text.startsWith("?"))
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
                            return "↑↓ choose · Enter copy · Alt+P pin · Shift+Del forget · Tab emoji · Esc close";
                        if (root.windows)
                            return "↑↓ choose · Enter go to the window · Tab clipboard · Esc close";
                        if (root.characters)
                            return (Ui.hasTyping ? "Arrows choose · Enter type · Shift+Enter copy" : "Arrows choose · Enter copy")
                                + (Ui.launcherMode === "emoji" ? " · Tab symbols" : " · Tab apps") + " · Esc close";
                        return "↑↓ choose · Enter open · Tab windows · Esc close";
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
