import QtQuick
import QtQuick.Layouts
import Quickshell

// Tiling layouts and window behavior.
ColumnLayout {
    id: root

    spacing: 10

    component Section: Overline {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.topMargin: 2
    }

    component SettingsCard: Rectangle {
        id: card
        default property alias content: cardColumn.data
        property int innerMargin: 4
        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 2 * innerMargin
        radius: Theme.radius
        color: Theme.alpha(Theme.control, 0.42)
        border.color: Theme.line
        ColumnLayout {
            id: cardColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.innerMargin }
            spacing: 2
        }
    }

    component StepperRow: Rectangle {
        id: stepRow
        property string glyph
        property string title
        property string subtitle: ""
        property string valueText
        property int textWidth: 92
        property bool canDecrease: true
        property bool canIncrease: true
        signal decreased()
        signal increased()

        Layout.fillWidth: true
        implicitHeight: Math.max(52, stepLabels.implicitHeight + 18)
        radius: Theme.radiusSmall
        color: stepHover.hovered ? Theme.raised : "transparent"
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
        HoverHandler { id: stepHover }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
            spacing: 11
            Glyph { Layout.preferredWidth: 22; text: stepRow.glyph; size: 17; color: Theme.textSoft }
            ColumnLayout {
                id: stepLabels
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: stepRow.title }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: stepRow.subtitle
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }
            }
            Stepper {
                text: stepRow.valueText
                textWidth: stepRow.textWidth
                canDecrease: stepRow.canDecrease
                canIncrease: stepRow.canIncrease
                onDecreased: stepRow.decreased()
                onIncreased: stepRow.increased()
            }
        }
    }

    readonly property var layouts: [
        { id: "dwindle", glyph: "󰕰", title: "Dwindle", subtitle: "Each new window splits the focused window" },
        { id: "tile", glyph: "󰙀", title: "Master & stack", subtitle: "Main window on the left, stack on the right" },
        { id: "scroller", glyph: "󰔰", title: "Scroller", subtitle: "Horizontal scrolling strip of windows" },
        { id: "center_tile", glyph: "󰆤", title: "Centered master", subtitle: "Main window centered with stacks on both sides" },
        { id: "grid", glyph: "󰕳", title: "Grid", subtitle: "Windows arranged in an equal grid" },
        { id: "deck", glyph: "󰘸", title: "Deck", subtitle: "Main window on the left, stacked deck on the right" },
        { id: "monocle", glyph: "󰊓", title: "Monocle", subtitle: "Every window fills the workspace" }
    ]

    PageHeader {
        Layout.fillWidth: true
        title: "Window manager"
        status: "MangoWM"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // ── Tiling layout ───────────────────────────────────────────────
    Section { text: "Tiling layout" }
    SettingsCard {
        Repeater {
            model: root.layouts
            delegate: Rectangle {
                id: layoutRow
                required property var modelData
                readonly property bool current: Settings.tilingLayout === modelData.id
                Layout.fillWidth: true
                implicitHeight: Math.max(50, rowText.implicitHeight + 16)
                radius: Theme.radiusSmall
                color: current ? Theme.alpha(Theme.accent, 0.14) : rowArea.containsMouse ? Theme.raised : "transparent"
                border.color: current ? Theme.alpha(Theme.accentBright, 0.45) : "transparent"
                Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                    spacing: 11
                    Glyph {
                        Layout.preferredWidth: 22
                        text: layoutRow.modelData.glyph
                        size: 17
                        color: layoutRow.current ? Theme.accentBright : Theme.textSoft
                    }
                    ColumnLayout {
                        id: rowText
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: layoutRow.modelData.title
                            font.weight: layoutRow.current ? Font.DemiBold : Font.Normal
                            color: layoutRow.current ? Theme.text : Theme.textSoft
                        }
                        Label {
                            Layout.fillWidth: true
                            text: layoutRow.modelData.subtitle
                            font.pixelSize: Theme.textSmall
                            color: Theme.muted
                            wrapMode: Text.Wrap
                        }
                    }
                    Glyph {
                        visible: layoutRow.current
                        text: "󰄬"
                        size: 15
                        color: Theme.accentBright
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Settings.tilingLayout = layoutRow.modelData.id
                }
            }
        }
    }

    // ── Layout options ──────────────────────────────────────────────
    Section { text: "Layout options" }
    SettingsCard {
        SwitchRow {
            visible: Settings.tilingLayout === "dwindle"
            glyph: "󰆾"
            title: "Cursor-guided split"
            subtitle: "Split direction follows the pointer instead of window shape"
            checked: Settings.dwindleSmartSplit
            onToggled: Settings.dwindleSmartSplit = !Settings.dwindleSmartSplit
        }
        StepperRow {
            id: masterWidthRow
            visible: Settings.tilingLayout === "tile" || Settings.tilingLayout === "center_tile" || Settings.tilingLayout === "deck"
            readonly property var ratios: [0.5, 0.55, 0.6, 0.65, 0.7]
            readonly property int current: {
                let best = 0;
                for (let i = 1; i < ratios.length; i++) {
                    if (Math.abs(ratios[i] - Settings.masterRatio) < Math.abs(ratios[best] - Settings.masterRatio))
                        best = i;
                }
                return best;
            }
            glyph: "↔"
            title: "Main window width"
            subtitle: "Share of the screen given to the main window"
            valueText: `${Math.round(ratios[current] * 100)}%`
            canDecrease: current > 0
            canIncrease: current < ratios.length - 1
            onDecreased: Settings.masterRatio = ratios[current - 1]
            onIncreased: Settings.masterRatio = ratios[current + 1]
        }
        SwitchRow {
            visible: Settings.tilingLayout === "tile" || Settings.tilingLayout === "center_tile" || Settings.tilingLayout === "deck"
            glyph: "󰁝"
            title: "Open new windows as main"
            subtitle: "New windows take the main spot instead of joining the stack"
            checked: Settings.newWindowMaster
            onToggled: Settings.newWindowMaster = !Settings.newWindowMaster
        }
        StepperRow {
            id: scrollerWidthRow
            visible: Settings.tilingLayout === "scroller"
            readonly property var proportions: [0.5, 0.67, 0.8, 1.0]
            readonly property int current: {
                let best = 0;
                for (let i = 1; i < proportions.length; i++) {
                    if (Math.abs(proportions[i] - Settings.scrollerProportion) < Math.abs(proportions[best] - Settings.scrollerProportion))
                        best = i;
                }
                return best;
            }
            glyph: "↔"
            title: "Column width"
            subtitle: "Default width of each scrolling column"
            valueText: `${Math.round(proportions[current] * 100)}%`
            canDecrease: current > 0
            canIncrease: current < proportions.length - 1
            onDecreased: Settings.scrollerProportion = proportions[current - 1]
            onIncreased: Settings.scrollerProportion = proportions[current + 1]
        }
        SwitchRow {
            visible: Settings.tilingLayout === "scroller"
            glyph: "󰆤"
            title: "Center focused column"
            subtitle: "Keep the active window centered on screen"
            checked: Settings.scrollerCenter
            onToggled: Settings.scrollerCenter = !Settings.scrollerCenter
        }
        SwitchRow {
            glyph: "󰙀"
            title: "Smart gaps"
            subtitle: "Hide outer gaps when a workspace has a single tiled window"
            checked: Settings.smartGaps
            onToggled: Settings.smartGaps = !Settings.smartGaps
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: "Press Super+Shift+Space to cycle layouts on the current workspace, or Super+J to flip a Dwindle split."
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
