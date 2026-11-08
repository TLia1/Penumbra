import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: root
    spacing: 10
    property var packages: []
    property var byKey: ({})
    property string error: ""
    property string source: "all"
    property string roleFilter: "all"
    property string sortBy: "name"
    property string selected: ""
    property string showRawDetails: ""
    property string confirmRemove: ""
    property var history: []
    property bool navigating: false
    property int page: 0
    readonly property int pageSize: 25

    onPackagesChanged: {
        const map = {};
        for (const p of packages)
            map[p.key] = p;
        byKey = map;
    }

    function matchesFilters(p, src, role, queryText) {
        if (src !== "all" && p.source !== src)
            return false;
        if (role === "explicit" && p.explicit === false)
            return false;
        if (role === "leaves" && (p.required_by_links ?? []).length > 0)
            return false;
        if (queryText !== "") {
            const haystack = [p.name, p.target, p.description, p.provides ?? "", p.groups ?? ""].join(" ").toLowerCase();
            if (!queryText.split(/\s+/).every(q => haystack.includes(q)))
                return false;
        }
        return true;
    }

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: {
        const filtered = packages.filter(p => matchesFilters(p, source, roleFilter, query));
        if (sortBy === "size")
            return filtered.slice().sort((a, b) => ((b.size_bytes ?? 0) - (a.size_bytes ?? 0)) || a.name.localeCompare(b.name));
        return filtered;
    }
    readonly property var shown: matches.slice(page * pageSize, (page + 1) * pageSize)

    onMatchesChanged: {
        if (navigating)
            return;
        page = 0;
        selected = "";
        confirmRemove = "";
        showRawDetails = "";
    }
    Component.onCompleted: refresh()

    function refresh() {
        if (scan.running) return;
        error = "";
        scan.command = [Ui.bin + "penumbra-packages", "list", "--appimage-directory", imageFolder.text.trim()];
        scan.running = true;
    }
    function manage(item, action) {
        confirmRemove = "";
        Ui.spawn(Ui.terminal([Ui.bin + "penumbra-packages", "manage", action, item.key,
                             "--appimage-directory", imageFolder.text.trim()],
                            ["--title", "Penumbra · Packages"]));
    }
    function sourceName(value) {
        return ({pacman: "pacman", aur: "AUR", flatpak: "Flatpak", appimage: "AppImage"})[value] || value;
    }
    function sourceGlyph(value) {
        return ({pacman: "󰏗", aur: "󰣇", flatpak: "󰏖", appimage: "󰀻"})[value] || "󰏗";
    }
    function relationshipSummary(item) {
        if (item.source === "appimage")
            return "Standalone file";
        const deps = (item.dependency_links ?? []).length;
        const reqs = (item.required_by_links ?? []).length;
        const depText = deps === 0 ? "no deps" : `${deps} ${deps === 1 ? "dep" : "deps"}`;
        const reqText = reqs === 0 ? "unused by others" : `needed by ${reqs}`;
        return `${depText} · ${reqText}`;
    }

    function jumpTo(targetKey, fromPkg) {
        const target = byKey[targetKey];
        if (!target)
            return;
        if (fromPkg && fromPkg.key && fromPkg.key !== targetKey) {
            const nextHistory = history.slice();
            nextHistory.push({
                key: fromPkg.key,
                name: fromPkg.name,
                source: root.source,
                roleFilter: root.roleFilter,
                sortBy: root.sortBy,
                query: search.text,
                page: root.page
            });
            history = nextHistory;
        }
        navigating = true;
        if (!matchesFilters(target, root.source, root.roleFilter, root.query)) {
            if (root.query !== "" && !matchesFilters(target, "all", "all", root.query))
                search.text = "";
            if (root.source !== "all" && target.source !== root.source)
                root.source = "all";
            if (root.roleFilter !== "all" && !matchesFilters(target, root.source, root.roleFilter, ""))
                root.roleFilter = "all";
        }
        const idx = root.matches.findIndex(p => p.key === targetKey);
        if (idx >= 0)
            root.page = Math.floor(idx / root.pageSize);
        root.selected = targetKey;
        root.confirmRemove = "";
        root.showRawDetails = "";
        navigating = false;
    }

    function goBack() {
        if (history.length === 0)
            return;
        const nextHistory = history.slice();
        const prev = nextHistory.pop();
        history = nextHistory;
        navigating = true;
        root.source = prev.source;
        root.roleFilter = prev.roleFilter;
        root.sortBy = prev.sortBy;
        search.text = prev.query;
        const idx = root.matches.findIndex(p => p.key === prev.key);
        root.page = idx >= 0 ? Math.floor(idx / root.pageSize) : prev.page;
        root.selected = prev.key;
        root.confirmRemove = "";
        root.showRawDetails = "";
        navigating = false;
    }

    // Small filter/sort chip used in the toolbar.
    component FilterChip: Rectangle {
        id: chip
        property string text
        property string glyph: ""
        property bool active: false
        signal clicked()

        implicitWidth: chipRow.implicitWidth + 14
        implicitHeight: 28
        radius: Theme.corner(14)
        color: active ? Theme.alpha(Theme.accent, 0.2) : chipArea.containsMouse ? Theme.hover : Theme.control
        border.color: active ? Theme.accent : Theme.line
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            Glyph {
                visible: chip.glyph !== ""
                text: chip.glyph
                size: 12
                color: chip.active ? Theme.accentBright : Theme.textSoft
            }
            Label {
                text: chip.text
                font.pixelSize: Theme.textTiny
                font.weight: chip.active ? Font.DemiBold : Font.Normal
                color: chip.active ? Theme.accentBright : Theme.textSoft
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // Clickable package chip for dependencies and reverse dependencies.
    component PackageLinkChip: Rectangle {
        id: linkChip
        property string label
        property string targetKey: ""
        property bool installed: true
        property string sublabel: ""
        property int maxWidth: 340
        signal activated(string key)

        readonly property bool clickable: installed && targetKey !== "" && !!root.byKey[targetKey]
        readonly property string fullText: label + (sublabel ? ` · ${sublabel}` : "")
        implicitWidth: Math.min(maxWidth, linkRow.implicitWidth + 20)
        implicitHeight: 28
        radius: Theme.corner(14)
        color: clickable
            ? (linkArea.containsMouse ? Theme.alpha(Theme.accent, 0.24) : Theme.control)
            : Theme.alpha(Theme.control, 0.5)
        border.color: clickable
            ? (linkArea.containsMouse ? Theme.accentBright : Theme.alpha(Theme.accent, 0.4))
            : Theme.line
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

        RowLayout {
            id: linkRow
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 5
            Glyph {
                id: linkGlyph
                text: linkChip.clickable ? "󰏗" : "󰅙"
                size: 11
                color: linkChip.clickable ? (linkArea.containsMouse ? Theme.accentBright : Theme.accent) : Theme.dim
            }
            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Math.max(60, linkChip.maxWidth - (linkChip.clickable ? 48 : 34))
                text: linkChip.fullText
                elide: Text.ElideRight
                font.pixelSize: Theme.textSmall
                font.weight: linkChip.clickable ? Font.Medium : Font.Normal
                color: linkChip.clickable ? (linkArea.containsMouse ? Theme.accentBright : Theme.text) : Theme.muted
            }
            Glyph {
                id: linkArrow
                visible: linkChip.clickable
                text: "󰁔"
                size: 10
                color: linkArea.containsMouse ? Theme.accentBright : Theme.dim
            }
        }
        MouseArea {
            id: linkArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: linkChip.clickable
            cursorShape: linkChip.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: linkChip.activated(linkChip.targetKey)
        }
    }

    Process {
        id: scan
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: code => {
            if (code !== 0) { root.error = errors.text.trim() || "Could not load packages. Try Refresh."; return; }
            try {
                const data = JSON.parse(output.text);
                root.packages = data.packages;
                root.error = data.errors.join("\n");
            } catch (e) { root.error = "Could not read the package list. Try Refresh."; }
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Installed packages"
        status: scan.running ? "Reading installed software…" : `${root.packages.length} installed · ${root.matches.length} shown`
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // Search field with quick clear button.
    Item {
        Layout.fillWidth: true
        implicitHeight: search.implicitHeight
        Field {
            id: search
            anchors.fill: parent
            rightPadding: clearSearch.visible ? 32 : 12
            placeholderText: "Search names, descriptions or provides…"
            Keys.onEscapePressed: event => {
                if (text !== "") {
                    text = "";
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
        }
        Rectangle {
            id: clearSearch
            visible: search.text !== ""
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            width: 22
            height: 22
            radius: Theme.corner(11)
            color: clearArea.containsMouse ? Theme.hover : "transparent"
            Glyph { anchors.centerIn: parent; text: "󰅖"; size: 12; color: Theme.muted }
            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: search.text = ""
            }
        }
    }

    Segmented {
        Layout.fillWidth: true
        current: root.source
        options: [{value: "all", title: "All"}, {value: "pacman", title: "pacman"},
                  {value: "aur", title: "AUR"}, {value: "flatpak", title: "Flatpak"},
                  {value: "appimage", title: "AppImage"}]
        onChosen: value => root.source = value
    }

    // Filter by install role + sort + quick actions (Flow wraps cleanly and never overflows).
    Flow {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        spacing: 6
        FilterChip {
            text: "All"
            active: root.roleFilter === "all"
            onClicked: root.roleFilter = "all"
        }
        FilterChip {
            text: "Explicit"
            glyph: "󰄬"
            active: root.roleFilter === "explicit"
            onClicked: root.roleFilter = root.roleFilter === "explicit" ? "all" : "explicit"
        }
        FilterChip {
            text: "Top-level"
            glyph: "󰌪"
            active: root.roleFilter === "leaves"
            onClicked: root.roleFilter = root.roleFilter === "leaves" ? "all" : "leaves"
        }
        FilterChip {
            text: root.sortBy === "size" ? "Size ↓" : "A–Z"
            glyph: "󰒺"
            active: root.sortBy === "size"
            onClicked: root.sortBy = root.sortBy === "size" ? "name" : "size"
        }
        FilterChip {
            text: "Refresh"
            glyph: "󰑐"
            onClicked: root.refresh()
        }
        FilterChip {
            text: "Updates"
            glyph: "󰚰"
            onClicked: Ui.spawn([Ui.bin + "penumbra-updates", "open"])
        }
    }

    // Breadcrumb trail when jumping across dependencies / reverse dependencies.
    Rectangle {
        Layout.fillWidth: true
        visible: root.history.length > 0
        implicitHeight: navRow.implicitHeight + 14
        radius: Theme.radiusSmall
        color: Theme.alpha(Theme.accent, 0.12)
        border.color: Theme.alpha(Theme.accent, 0.35)

        RowLayout {
            id: navRow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 10; rightMargin: 10; topMargin: 7 }
            spacing: 8

            Rectangle {
                implicitWidth: Math.min(200, backRow.implicitWidth + 14)
                implicitHeight: 24
                radius: Theme.corner(12)
                color: navBackArea.containsMouse ? Theme.accent : Theme.control
                border.color: Theme.accent
                RowLayout {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 4
                    Glyph {
                        text: "󰁍"
                        size: 11
                        color: navBackArea.containsMouse ? Theme.accentInk : Theme.accentBright
                    }
                    Label {
                        text: root.history.length > 0 ? `Back to ${root.history[root.history.length - 1].name}` : "Back"
                        elide: Text.ElideRight
                        Layout.maximumWidth: 165
                        font.pixelSize: Theme.textTiny
                        font.weight: Font.DemiBold
                        color: navBackArea.containsMouse ? Theme.accentInk : Theme.accentBright
                    }
                }
                MouseArea {
                    id: navBackArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goBack()
                }
            }

            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                text: root.history.map(h => h.name).concat(root.byKey[root.selected] ? [root.byKey[root.selected].name] : []).join(" → ")
                elide: Text.ElideLeft
                font.pixelSize: Theme.textTiny
                color: Theme.textSoft
            }

            Glyph {
                text: "󰅖"
                size: 12
                color: clearHistoryArea.containsMouse ? Theme.text : Theme.muted
                MouseArea {
                    id: clearHistoryArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.history = []
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        visible: root.source === "appimage"
        spacing: 6
        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            text: "Scanned folders: Applications, AppImages, Downloads, Desktop, ~/.local/bin, ~/.local/share/AppImage, /opt and /usr/local/bin."
            wrapMode: Text.Wrap
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
        Field {
            id: imageFolder
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            placeholderText: "Additional AppImage folder (optional, press Enter to scan)"
            onAccepted: root.refresh()
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        visible: root.error !== ""
        text: root.error
        wrapMode: Text.Wrap
        color: Theme.amber
    }

    Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        visible: !scan.running && root.matches.length === 0
        text: "No installed packages match this filter."
        wrapMode: Text.Wrap
        color: Theme.muted
    }

    // Top pagination bar when there are multiple pages.
    RowLayout {
        Layout.fillWidth: true
        visible: root.matches.length > root.pageSize
        spacing: 8
        PillButton {
            text: "Previous"
            available: root.page > 0
            onClicked: { root.page--; root.selected = ""; }
        }
        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.textSmall
            color: Theme.muted
            text: `Page ${root.page + 1} of ${Math.ceil(root.matches.length / root.pageSize)}`
        }
        PillButton {
            text: "Next"
            available: (root.page + 1) * root.pageSize < root.matches.length
            onClicked: { root.page++; root.selected = ""; }
        }
    }

    // Package list.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredWidth: 0
        spacing: 4

        Repeater {
            model: root.shown
            delegate: Rectangle {
                id: packageCard
                required property var modelData
                readonly property bool expanded: root.selected === modelData.key
                readonly property var depLinks: modelData.dependency_links ?? []
                readonly property var reqLinks: modelData.required_by_links ?? []
                readonly property var optDepLinks: modelData.optional_dependency_links ?? []
                readonly property var optForLinks: modelData.optional_for_links ?? []

                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                implicitHeight: cardColumn.implicitHeight + 18
                radius: Theme.radiusSmall
                color: expanded ? Theme.raised : headerMouse.containsMouse ? Theme.hover : "transparent"
                border.color: expanded ? Theme.lineStrong : "transparent"
                Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
                Behavior on implicitHeight { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                clip: true

                ColumnLayout {
                    id: cardColumn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9; leftMargin: 10; rightMargin: 10 }
                    spacing: 10

                    // Clickable header row to expand/collapse the package.
                    Item {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        implicitHeight: headerRow.implicitHeight

                        MouseArea {
                            id: headerMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selected = packageCard.expanded ? "" : packageCard.modelData.key;
                                root.confirmRemove = "";
                                root.showRawDetails = "";
                            }
                        }

                        RowLayout {
                            id: headerRow
                            width: parent.width
                            spacing: 10

                            Rectangle {
                                implicitWidth: 32
                                implicitHeight: 32
                                radius: Theme.corner(10)
                                color: packageCard.expanded ? Theme.alpha(Theme.accent, 0.2) : Theme.control
                                border.color: packageCard.expanded ? Theme.alpha(Theme.accent, 0.5) : Theme.line
                                Glyph {
                                    anchors.centerIn: parent
                                    text: root.sourceGlyph(packageCard.modelData.source)
                                    size: 16
                                    color: packageCard.expanded ? Theme.accentBright : Theme.textSoft
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Label {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredWidth: 0
                                        text: packageCard.modelData.name
                                        elide: Text.ElideRight
                                        font.weight: packageCard.expanded ? Font.DemiBold : Font.Medium
                                        color: packageCard.expanded ? Theme.accentBright : Theme.text
                                    }
                                    Rectangle {
                                        visible: packageCard.modelData.explicit === false
                                        implicitWidth: depBadgeLabel.implicitWidth + 10
                                        implicitHeight: 18
                                        radius: Theme.corner(9)
                                        color: Theme.control
                                        border.color: Theme.line
                                        Label {
                                            id: depBadgeLabel
                                            anchors.centerIn: parent
                                            text: "dep"
                                            font.pixelSize: Theme.textTiny
                                            color: Theme.muted
                                        }
                                    }
                                    Label {
                                        visible: (packageCard.modelData.size ?? "") !== ""
                                        text: packageCard.modelData.size
                                        font.pixelSize: Theme.textTiny
                                        color: Theme.muted
                                    }
                                }

                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    visible: (packageCard.modelData.description ?? "") !== "" && !packageCard.expanded
                                    text: packageCard.modelData.description
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.textSmall
                                    color: Theme.textSoft
                                }

                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: [
                                        root.sourceName(packageCard.modelData.source),
                                        packageCard.modelData.version,
                                        root.relationshipSummary(packageCard.modelData)
                                    ].filter(Boolean).join(" · ")
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.textTiny
                                    color: Theme.muted
                                }
                            }

                            Glyph {
                                text: packageCard.expanded ? "󰅃" : "󰅀"
                                size: 13
                                color: packageCard.expanded ? Theme.accentBright : Theme.dim
                            }
                        }
                    }

                    // Expanded package view.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        visible: packageCard.expanded
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.line
                        }

                        // Full description.
                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            visible: (packageCard.modelData.description ?? "") !== ""
                            text: packageCard.modelData.description
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.textBody
                            color: Theme.text
                        }

                        // Structured metadata pills.
                        Flow {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "Source", value: root.sourceName(packageCard.modelData.source) },
                                    { label: "Version", value: packageCard.modelData.version },
                                    { label: "Size", value: packageCard.modelData.size },
                                    { label: "Role", value: packageCard.modelData.reason || (packageCard.modelData.explicit === false ? "Dependency" : "Explicitly installed") },
                                    { label: "License", value: packageCard.modelData.licenses ?? "" },
                                    { label: "Groups", value: packageCard.modelData.groups ?? "" },
                                    { label: "Provides", value: packageCard.modelData.provides ?? "" }
                                ].filter(item => !!item.value)
                                delegate: Rectangle {
                                    id: metaPill
                                    required property var modelData
                                    implicitWidth: Math.min(cardColumn.width, metaRow.implicitWidth + 16)
                                    implicitHeight: 24
                                    radius: Theme.corner(8)
                                    color: Theme.control
                                    border.color: Theme.line

                                    RowLayout {
                                        id: metaRow
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                        spacing: 4
                                        Label {
                                            id: metaKeyLabel
                                            text: metaPill.modelData.label + ":"
                                            font.pixelSize: Theme.textTiny
                                            color: Theme.muted
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            Layout.maximumWidth: Math.max(60, cardColumn.width - metaKeyLabel.implicitWidth - 24)
                                            text: metaPill.modelData.value
                                            elide: Text.ElideRight
                                            font.pixelSize: Theme.textTiny
                                            font.weight: Font.Medium
                                            color: Theme.textSoft
                                        }
                                    }
                                }
                            }
                        }

                        // Dependencies (what this package needs) — clickable chips.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Glyph { text: "󰁔"; size: 12; color: Theme.accent }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: packageCard.depLinks.length > 0
                                        ? `Dependencies · what this needs (${packageCard.depLinks.length})`
                                        : "Dependencies · what this needs"
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.textSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.textSoft
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                visible: packageCard.depLinks.length > 0
                                spacing: 6
                                Repeater {
                                    model: packageCard.depLinks
                                    delegate: PackageLinkChip {
                                        required property var modelData
                                        label: modelData.label
                                        targetKey: modelData.key ?? ""
                                        installed: modelData.installed ?? false
                                        maxWidth: cardColumn.width
                                        onActivated: key => root.jumpTo(key, packageCard.modelData)
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                visible: packageCard.depLinks.length === 0
                                text: packageCard.modelData.source === "appimage"
                                    ? packageCard.modelData.dependencies
                                    : (packageCard.modelData.dependencies && packageCard.modelData.dependencies !== "None"
                                        ? packageCard.modelData.dependencies
                                        : "None — standalone package with no direct dependencies")
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.textSmall
                                color: Theme.muted
                            }
                        }

                        // Required by (what needs this package) — clickable chips.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Glyph { text: "󰁍"; size: 12; color: Theme.accent }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: packageCard.reqLinks.length > 0
                                        ? `Required by · what needs this (${packageCard.reqLinks.length})`
                                        : "Required by · what needs this"
                                    elide: Text.ElideRight
                                    font.pixelSize: Theme.textSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.textSoft
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                visible: packageCard.reqLinks.length > 0
                                spacing: 6
                                Repeater {
                                    model: packageCard.reqLinks
                                    delegate: PackageLinkChip {
                                        required property var modelData
                                        label: modelData.label
                                        targetKey: modelData.key ?? ""
                                        installed: modelData.installed ?? true
                                        maxWidth: cardColumn.width
                                        onActivated: key => root.jumpTo(key, packageCard.modelData)
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                visible: packageCard.reqLinks.length === 0
                                text: packageCard.modelData.source === "appimage"
                                    ? packageCard.modelData.required_by
                                    : "Nothing requires this package (top-level)"
                                wrapMode: Text.Wrap
                                font.pixelSize: Theme.textSmall
                                color: Theme.muted
                            }
                        }

                        // Optional dependencies (only shown when non-empty).
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            visible: packageCard.optDepLinks.length > 0
                            spacing: 5

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                text: `Optional dependencies (${packageCard.optDepLinks.length})`
                                elide: Text.ElideRight
                                font.pixelSize: Theme.textSmall
                                font.weight: Font.DemiBold
                                color: Theme.textSoft
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                spacing: 6
                                Repeater {
                                    model: packageCard.optDepLinks
                                    delegate: ColumnLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        Layout.preferredWidth: 0
                                        spacing: 2
                                        PackageLinkChip {
                                            label: modelData.label
                                            targetKey: modelData.key ?? ""
                                            installed: modelData.installed ?? false
                                            sublabel: (modelData.installed ?? false) ? "installed" : "not installed"
                                            maxWidth: cardColumn.width
                                            onActivated: key => root.jumpTo(key, packageCard.modelData)
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            Layout.preferredWidth: 0
                                            Layout.leftMargin: 6
                                            visible: (modelData.description ?? "") !== ""
                                            text: modelData.description ?? ""
                                            wrapMode: Text.Wrap
                                            font.pixelSize: Theme.textTiny
                                            color: Theme.muted
                                        }
                                    }
                                }
                            }
                        }

                        // Optional for (only shown when non-empty) — clickable chips.
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            visible: packageCard.optForLinks.length > 0
                            spacing: 5

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                text: `Optional for · enhances (${packageCard.optForLinks.length})`
                                elide: Text.ElideRight
                                font.pixelSize: Theme.textSmall
                                font.weight: Font.DemiBold
                                color: Theme.textSoft
                            }

                            Flow {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.preferredWidth: 0
                                spacing: 6
                                Repeater {
                                    model: packageCard.optForLinks
                                    delegate: PackageLinkChip {
                                        required property var modelData
                                        label: modelData.label
                                        targetKey: modelData.key ?? ""
                                        installed: modelData.installed ?? true
                                        maxWidth: cardColumn.width
                                        onActivated: key => root.jumpTo(key, packageCard.modelData)
                                    }
                                }
                            }
                        }

                        // Action buttons.
                        Flow {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            spacing: 8
                            PillButton {
                                text: packageCard.modelData.source === "flatpak" ? "Update" : "Upgrade system"
                                visible: packageCard.modelData.source !== "appimage"
                                onClicked: root.manage(packageCard.modelData, "update")
                            }
                            PillButton {
                                text: "Website"
                                visible: (packageCard.modelData.url ?? "") !== ""
                                onClicked: Ui.spawn(["xdg-open", packageCard.modelData.url])
                            }
                            PillButton {
                                text: "Open folder"
                                visible: packageCard.modelData.source === "appimage"
                                onClicked: root.manage(packageCard.modelData, "folder")
                            }
                            PillButton {
                                text: root.showRawDetails === packageCard.modelData.key ? "Hide record" : "Full record"
                                onClicked: root.showRawDetails = root.showRawDetails === packageCard.modelData.key ? "" : packageCard.modelData.key
                            }
                            PillButton {
                                text: packageCard.modelData.source === "appimage" ? "Move to trash…" : "Uninstall…"
                                danger: true
                                onClicked: root.confirmRemove = packageCard.modelData.key
                            }
                        }

                        // Collapsible full package record.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            visible: root.showRawDetails === packageCard.modelData.key
                            implicitHeight: rawColumn.implicitHeight + 16
                            radius: Theme.corner(8)
                            color: Theme.control
                            border.color: Theme.line

                            ColumnLayout {
                                id: rawColumn
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 6
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: packageCard.modelData.details
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.textTiny
                                    color: Theme.textSoft
                                }
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: packageCard.modelData.dependency_note || ""
                                    visible: text !== ""
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Theme.textTiny
                                    color: Theme.dim
                                }
                            }
                        }

                        // Uninstall confirmation.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.preferredWidth: 0
                            visible: root.confirmRemove === packageCard.modelData.key
                            implicitHeight: confirmCol.implicitHeight + 16
                            radius: Theme.corner(8)
                            color: Theme.alpha(Theme.rose, 0.12)
                            border.color: Theme.alpha(Theme.rose, 0.4)

                            ColumnLayout {
                                id: confirmCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                spacing: 8
                                Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    text: packageCard.modelData.source === "appimage"
                                        ? "Move this file to the trash? App data and launcher entries stay in place."
                                        : (packageCard.reqLinks.length > 0
                                            ? `Warning: ${packageCard.reqLinks.length} installed ${packageCard.reqLinks.length === 1 ? "package requires" : "packages require"} ${packageCard.modelData.name}. Review in the terminal before confirming.`
                                            : "Uninstall this package? Review and confirm in the terminal.")
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Theme.textSmall
                                    color: Theme.amber
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 0
                                    spacing: 8
                                    PillButton {
                                        text: "Continue in terminal"
                                        danger: true
                                        onClicked: root.manage(packageCard.modelData, "remove")
                                    }
                                    PillButton {
                                        text: "Cancel"
                                        onClicked: root.confirmRemove = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom pagination bar so the user doesn't have to scroll back to the top.
    RowLayout {
        Layout.fillWidth: true
        visible: root.matches.length > root.pageSize
        spacing: 8
        PillButton {
            text: "Previous"
            available: root.page > 0
            onClicked: { root.page--; root.selected = ""; }
        }
        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.textSmall
            color: Theme.muted
            text: `Page ${root.page + 1} of ${Math.ceil(root.matches.length / root.pageSize)}`
        }
        PillButton {
            text: "Next"
            available: (root.page + 1) * root.pageSize < root.matches.length
            onClicked: { root.page++; root.selected = ""; }
        }
    }
}
