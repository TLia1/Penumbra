import QtQuick
import QtQuick.Layouts

// When an idle computer dims, locks, turns its screens off and (on battery) suspends:
// settings.conf's idle timings, which penumbra-settings writes into hypridle.conf.
ColumnLayout {
    id: root

    spacing: 12

    // The steps each row moves through, in minutes; a value typed into settings.conf joins them.
    readonly property var steps: [0.5, 1, 2, 3, 4, 5, 7, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180]
    function choices(value) {
        const list = steps.slice();
        if (value !== "never" && value !== undefined && !list.includes(Number(value)))
            list.push(Number(value));
        return list.sort((a, b) => a - b).map(String).concat(["never"]);
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Idle and sleep"
        status: Ui.caffeine ? "Paused by Stay awake" : "After this long without input"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: [
                { key: "idle_dim", glyph: "󰃞", title: "Dim the screen", subtitle: "Any input brightens it again" },
                { key: "idle_lock", glyph: "󰌾", title: "Lock", subtitle: "Also before every suspend" },
                { key: "idle_screen_off", glyph: "󰍹", title: "Turn the screens off", subtitle: "" },
                { key: "idle_suspend", glyph: "󰒲", title: "Suspend", subtitle: "Only on battery" }
            ]
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property string value: Config.values[modelData.key] ?? "never"
                readonly property var list: root.choices(value)
                readonly property int index: list.indexOf(value === "never" ? "never" : String(Number(value)))
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Theme.radiusSmall
                color: hover.hovered ? Theme.raised : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                HoverHandler { id: hover }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 4 }
                    spacing: 11
                    Glyph { Layout.preferredWidth: 22; text: row.modelData.glyph; size: 17 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Label { Layout.fillWidth: true; text: row.modelData.title }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.modelData.subtitle
                            font.pixelSize: Theme.textSmall
                            color: Theme.muted
                        }
                    }
                    Stepper {
                        text: Config.duration(row.value)
                        textWidth: 92
                        canDecrease: row.index > 0
                        canIncrease: row.index < row.list.length - 1
                        onDecreased: Config.set({ [row.modelData.key]: row.list[Math.max(0, row.index - 1)] })
                        onIncreased: Config.set({ [row.modelData.key]: row.list[Math.min(row.list.length - 1, row.index + 1)] })
                    }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: "Stay awake in the control center pauses all of these, and so does a fullscreen window."
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: Config.error !== ""
        text: Config.error
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.rose
    }
}
