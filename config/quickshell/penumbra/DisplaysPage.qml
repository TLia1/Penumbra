import QtQuick
import QtQuick.Layouts

// Settings → Displays: drag the screens into place, then pick each one's resolution, refresh
// rate, scale and rotation. Displays holds the draft and applies it.
ColumnLayout {
    id: root

    spacing: 12

    property int selected: 0
    readonly property var current: Displays.draft[Math.min(selected, Displays.draft.length - 1)] ?? null
    readonly property int enabledCount: Displays.draft.filter(s => s.enabled).length
    onVisibleChanged: if (visible && Displays.countdown === 0 && !Displays.changed) Displays.refresh()

    // Change the selected screen, then put it back against its neighbours: a new size may overlap.
    function change(changes) {
        Displays.update(selected, changes);
        Displays.place(selected, current.x, current.y);
    }
    readonly property var resolutions: current ? [...new Set(current.modes.map(m => m.split("@")[0]))]
        .sort((a, b) => Displays.pixels(b).width * Displays.pixels(b).height - Displays.pixels(a).width * Displays.pixels(a).height) : []
    readonly property string resolution: current?.mode.split("@")[0] ?? ""
    readonly property var rates: current ? current.modes.filter(m => m.split("@")[0] === resolution)
        .sort((a, b) => Number(b.split("@")[1]) - Number(a.split("@")[1])) : []
    readonly property var scales: current ? Displays.scales(current) : []
    readonly property var rotations: ["Normal", "90°", "Upside down", "270°"]

    // A titled row with its control on the right.
    component SettingRow: RowLayout {
        id: setting
        property string glyph
        property string title
        default property alias control: holder.data
        Layout.fillWidth: true
        Layout.leftMargin: 10
        Layout.preferredHeight: 36
        spacing: 11
        Glyph { Layout.preferredWidth: 22; text: setting.glyph; size: 17 }
        Label { Layout.fillWidth: true; text: setting.title }
        Item {
            id: holder
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Displays"
        status: Displays.draft.length > 1 ? `${root.enabledCount} of ${Displays.draft.length} screens on · drag to arrange` : (root.current?.label ?? "")
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // ── Arrangement ─────────────────────────────────────────────────
    Rectangle {
        id: canvas
        Layout.fillWidth: true
        implicitHeight: 168
        radius: Theme.radius
        color: Theme.alpha(Theme.base, 0.45)
        border.color: Theme.line

        readonly property var shown: Displays.draft.map(s => ({ s, size: Displays.logical(s) })).filter(o => o.s.enabled)
        readonly property real minX: shown.length ? Math.min(...shown.map(o => o.s.x)) : 0
        readonly property real minY: shown.length ? Math.min(...shown.map(o => o.s.y)) : 0
        readonly property real spanX: shown.length ? Math.max(...shown.map(o => o.s.x + o.size.width)) - minX : 1
        readonly property real spanY: shown.length ? Math.max(...shown.map(o => o.s.y + o.size.height)) - minY : 1
        readonly property real fit: Math.min((width - 40) / spanX, (height - 40) / spanY)
        readonly property real originX: (width - spanX * fit) / 2
        readonly property real originY: (height - spanY * fit) / 2

        Repeater {
            model: Displays.draft
            delegate: Rectangle {
                id: box
                required property var modelData
                required property int index
                readonly property var size: Displays.logical(modelData)
                readonly property bool chosen: index === root.selected
                property real dx: 0
                property real dy: 0
                visible: modelData.enabled
                x: canvas.originX + (modelData.x - canvas.minX) * canvas.fit + dx
                y: canvas.originY + (modelData.y - canvas.minY) * canvas.fit + dy
                width: size.width * canvas.fit
                height: size.height * canvas.fit
                z: area.pressed ? 2 : chosen ? 1 : 0
                radius: Theme.corner(8)
                color: chosen ? Theme.alpha(Theme.violet, 0.28) : Theme.raised
                border.width: chosen ? 2 : 1
                border.color: chosen ? Theme.violet : Theme.lineStrong
                Behavior on x { enabled: !area.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !area.pressed; NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 0
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: String(box.index + 1)
                        font.family: Theme.display
                        font.pixelSize: Math.max(Theme.textBody, Math.min(Theme.textHeading, box.height / 3))
                        font.weight: Font.DemiBold
                        color: box.chosen ? Theme.text : Theme.textSoft
                    }
                    Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: box.height > 54
                        text: box.modelData.name
                        font.pixelSize: Theme.textTiny
                        color: Theme.muted
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: canvas.shown.length > 1 ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.PointingHandCursor
                    property point start
                    onPressed: m => {
                        root.selected = box.index;
                        start = mapToItem(canvas, m.x, m.y);
                    }
                    onPositionChanged: m => {
                        if (!pressed || canvas.shown.length < 2)
                            return;
                        const p = mapToItem(canvas, m.x, m.y);
                        box.dx = p.x - start.x;
                        box.dy = p.y - start.y;
                    }
                    onReleased: {
                        if (box.dx !== 0 || box.dy !== 0)
                            Displays.place(box.index, box.modelData.x + box.dx / canvas.fit, box.modelData.y + box.dy / canvas.fit);
                        box.dx = 0;
                        box.dy = 0;
                    }
                }
            }
        }
    }

    // ── The selected screen ─────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: !!root.current
        spacing: 8
        Label {
            Layout.fillWidth: true
            text: `${root.selected + 1} · ${root.current?.label ?? ""}`
            font.weight: Font.DemiBold
        }
        Label { text: root.current?.name ?? ""; font.family: Theme.mono; font.pixelSize: Theme.textSmall; color: Theme.muted }
    }

    SwitchRow {
        visible: Displays.draft.length > 1
        glyph: "󰍹"
        title: "Use this screen"
        subtitle: root.current?.enabled && root.enabledCount === 1 ? "The last screen on stays on" : ""
        checked: root.current?.enabled ?? false
        onToggled: {
            if (root.current.enabled && root.enabledCount === 1)
                return;
            root.change({ enabled: !root.current.enabled });
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.current?.enabled ?? false
        spacing: 4
        SettingRow {
            glyph: "󰨤"
            title: "Resolution"
            Stepper {
                readonly property int at: root.resolutions.indexOf(root.resolution)
                text: root.resolution.replace("x", " × ")
                textWidth: 100
                // Larger to the right.
                canDecrease: at < root.resolutions.length - 1
                canIncrease: at > 0
                function pick(resolution) {
                    // The same refresh rate when the new resolution has it, else its fastest.
                    const rate = root.current.mode.split("@")[1];
                    const modes = root.current.modes.filter(m => m.split("@")[0] === resolution);
                    root.change({ mode: modes.find(m => m.split("@")[1] === rate) ?? modes.sort((a, b) => Number(b.split("@")[1]) - Number(a.split("@")[1]))[0] });
                }
                onDecreased: pick(root.resolutions[at + 1])
                onIncreased: pick(root.resolutions[at - 1])
            }
        }
        SettingRow {
            glyph: "󰓅"
            title: "Refresh rate"
            Stepper {
                readonly property int at: root.rates.indexOf(root.current?.mode ?? "")
                text: `${Math.round(Number((root.current?.mode ?? "@0").split("@")[1]) * 100) / 100} Hz`
                textWidth: 100
                canDecrease: at < root.rates.length - 1
                canIncrease: at > 0
                onDecreased: root.change({ mode: root.rates[at + 1] })
                onIncreased: root.change({ mode: root.rates[at - 1] })
            }
        }
        SettingRow {
            glyph: "󰑒"
            title: "Scale"
            Stepper {
                readonly property int at: root.scales.findIndex(s => Math.abs(s - (root.current?.scale ?? 1)) < 0.001)
                text: Math.round((root.current?.scale ?? 1) * 100) + "%"
                textWidth: 100
                canDecrease: at > 0
                canIncrease: at < root.scales.length - 1
                onDecreased: root.change({ scale: root.scales[at - 1] })
                onIncreased: root.change({ scale: root.scales[at + 1] })
            }
        }
        SettingRow {
            glyph: "󰑵"
            title: "Rotation"
            Stepper {
                text: root.rotations[root.current?.transform ?? 0]
                textWidth: 100
                onDecreased: root.change({ transform: (root.current.transform + 3) % 4 })
                onIncreased: root.change({ transform: (root.current.transform + 1) % 4 })
            }
        }
    }

    // ── Apply, then keep or undo ────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        visible: Displays.countdown > 0
        implicitHeight: keepRow.implicitHeight + 20
        radius: Theme.radius
        color: Theme.alpha(Theme.violet, 0.14)
        border.color: Theme.alpha(Theme.violetBright, 0.45)
        RowLayout {
            id: keepRow
            anchors { fill: parent; margins: 10; leftMargin: 14 }
            spacing: 8
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: "Keep these settings?"; font.weight: Font.DemiBold }
                Label { Layout.fillWidth: true; text: `Undoing them in ${Displays.countdown} s`; font.pixelSize: Theme.textSmall; color: Theme.textSoft }
            }
            PillButton { text: "Undo"; onClicked: Displays.revert() }
            PillButton { text: "Keep"; primary: true; onClicked: Displays.keep() }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: Displays.changed && Displays.countdown === 0
        spacing: 8
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: "Not applied yet"
            font.pixelSize: Theme.textSmall
            color: Theme.muted
        }
        PillButton { text: "Reset"; onClicked: Displays.reset() }
        PillButton { text: "Apply"; primary: true; onClicked: Displays.apply() }
    }
}
