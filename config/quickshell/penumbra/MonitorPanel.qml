import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// The system monitor, under the system capsule: live graphs of the processor, memory,
// graphics, disks and network with storage, or the busiest apps.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge - shadowRoom
    sheetWidth: 440
    open: Ui.monitorOpen
    onDismissed: Ui.dismiss()

    readonly property var pages: [
        { page: "overview", label: "Overview", glyph: "󰕮" },
        { page: "processes", label: "Processes", glyph: "󰉹" }
    ]
    property string page: "overview"
    readonly property bool listing: open && page === "processes"

    readonly property int shown: 10
    property string sortBy: "cpu" // cpu or memory
    property string expanded: ""
    property var groups: []

    // The graphics card shows the GPU picked by clicking it, or else the discrete GPU while it
    // is awake and the integrated one otherwise.
    property int gpuChoice: -1
    readonly property int gpuDefault: Math.max(0, Usage.gpus.findIndex(g => !g.integrated && !g.asleep), Usage.gpus.findIndex(g => g.integrated))
    readonly property var gpu: Usage.gpus[gpuChoice >= 0 ? gpuChoice : gpuDefault] ?? null

    onOpenChanged: if (!open) expanded = ""
    onPageChanged: pageIn.restart()
    onSortByChanged: refreshList()

    // Two batch iterations: the second measures CPU over the one-second delay.
    // The C locale keeps decimal points out of the user's locale.
    Process {
        id: top
        command: ["env", "LC_ALL=C", "top", "-b", "-n", "2", "-d", "1", "-w", "512", "-c", "-e", "k"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
    Timer {
        interval: 2000
        running: root.listing
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!top.running) top.running = true
    }

    // RES is in KiB, but top shortens values too wide for the column (e.g. 10.2g).
    function kib(value) {
        const scale = { m: 1024, g: 1048576, t: 1073741824 }[value.slice(-1)];
        return scale ? parseFloat(value) * scale : Number(value);
    }
    // Processes are grouped by executable, so a browser counts once.
    function parse(out) {
        const lines = out.split("\n");
        let start = lines.length;
        for (let i = lines.length - 1; i >= 0; i--) {
            if (/^\s*PID\s+USER/.test(lines[i])) {
                start = i + 1;
                break;
            }
        }
        const found = {};
        for (const line of lines.slice(start)) {
            // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
            const m = line.match(/^\s*(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\S+\s+\S\s+([\d.]+)\s+\S+\s+\S+\s+(.+)$/);
            if (!m || m[5].startsWith("top -b -n 2"))
                continue;
            const key = m[5].startsWith("[") ? "kernel" : m[5].split(" ")[0].split("/").pop().replace(/^-/, "");
            if (!key)
                continue;
            if (!found[key])
                found[key] = { key, cpu: 0, mem: 0, pids: [], user: m[2] };
            const g = found[key];
            g.cpu += Number(m[4]);
            g.mem += kib(m[3]);
            g.pids.push(m[1]);
            if (g.user !== m[2])
                g.user = "";
        }
        groups = Object.values(found);
        refreshList();
    }
    // Apps whose desktop file is named after something else (com.anthropic.Claude runs
    // claude-desktop) are found by the program they launch; wrappers say nothing about the app.
    readonly property var launchers: {
        const wrappers = ["env", "flatpak", "sh", "bash", "python", "python3", "java", "sudo", "pkexec"];
        const map = {};
        for (const e of DesktopEntries.applications.values) {
            const exe = (e.command[0] ?? "").split("/").pop();
            if (exe && !wrappers.includes(exe) && (!map[exe] || map[exe].noDisplay))
                map[exe] = e;
        }
        return map;
    }
    // Updated in place, so rows keep their state between samples.
    function refreshList() {
        const byCpu = (a, b) => (b.cpu - a.cpu) || (b.mem - a.mem);
        const byMem = (a, b) => b.mem - a.mem;
        const top = groups.slice().sort(sortBy === "cpu" ? byCpu : byMem).slice(0, shown);
        top.forEach((g, i) => {
            const entry = g.key === "kernel" ? null : DesktopEntries.heuristicLookup(g.key) ?? launchers[g.key];
            const row = {
                key: g.key,
                name: g.key === "kernel" ? "Kernel" : entry?.name || g.key,
                icon: entry?.icon ? Quickshell.iconPath(entry.icon, true) : "",
                cpu: g.cpu / Usage.cores,
                mem: g.mem,
                pids: g.pids.join(" "),
                count: g.pids.length,
                user: g.user
            };
            if (i < rows.count)
                rows.set(i, row);
            else
                rows.append(row);
        });
        while (rows.count > top.length)
            rows.remove(rows.count - 1);
    }
    function percent(value) {
        return value < 0.05 ? "0%" : value < 10 ? value.toFixed(1) + "%" : Math.round(value) + "%";
    }
    function size(kib) {
        return kib < 512 ? "—" : kib >= 1048576 ? (kib / 1048576).toFixed(1) + " GiB" : Math.round(kib / 1024) + " MiB";
    }
    function gib(kib) {
        return (kib / 1048576).toFixed(1) + " GiB";
    }
    // Decimal units, as drives and connections are sold.
    function bytes(n) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        for (; n >= 1000 && i < units.length - 1; i++)
            n /= 1000;
        return `${i === 0 || n >= 10 ? Math.round(n) : n.toFixed(1)} ${units[i]}`;
    }
    function rate(n) {
        return bytes(n) + "/s";
    }
    // Calm, then amber, then rose as something fills up.
    function level(value, calm) {
        return value >= 90 ? Theme.rose : value >= 75 ? Theme.amber : calm;
    }
    function end(pids, force) {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(pids.split(" ")));
        expanded = "";
        refreshSoon.restart();
    }
    Timer {
        id: refreshSoon
        interval: 400
        onTriggered: if (!top.running) top.running = true
    }

    ListModel { id: rows }

    // A figure over its history graph, which fills the card's lower part edge to edge.
    component Meter: Rectangle {
        id: meter
        property string glyph
        property string title
        property color accent: Theme.accent
        property bool interactive: false
        // The graphs; the header's right side; the figures under the title.
        default property alias graphs: graphArea.data
        property alias corner: cornerSlot.data
        property alias figures: figureSlot.data
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 132
        radius: Theme.radius
        color: interactive && meterArea.containsMouse ? Theme.hover : Theme.raised
        border.color: Theme.line
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        MouseArea {
            id: meterArea
            anchors.fill: parent
            enabled: meter.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: meter.clicked()
        }

        Item {
            id: graphArea
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 54
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: graphMask
                maskThresholdMin: 0.25
                maskSpreadAtMin: 0.25
            }
        }
        // The card's lower corners, for the graphs.
        Rectangle {
            id: graphMask
            anchors.fill: graphArea
            visible: false
            layer.enabled: true
            bottomLeftRadius: Math.max(0, meter.radius - 1)
            bottomRightRadius: Math.max(0, meter.radius - 1)
        }

        ColumnLayout {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14; rightMargin: 14 }
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                spacing: 7
                Glyph { text: meter.glyph; size: 13; color: meter.accent }
                Label { Layout.fillWidth: true; text: meter.title; font.pixelSize: Theme.textSmall; color: Theme.muted }
                RowLayout { id: cornerSlot; spacing: 6 }
            }
            ColumnLayout {
                id: figureSlot
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    // A big figure and a line of detail under it.
    component Figure: ColumnLayout {
        id: figure
        property string value
        property string detail
        property color color: Theme.text
        Layout.fillWidth: true
        spacing: 0
        Label {
            text: figure.value
            font.family: Theme.display
            font.pixelSize: Theme.textHeading
            font.weight: Font.DemiBold
            color: figure.color
        }
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: figure.detail
            font.pixelSize: Theme.textSmall
            color: Theme.subtle
        }
    }

    // A column title that sorts the list.
    component SortHeader: Overline {
        id: header
        property string mode
        readonly property bool current: root.sortBy === mode
        horizontalAlignment: Text.AlignRight
        font.weight: current ? Font.DemiBold : Font.Medium
        color: current ? Theme.accentBright : headerArea.containsMouse ? Theme.textSoft : Theme.muted
        MouseArea {
            id: headerArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortBy = header.mode
        }
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12

        // Header: the machine, and the two pages. Only the current page shows its name.
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 6
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label { text: "System"; font.pixelSize: Theme.textLarge; font.weight: Font.DemiBold }
                Label {
                    Layout.fillWidth: true
                    text: Usage.cpuModel || `${Usage.cores} threads`
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }
            Repeater {
                model: root.pages
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool current: root.page === modelData.page
                    implicitWidth: current ? pageRow.implicitWidth + 24 : 32
                    implicitHeight: 32
                    radius: Theme.corner(16)
                    color: current ? Theme.accent : pageArea.containsMouse ? Theme.hover : Theme.raised
                    border.color: current ? Theme.accentBright : Theme.line
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    RowLayout {
                        id: pageRow
                        anchors.centerIn: parent
                        spacing: 6
                        Glyph { text: modelData.glyph; size: 13; color: current ? Theme.onAccent : Theme.textSoft }
                        Label { visible: current; text: modelData.label; font.pixelSize: Theme.textSmall; font.weight: Font.DemiBold; color: Theme.onAccent }
                    }
                    MouseArea {
                        id: pageArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = modelData.page
                    }
                }
            }
        }

        ColumnLayout {
            id: pageContent
            Layout.fillWidth: true
            spacing: 12

            ParallelAnimation {
                id: pageIn
                NumberAnimation { target: pageContent; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                NumberAnimation { target: pageContent; property: "Layout.topMargin"; from: 8; to: 0; duration: Theme.slow; easing.type: Easing.OutExpo }
            }

            // Overview
            GridLayout {
                Layout.fillWidth: true
                visible: root.page === "overview"
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                Meter {
                    glyph: "󰻠"
                    title: "Processor"
                    accent: Theme.accent
                    // One bar per thread.
                    corner: Row {
                        readonly property int count: Usage.coreLoads.length
                        readonly property real bar: Math.max(1, (84 - (count - 1)) / count)
                        spacing: 1
                        Repeater {
                            model: parent.count
                            delegate: Rectangle {
                                required property int index
                                width: parent.bar
                                height: 14
                                radius: Theme.corner(1)
                                color: Theme.alpha(Theme.accent, 0.16)
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: Math.max(1, parent.height * (Usage.coreLoads[index] ?? 0) / 100)
                                    radius: parent.radius
                                    color: root.level(Usage.coreLoads[index] ?? 0, Theme.accent)
                                    Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                    figures: Figure {
                        value: Usage.cpu + "%"
                        detail: [Usage.cpuTemp >= 0 ? Usage.cpuTemp + " °C" : "", Usage.cpuGhz ? Usage.cpuGhz.toFixed(1) + " GHz" : "", Usage.loadAverage ? "load " + Usage.loadAverage : ""].filter(s => s).join(" · ")
                    }
                    Graph {
                        anchors.fill: parent
                        values: Usage.cpuHistory
                        color: Theme.accent
                        live: root.open
                    }
                }

                Meter {
                    glyph: "󰍛"
                    title: "Memory"
                    accent: Theme.pink
                    corner: Label {
                        visible: Usage.swapUsed >= 1024
                        text: "Swap " + root.gib(Usage.swapUsed)
                        font.pixelSize: Theme.textTiny
                        color: Theme.dim
                    }
                    figures: Figure {
                        value: Usage.memory + "%"
                        detail: `${root.gib(Usage.memoryUsed)} of ${root.gib(Usage.memoryTotal)}`
                    }
                    Graph {
                        anchors.fill: parent
                        values: Usage.memoryHistory
                        color: Theme.pink
                        live: root.open
                    }
                }

                Meter {
                    glyph: "󰢮"
                    title: root.gpu?.name ?? "Graphics"
                    accent: Theme.blue
                    interactive: Usage.gpus.length > 1
                    onClicked: root.gpuChoice = (Usage.gpus.indexOf(root.gpu) + 1) % Usage.gpus.length
                    // Which GPU of several this is.
                    corner: Row {
                        visible: Usage.gpus.length > 1
                        spacing: 4
                        Repeater {
                            model: Usage.gpus.length
                            delegate: Rectangle {
                                required property int index
                                readonly property bool current: Usage.gpus[index] === root.gpu
                                width: current ? 12 : 5
                                height: 5
                                radius: Theme.corner(2.5)
                                color: current ? Theme.blue : Theme.alpha(Theme.blue, 0.3)
                                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    figures: Figure {
                        readonly property var g: root.gpu
                        value: !g ? "—" : g.asleep ? "Asleep" : g.busy >= 0 ? Math.round(g.busy) + "%" : "…"
                        color: g?.asleep ? Theme.textSoft : Theme.text
                        detail: {
                            if (!g)
                                return "No GPU found";
                            if (g.asleep)
                                return "Wakes when an app needs it";
                            return [g.temp >= 0 ? g.temp + " °C" : "",
                                    g.memTotal > 0 ? `${(g.memUsed / 1024).toFixed(1)} of ${(g.memTotal / 1024).toFixed(1)} GiB` : "",
                                    g.power >= 0 ? g.power + " W" : "",
                                    g.freq >= 0 ? `${g.freq} MHz` : ""].filter(s => s).join(" · ");
                        }
                    }
                    Graph {
                        anchors.fill: parent
                        values: root.gpu?.history ?? []
                        color: Theme.blue
                        live: root.open
                    }
                }

                Meter {
                    glyph: "󰋊"
                    title: "Disks"
                    accent: Theme.green
                    figures: Figure {
                        value: root.rate(Usage.diskRead + Usage.diskWrite)
                        detail: `Read ${root.rate(Usage.diskRead)} · Write ${root.rate(Usage.diskWrite)}`
                    }
                    Graph {
                        anchors.fill: parent
                        values: Usage.diskHistory
                        maximum: 0
                        floor: 1e6
                        color: Theme.green
                        live: root.open
                    }
                }

                Meter {
                    Layout.columnSpan: 2
                    glyph: Devices.networkGlyph
                    title: Devices.networkName
                    accent: Theme.cyan
                    corner: Label {
                        text: Usage.netInterface
                        font.pixelSize: Theme.textTiny
                        color: Theme.dim
                    }
                    figures: RowLayout {
                        Layout.fillWidth: true
                        spacing: 22
                        Repeater {
                            model: [
                                { glyph: "󰇚", value: Usage.netDown, total: Usage.netReceived, what: "received", color: Theme.cyan },
                                { glyph: "󰕒", value: Usage.netUp, total: Usage.netSent, what: "sent", color: Theme.accentBright }
                            ]
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 8
                                Glyph { text: modelData.glyph; size: 16; color: modelData.color }
                                Figure {
                                    value: root.rate(modelData.value)
                                    detail: `${root.bytes(modelData.total)} ${modelData.what}`
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    // Both directions on one scale.
                    Graph {
                        id: download
                        anchors.fill: parent
                        values: Usage.downHistory
                        maximum: Math.max(1e5, 1.15 * Math.max(0, ...Usage.downHistory, ...Usage.upHistory))
                        color: Theme.cyan
                        live: root.open
                    }
                    Graph {
                        anchors.fill: parent
                        values: Usage.upHistory
                        maximum: download.maximum
                        color: Theme.accentBright
                        fillOpacity: 0.16
                        live: root.open
                    }
                }

                // Storage, one row per filesystem.
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    visible: Usage.filesystems.length > 0
                    implicitHeight: storage.implicitHeight + 24
                    radius: Theme.radius
                    color: Theme.raised
                    border.color: Theme.line
                    ColumnLayout {
                        id: storage
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; leftMargin: 14; rightMargin: 14 }
                        spacing: 10
                        Repeater {
                            model: Usage.filesystems
                            delegate: ColumnLayout {
                                id: fs
                                required property var modelData
                                readonly property real used: 100 * modelData.used / modelData.size
                                Layout.fillWidth: true
                                spacing: 6
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7
                                    Glyph { text: "󰋊"; size: 13; color: Theme.green }
                                    Label { text: fs.modelData.name; font.weight: Font.Medium }
                                    Label {
                                        Layout.fillWidth: true
                                        text: fs.modelData.mount
                                        font.pixelSize: Theme.textSmall
                                        color: Theme.dim
                                    }
                                    Label {
                                        text: `${root.bytes(fs.modelData.size - fs.modelData.used)} free of ${root.bytes(fs.modelData.size)}`
                                        font.pixelSize: Theme.textSmall
                                        color: Theme.subtle
                                    }
                                }
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    radius: Theme.corner(3)
                                    color: Theme.hover
                                    Rectangle {
                                        width: Math.max(height, parent.width * Math.min(fs.used, 100) / 100)
                                        height: parent.height
                                        radius: parent.radius
                                        color: root.level(fs.used, Theme.green)
                                        Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Processes
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.page === "processes"
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    spacing: 0
                    Overline {
                        Layout.fillWidth: true
                        text: "Apps & processes"
                    }
                    SortHeader { Layout.preferredWidth: 56; text: "CPU"; mode: "cpu" }
                    SortHeader { Layout.preferredWidth: 76; text: "Memory"; mode: "memory" }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        visible: rows.count === 0
                        horizontalAlignment: Text.AlignHCenter
                        text: "Measuring…"
                        color: Theme.muted
                    }

                    Repeater {
                        model: rows
                        delegate: Rectangle {
                            id: row
                            required property string key
                            required property string name
                            required property string icon
                            required property real cpu
                            required property real mem
                            required property string pids
                            required property int count
                            required property string user
                            readonly property bool expanded: root.expanded === key
                            readonly property bool mine: user === Quickshell.env("USER")

                            Layout.fillWidth: true
                            implicitHeight: column.implicitHeight + 14
                            radius: Theme.radiusSmall
                            color: area.containsMouse || expanded ? Theme.raised : "transparent"
                            border.color: expanded ? Theme.line : "transparent"
                            clip: true
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                            Behavior on implicitHeight { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }

                            MouseArea {
                                id: area
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expanded = row.expanded ? "" : row.key
                            }

                            ColumnLayout {
                                id: column
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 7; leftMargin: 10; rightMargin: 10 }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 11
                                    Item {
                                        implicitWidth: 22
                                        implicitHeight: 22
                                        IconImage {
                                            anchors.fill: parent
                                            visible: row.icon !== ""
                                            source: row.icon
                                            asynchronous: true
                                        }
                                        Glyph {
                                            anchors.centerIn: parent
                                            visible: row.icon === ""
                                            text: row.key === "kernel" ? "󰻠" : "󰣆"
                                            size: 17
                                            color: Theme.textSoft
                                        }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Label { Layout.fillWidth: true; text: row.name }
                                        Label {
                                            Layout.fillWidth: true
                                            text: (row.count > 1 ? `${row.count} processes` : `PID ${row.pids}`) + (row.user && !row.mine ? ` · ${row.user}` : "")
                                            font.pixelSize: Theme.textSmall
                                            color: Theme.muted
                                        }
                                    }
                                    Label {
                                        Layout.preferredWidth: 56
                                        horizontalAlignment: Text.AlignRight
                                        text: root.percent(row.cpu)
                                        font.pixelSize: Theme.textBody
                                        color: root.sortBy === "cpu" ? Theme.text : Theme.muted
                                    }
                                    Label {
                                        Layout.preferredWidth: 76
                                        horizontalAlignment: Text.AlignRight
                                        text: root.size(row.mem)
                                        font.pixelSize: Theme.textBody
                                        color: root.sortBy === "memory" ? Theme.text : Theme.muted
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 33
                                    visible: row.expanded
                                    spacing: 8
                                    Label {
                                        Layout.fillWidth: true
                                        text: row.mine ? `Running as ${row.user}` : row.key === "kernel" ? "Kernel threads" : "Owned by another user"
                                        font.pixelSize: Theme.textSmall
                                        color: Theme.dim
                                    }
                                    PillButton {
                                        visible: row.mine
                                        text: "End"
                                        onClicked: root.end(row.pids, false)
                                    }
                                    PillButton {
                                        visible: row.mine
                                        text: "Force quit"
                                        danger: true
                                        onClicked: root.end(row.pids, true)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Label {
                Layout.fillWidth: true
                text: "Updates every 2 s"
                font.pixelSize: Theme.textSmall
                color: Theme.dim
            }
            PillButton {
                text: "Advanced view"
                primary: true
                onClicked: {
                    Ui.close();
                    Ui.run("kitty --class penumbra-monitor btop");
                }
            }
        }
    }
}
