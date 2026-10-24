import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// CPU and memory at a glance, and the busiest apps, under the system capsule.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge
    sheetWidth: 400
    open: Ui.monitorOpen
    onDismissed: Ui.dismiss()

    readonly property int shown: 8
    property string sortBy: "cpu" // cpu or memory
    property string expanded: ""
    property var groups: []

    onOpenChanged: if (!open) expanded = ""
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
        running: root.open
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
                cpu: g.cpu / Sys.cores,
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

    component Stat: Rectangle {
        id: stat
        property string glyph
        property string title
        property int value
        property string detail
        Layout.fillWidth: true
        implicitHeight: 84
        radius: Theme.radius
        color: Theme.raised
        border.color: Theme.line
        ColumnLayout {
            anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 }
            spacing: 6
            RowLayout {
                spacing: 7
                Glyph { text: stat.glyph; size: 13; color: Theme.violetBright }
                Label { Layout.fillWidth: true; text: stat.title; font.pixelSize: 11; color: Theme.muted }
                Label { text: stat.value + "%"; font.pixelSize: 18; font.weight: Font.DemiBold; font.family: Theme.mono }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.hover
                Rectangle {
                    width: parent.width * Math.min(stat.value, 100) / 100
                    height: parent.height
                    radius: 3
                    color: stat.value >= 90 ? Theme.rose : stat.value >= 70 ? Theme.amber : Theme.violet
                    Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }
            }
            Label { Layout.fillWidth: true; text: stat.detail; font.pixelSize: 11; color: Theme.muted }
        }
    }

    // A column title that sorts the list.
    component SortHeader: Label {
        id: header
        property string mode
        readonly property bool current: root.sortBy === mode
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        font.weight: current ? Font.DemiBold : Font.Normal
        color: current ? Theme.violetBright : headerArea.containsMouse ? Theme.textSoft : Theme.muted
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Stat {
                glyph: "󰻠"
                title: "Processor"
                value: Sys.cpu
                detail: `${Sys.cores} threads`
            }
            Stat {
                glyph: "󰍛"
                title: "Memory"
                value: Sys.memory
                detail: Sys.memoryDetail
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 0
            Label {
                Layout.fillWidth: true
                text: "Apps & processes"
                font.pixelSize: 11
                font.letterSpacing: 1.2
                font.capitalization: Font.AllUppercase
                color: Theme.muted
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
                                    font.pixelSize: 11
                                    color: Theme.muted
                                }
                            }
                            Label {
                                Layout.preferredWidth: 56
                                horizontalAlignment: Text.AlignRight
                                text: root.percent(row.cpu)
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: root.sortBy === "cpu" ? Theme.text : Theme.muted
                            }
                            Label {
                                Layout.preferredWidth: 76
                                horizontalAlignment: Text.AlignRight
                                text: root.size(row.mem)
                                font.family: Theme.mono
                                font.pixelSize: 12
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
                                font.pixelSize: 11
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

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Label {
                Layout.fillWidth: true
                text: "Updates every 2 s"
                font.pixelSize: 11
                color: Theme.dim
            }
            PillButton {
                text: "Advanced view"
                primary: true
                onClicked: {
                    Ui.close();
                    Ui.run("kitty --class nocturne-monitor htop");
                }
            }
        }
    }
}
