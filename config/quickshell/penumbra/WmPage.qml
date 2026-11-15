import QtQuick
import QtQuick.Layouts
import Quickshell

// MangoWM explorer: multi-tag matrix, interactive MangoWM features, all 14 tiling layouts and layout tuning.
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

    component ActionChip: Rectangle {
        id: chip
        property string glyph
        property string title
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 34
        radius: Theme.corner(10)
        color: active ? Theme.alpha(Theme.accent, 0.2) : chipArea.containsMouse ? Theme.hover : Theme.raised
        border.color: active ? Theme.alpha(Theme.accentBright, 0.55) : Theme.line
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 6
            Glyph {
                text: chip.glyph
                size: 13
                color: chip.active ? Theme.accentBright : Theme.textSoft
            }
            Label {
                Layout.fillWidth: true
                text: chip.title
                elide: Text.ElideRight
                font.pixelSize: Theme.textSmall
                font.weight: chip.active ? Font.DemiBold : Font.Medium
                color: chip.active ? Theme.text : Theme.textSoft
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

    readonly property var layouts: Wm.layoutCatalog
    readonly property var horizontalLayouts: layouts.filter(l => !l.vertical)
    readonly property var verticalLayouts: layouts.filter(l => l.vertical)
    readonly property var screenTags: Wm.allTagsFor(Ui.screen?.name ?? Wm.focusedMonitor?.name ?? "")
    readonly property bool isMasterLayout: ["tile", "center_tile", "right_tile", "deck", "vertical_tile", "vertical_deck"].includes(Settings.tilingLayout)
    readonly property bool isScrollerLayout: ["scroller", "vertical_scroller"].includes(Settings.tilingLayout)

    PageHeader {
        Layout.fillWidth: true
        title: "Window manager"
        status: `MangoWM · ${Wm.activeLayout?.title ?? "Dwindle"} (${Wm.activeLayoutSymbol})`
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // ── Live Tags & Multi-Tag View ──────────────────────────────────
    Section { text: "Tags & multi-tag view" }
    SettingsCard {
        innerMargin: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.screenTags.length > 0 ? root.screenTags : [1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => ({
                    id: i, name: String(i), active: i === 1, layoutSymbol: Wm.activeLayoutSymbol, clientCount: 0,
                    activate: () => Wm.focusWorkspace(i), toggleView: () => Wm.toggleTagView(i), toggleTagFocusedWindow: () => Wm.toggleTagFocusedWindow(i)
                }))
                delegate: Rectangle {
                    id: tagCell
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 44
                    radius: Theme.radiusSmall
                    color: modelData.active ? Theme.alpha(Theme.accent, 0.22) : tagArea.containsMouse ? Theme.hover : Theme.raised
                    border.width: modelData.active ? 1.5 : 1
                    border.color: modelData.active ? Theme.accentBright : modelData.clientCount > 0 ? Theme.lineStrong : Theme.line
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: tagCell.modelData.name
                            font.pixelSize: Theme.textSmall
                            font.weight: tagCell.modelData.active ? Font.Bold : Font.DemiBold
                            color: tagCell.modelData.active ? Theme.accentBright : tagCell.modelData.clientCount > 0 ? Theme.text : Theme.muted
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: tagCell.modelData.clientCount > 0 ? `${tagCell.modelData.layoutSymbol}·${tagCell.modelData.clientCount}` : tagCell.modelData.layoutSymbol
                            font.pixelSize: Theme.textTiny
                            color: tagCell.modelData.active ? Theme.textSoft : Theme.dim
                        }
                    }
                    MouseArea {
                        id: tagArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            if (m.button === Qt.RightButton || (m.modifiers & Qt.ControlModifier))
                                tagCell.modelData.toggleView();
                            else if (m.button === Qt.MiddleButton)
                                tagCell.modelData.toggleTagFocusedWindow();
                            else
                                tagCell.modelData.activate();
                        }
                    }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.topMargin: 4
            text: "Left-click switches tag · Right-click (or Super+Ctrl+1–9) views multiple tags at once · Middle-click (or Super+Ctrl+Shift+1–9) puts the focused window on multiple tags"
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textTiny
            color: Theme.dim
        }
        SwitchRow {
            glyph: "󰓹"
            title: "Show all 9 tags in bar"
            subtitle: "Always display tags 1–9 so any tag can be right-clicked for multi-tag view"
            checked: Settings.showAllTags
            onToggled: Settings.showAllTags = !Settings.showAllTags
        }
    }

    // ── Explore MangoWM Features ────────────────────────────────────
    Section { text: "MangoWM interactive features" }
    SettingsCard {
        innerMargin: 8
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 6
            ActionChip {
                glyph: "󰌌"
                title: "Jump labels (Super+Z)"
                onClicked: { Ui.close(); Wm.toggleJump(); }
            }
            ActionChip {
                glyph: "󰕮"
                title: "Native overview (Super+Shift+`)"
                onClicked: { Ui.close(); Wm.toggleOverview(); }
            }
            ActionChip {
                glyph: "󰓩"
                title: Wm.focusedClient?.isGroup ? "Leave group (Super+Shift+G)" : "Group window (Super+G)"
                active: !!Wm.focusedClient?.isGroup
                onClicked: Wm.focusedClient?.isGroup ? Wm.leaveGroup() : Wm.toggleGroup()
            }
            ActionChip {
                glyph: "󰀿"
                title: Wm.scratchpadCount > 0 ? `Scratchpad (${Wm.scratchpadCount}) (Super+S)` : "Scratchpad (Super+S)"
                active: Wm.scratchpadCount > 0
                onClicked: Wm.toggleScratchpad()
            }
            ActionChip {
                glyph: "󰐃"
                title: "Pin all tags (Super+P)"
                active: !!Wm.focusedClient?.isGlobal
                onClicked: Wm.toggleGlobal(Wm.focusedClient)
            }
            ActionChip {
                glyph: "󰁝"
                title: "Overlay on top (Super+O)"
                active: !!Wm.focusedClient?.isOverlay
                onClicked: Wm.toggleOverlay(Wm.focusedClient)
            }
            ActionChip {
                glyph: "󰊓"
                title: "Maximize in bar (Super+Shift+F)"
                active: !!Wm.focusedClient?.isMaximized
                onClicked: Wm.toggleMaximizeScreen(Wm.focusedClient)
            }
            ActionChip {
                glyph: "󰘕"
                title: Wm.keymode === "resize" ? "Exit resize mode (Esc)" : "Resize keymode (Super+Alt+K)"
                active: Wm.keymode === "resize"
                onClicked: {
                    const next = Wm.keymode === "resize" ? "default" : "resize";
                    if (next !== "default") Ui.close();
                    Wm.setKeymode(next);
                }
            }
        }
    }

    // ── Standard & Horizontal Tiling Layouts ────────────────────────
    Section { text: "Tiling layouts (Super+Shift+Space cycles)" }
    SettingsCard {
        Repeater {
            model: root.horizontalLayouts
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
                        RowLayout {
                            spacing: 6
                            Label {
                                text: layoutRow.modelData.title
                                font.weight: layoutRow.current ? Font.DemiBold : Font.Normal
                                color: layoutRow.current ? Theme.text : Theme.textSoft
                            }
                            Rectangle {
                                implicitWidth: symLabel.implicitWidth + 8
                                implicitHeight: 16
                                radius: Theme.corner(6)
                                color: layoutRow.current ? Theme.alpha(Theme.accent, 0.24) : Theme.raised
                                Label {
                                    id: symLabel
                                    anchors.centerIn: parent
                                    text: layoutRow.modelData.symbol
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.textTiny
                                    color: layoutRow.current ? Theme.accentBright : Theme.muted
                                }
                            }
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
                    onClicked: {
                        Settings.tilingLayout = layoutRow.modelData.id;
                        Wm.setLayout(layoutRow.modelData.id);
                    }
                }
            }
        }
    }

    // ── Vertical Tiling Layouts ─────────────────────────────────────
    Section { text: "Vertical tiling layouts" }
    SettingsCard {
        innerMargin: 6
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 6
            Repeater {
                model: root.verticalLayouts
                delegate: ActionChip {
                    required property var modelData
                    glyph: modelData.glyph
                    title: `${modelData.title} (${modelData.symbol})`
                    active: Settings.tilingLayout === modelData.id
                    onClicked: {
                        Settings.tilingLayout = modelData.id;
                        Wm.setLayout(modelData.id);
                    }
                }
            }
        }
    }

    // ── Layout Options & Behavior ───────────────────────────────────
    Section { text: "Layout options & focus" }
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
            visible: root.isMasterLayout
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
            title: "Main window size"
            subtitle: "Share of the screen given to the master area"
            valueText: `${Math.round(ratios[current] * 100)}%`
            canDecrease: current > 0
            canIncrease: current < ratios.length - 1
            onDecreased: Settings.masterRatio = ratios[current - 1]
            onIncreased: Settings.masterRatio = ratios[current + 1]
        }
        SwitchRow {
            visible: root.isMasterLayout
            glyph: "󰁝"
            title: "Open new windows as master"
            subtitle: "New windows take the main spot instead of joining the stack"
            checked: Settings.newWindowMaster
            onToggled: Settings.newWindowMaster = !Settings.newWindowMaster
        }
        SwitchRow {
            visible: Settings.tilingLayout === "deck" || Settings.tilingLayout === "vertical_deck"
            glyph: "󰓩"
            title: "Deck tab bar"
            subtitle: "Show MangoWM's native tab bar above stacked deck windows"
            checked: Settings.deckTabBar
            onToggled: Settings.deckTabBar = !Settings.deckTabBar
        }
        StepperRow {
            id: scrollerWidthRow
            visible: root.isScrollerLayout
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
            subtitle: "Default width of each scrolling column (Super+X cycles presets)"
            valueText: `${Math.round(proportions[current] * 100)}%`
            canDecrease: current > 0
            canIncrease: current < proportions.length - 1
            onDecreased: Settings.scrollerProportion = proportions[current - 1]
            onIncreased: Settings.scrollerProportion = proportions[current + 1]
        }
        SwitchRow {
            visible: root.isScrollerLayout
            glyph: "󰆤"
            title: "Center focused column"
            subtitle: "Keep the active window column centered on screen"
            checked: Settings.scrollerCenter
            onToggled: Settings.scrollerCenter = !Settings.scrollerCenter
        }
        RowLayout {
            visible: root.isScrollerLayout
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 4
            spacing: 6
            ActionChip {
                glyph: "↔"
                title: "Cycle column width (Super+X)"
                onClicked: Wm.switchProportionPreset()
            }
            ActionChip {
                glyph: "󰁍"
                title: "Stack left (Super+Alt+←)"
                onClicked: Wm.scrollerStack("left")
            }
            ActionChip {
                glyph: "󰁔"
                title: "Stack right (Super+Alt+→)"
                onClicked: Wm.scrollerStack("right")
            }
        }
        SwitchRow {
            visible: Settings.tilingLayout === "monocle"
            glyph: "󰓩"
            title: "Monocle tab bar"
            subtitle: "Show MangoWM's native tab bar across full-tag monocle windows"
            checked: Settings.monocleTabBar
            onToggled: Settings.monocleTabBar = !Settings.monocleTabBar
        }
        SwitchRow {
            glyph: "󰙀"
            title: "Smart gaps"
            subtitle: "Hide outer gaps when a tag has a single tiled window"
            checked: Settings.smartGaps
            onToggled: Settings.smartGaps = !Settings.smartGaps
        }
        SwitchRow {
            glyph: "󰆾"
            title: "Floating window edge snap"
            subtitle: "Snap dragged floating windows to screen and window edges"
            checked: Settings.floatingSnap
            onToggled: Settings.floatingSnap = !Settings.floatingSnap
        }
        SwitchRow {
            glyph: "󰇀"
            title: "Focus follows pointer"
            subtitle: "Moving the pointer into a window focuses it (sloppy focus)"
            checked: Settings.sloppyFocus
            onToggled: Settings.sloppyFocus = !Settings.sloppyFocus
        }
        SwitchRow {
            glyph: " 🎯"
            title: "Warp pointer to focused window"
            subtitle: "Move the cursor to the center of the window focused by keyboard"
            checked: Settings.warpCursor
            onToggled: Settings.warpCursor = !Settings.warpCursor
        }
        SwitchRow {
            glyph: "󰕮"
            title: "Bottom-left hot-corner native overview"
            subtitle: "Trigger MangoWM's built-in overview when pushing the pointer into the corner"
            checked: Settings.nativeHotarea
            onToggled: Settings.nativeHotarea = !Settings.nativeHotarea
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: "Config split across ~/.config/mango/{env,appearance,animations,layouts,input,rules,keybinds,autostart}.conf · user.conf is read last."
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
