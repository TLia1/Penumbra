import QtQuick
import "settingsSearch.js" as SettingsSearch
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings: organized into clean card groups for personalization, hardware, apps & tools,
// accessibility, and backup. Typing in the search field finds any setting across all pages.
ColumnLayout {
    id: root

    spacing: 10
    onVisibleChanged: if (visible) { Config.loadLayouts(); findExport.running = true; }
    Component.onCompleted: { Qt.callLater(locate); Config.loadLayouts(); findExport.running = true; }

    component Section: Overline {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        Layout.topMargin: 2
    }

    // A subtle grouped container for related rows.
    component SettingsCard: Rectangle {
        id: card
        default property alias content: cardColumn.data
        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 8
        radius: Theme.radius
        color: Theme.alpha(Theme.control, 0.42)
        border.color: Theme.line
        ColumnLayout {
            id: cardColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 4 }
            spacing: 2
        }
    }

    // A row with a Stepper on the right, matching ListRow and SwitchRow in height and hover style.
    component StepperRow: Rectangle {
        id: stepRow
        property string glyph
        property string title
        property string subtitle: ""
        property color subtitleColor: Theme.muted
        property string valueText
        property int textWidth: 92
        property bool canDecrease: true
        property bool canIncrease: true
        readonly property Item focusControl: stepper.focusControl
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
                    color: stepRow.subtitleColor
                    wrapMode: Text.Wrap
                }
            }
            Stepper {
                id: stepper
                accessibleLabel: stepRow.title
                text: stepRow.valueText
                textWidth: stepRow.textWidth
                canDecrease: stepRow.canDecrease
                canIncrease: stepRow.canIncrease
                onDecreased: stepRow.decreased()
                onIncreased: stepRow.increased()
            }
        }
    }

    // Compact pill toggle for nested sub-options (e.g. animated wallpaper pause rules).
    component SubToggle: Rectangle {
        id: chip
        property string glyph
        property string title
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 32
        radius: Theme.corner(10)
        color: checked ? Theme.alpha(Theme.accent, 0.18) : chipArea.containsMouse ? Theme.hover : Theme.raised
        border.color: checked ? Theme.alpha(Theme.accentBright, 0.5) : Theme.line
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 6
            Glyph {
                text: chip.glyph
                size: 13
                color: chip.checked ? Theme.accentBright : Theme.muted
            }
            Label {
                Layout.fillWidth: true
                text: chip.title
                elide: Text.ElideRight
                font.pixelSize: Theme.textTiny
                font.weight: chip.checked ? Font.DemiBold : Font.Normal
                color: chip.checked ? Theme.text : Theme.textSoft
            }
            Glyph {
                visible: chip.checked
                text: "󰄬"
                size: 11
                color: Theme.accentBright
            }
        }
        ActionArea {
            id: chipArea
            actionName: chip.title
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onTriggered: chip.toggled()
        }
    }

    readonly property string barSummary: ({ floating: "Capsules", island: "Island", framed: "Framed" })[Settings.barStyle] ?? "Capsules"
    readonly property string dockSummary: ({ off: "Dock off", auto: "Dock auto-hide", empty: "Dock on empty" })[Settings.dockMode] ?? "Dock off"
    readonly property string tilingSummary: Wm.layoutById(Settings.tilingLayout)?.title ?? "Dwindle"

    // What search finds: a page to open (page), or a row of this page (page: "settings").
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: query === "" ? [] : SettingsSearch.matches(query, Sys.chargeLimitFile !== "")
    required property bool panelOpen
    onPanelOpenChanged: if (panelOpen) Qt.callLater(locate)
    signal revealItem(Item row)

    function open(entry) {
        search.text = "";
        Ui.openSetting(entry);
    }

    function locate() {
        const rows = {
            "Reduced motion": reducedMotion, "Text size": textSize, "Battery care": battery,
            "Animated wallpapers": animated, "Hot corner": hotCorner,
            "Clipboard history": clipboard, "Export settings": exportRow,
            "Import settings": root.exportFile ? importRow : importHint
        };
        const row = rows[Ui.settingTarget];
        if (!row || !panelOpen) return;
        Ui.settingTarget = "";
        root.revealItem(row);
        const control = row === importHint ? row : row.focusControl;
        control.forceActiveFocus(Qt.TabFocusReason);
    }
    Connections {
        target: Ui
        function onSettingTargetChanged() { if (Ui.settingTarget) Qt.callLater(root.locate); }
    }

    // The newest export in the home folder, offered for import.
    property string exportFile: ""
    property bool includePins: false
    property bool includeLocation: false
    property bool includeMonitors: false
    readonly property var transferOptions: [
        ...(includePins ? ["--clipboard-pins"] : []),
        ...(includeLocation ? ["--location"] : []),
        ...(includeMonitors ? ["--monitors"] : [])
    ]
    onTransferOptionsChanged: Config.reviewedToken = ""
    onExportFileChanged: Config.reviewedToken = ""
    Process {
        id: findExport
        command: ["bash", "-c", "ls -t \"$HOME\"/penumbra-settings-*.json 2>/dev/null | head -n 1"]
        stdout: StdioCollector { onStreamFinished: root.exportFile = text.trim() }
    }
    Connections {
        target: Config
        function onTransferFinished() { findExport.running = true; }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Settings"
        status: "Super+, opens this page"
        showSwitch: false
        onBack: Ui.controlPage = "main"
    }

    Field {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search settings…"
        Keys.onReturnPressed: if (root.matches.length) root.open(root.matches[0])
        Keys.onEscapePressed: event => {
            if (text) {
                text = "";
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }
    }

    // Search results.
    SettingsCard {
        visible: root.query !== ""
        Repeater {
            model: root.matches
            delegate: ListRow {
                required property var modelData
                Layout.fillWidth: true
                glyph: modelData.glyph
                title: modelData.title
                subtitle: modelData.page === "settings" ? "On this page" : ""
                trailing: "󰅂"
                onClicked: root.open(modelData)
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.margins: 8
            visible: root.matches.length === 0
            text: "No setting matches"
            color: Theme.muted
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.query === ""
        spacing: 10

        // ── Personalization ─────────────────────────────────────────
        Section { text: "Personalization" }
        SettingsCard {
            ListRow {
                Layout.fillWidth: true
                glyph: "󰏘"
                title: "Look & colours"
                subtitle: Look.summary
                trailing: "󰅂"
                onClicked: Ui.openControl("look", "theme")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰍹"
                title: "Bar, dock & desktop"
                subtitle: `${root.barSummary} · ${root.dockSummary}`
                trailing: "󰅂"
                onClicked: Ui.openControl("look", "desktop")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰸉"
                title: "Wallpaper"
                subtitle: Ui.wallpaperTitle(Ui.wallpaper)
                trailing: "󰅂"
                onClicked: Ui.toggle("wallpapers")
            }
            SwitchRow {
                id: animated
                glyph: "󰐊"
                title: "Animated wallpapers"
                subtitle: Settings.reducedMotion ? "Still while Reduced motion is on" : Settings.animatedWallpapers ? "Wallpaper scenes, GIFs and videos move" : "Still images"
                checked: Settings.animatedWallpapers
                onToggled: Settings.animatedWallpapers = !Settings.animatedWallpapers
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 4
                visible: Settings.animatedWallpapers
                spacing: 6
                SubToggle {
                    glyph: "󰖯"
                    title: "Behind windows"
                    checked: Settings.stillWhenCovered
                    onToggled: Settings.stillWhenCovered = !Settings.stillWhenCovered
                }
                SubToggle {
                    glyph: "󰌪"
                    title: "On battery"
                    checked: Settings.stillOnBattery
                    onToggled: Settings.stillOnBattery = !Settings.stillOnBattery
                }
            }
            SwitchRow {
                id: hotCorner
                glyph: "󰆾"
                title: "Hot corner"
                subtitle: "Top-right corner opens the control center"
                checked: Settings.hotCorner
                onToggled: Settings.hotCorner = !Settings.hotCorner
            }
        }

        // ── System & hardware ───────────────────────────────────────
        Section { text: "System & hardware" }
        SettingsCard {
            ListRow {
                Layout.fillWidth: true
                glyph: "󰍹"
                title: "Displays"
                subtitle: Quickshell.screens.length > 1 ? `${Quickshell.screens.length} screens · arrangement, resolution, scale` : "Resolution, refresh rate, scale"
                trailing: "󰅂"
                onClicked: Ui.openControl("displays")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰕾"
                title: "Sound"
                subtitle: "Output, input and per-app volume"
                trailing: "󰅂"
                onClicked: Ui.openControl("mixer")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰌌"
                title: "Keyboard"
                subtitle: (Config.values.kb_layout ?? "").split(",").map(l => Config.layoutName(l)).join(", ")
                trailing: "󰅂"
                onClicked: Ui.openControl("keyboard")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰒲"
                title: "Idle and sleep"
                subtitle: `Lock after ${Config.duration(Config.values.idle_lock).toLowerCase()}`
                trailing: "󰅂"
                onClicked: Ui.openControl("idle")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰖯"
                title: "Window manager"
                subtitle: `MangoWM · ${root.tilingSummary}`
                trailing: "󰅂"
                onClicked: Ui.openControl("wm")
            }
            // Only where the battery's firmware can stop charging early.
            StepperRow {
                id: battery
                readonly property var limits: [100, 90, 80, 60]
                readonly property int current: Math.max(0, limits.indexOf(Settings.batteryLimit))
                visible: Sys.chargeLimitFile !== ""
                glyph: "󰂄"
                title: "Battery care"
                subtitle: !Sys.chargeLimitWritable ? "Run ./install.sh again to allow it" : Settings.batteryLimit < 100 ? "Stops charging early; the battery lasts more years" : "Charges to full"
                subtitleColor: Sys.chargeLimitWritable ? Theme.muted : Theme.amber
                valueText: Settings.batteryLimit < 100 ? `Up to ${Settings.batteryLimit}%` : "Full"
                canDecrease: Sys.chargeLimitWritable && battery.current < battery.limits.length - 1
                canIncrease: Sys.chargeLimitWritable && battery.current > 0
                onDecreased: Settings.batteryLimit = battery.limits[battery.current + 1]
                onIncreased: Settings.batteryLimit = battery.limits[battery.current - 1]
            }
        }

        // ── Apps & tools ────────────────────────────────────────────
        Section { text: "Apps & tools" }
        SettingsCard {
            ListRow {
                Layout.fillWidth: true
                glyph: "󰂚"
                title: "Notifications"
                subtitle: "Do not disturb, sounds, app rules"
                trailing: "󰅂"
                onClicked: Ui.openControl("notifications")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰀻"
                title: "Default apps"
                subtitle: "Browser, file manager, terminal"
                trailing: "󰅂"
                onClicked: Ui.openControl("apps")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰏗"
                title: "Installed packages"
                subtitle: "pacman, AUR, Flatpak and AppImage"
                trailing: "󰅂"
                onClicked: Ui.openControl("packages")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰇚"
                title: "Download video or audio"
                subtitle: "Save a video or its sound with yt-dlp"
                trailing: "󰅂"
                onClicked: Ui.toggle("downloads")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰖐"
                title: "Weather"
                subtitle: Settings.weatherEnabled ? (Weather.place?.name ?? "Enabled") : "Off · Open-Meteo forecast"
                trailing: "󰅂"
                onClicked: Ui.openControl("weather")
            }
            ListRow {
                Layout.fillWidth: true
                glyph: "󰎞"
                title: "Quick notes"
                subtitle: "A local draft, saved as you type"
                trailing: "󰅂"
                onClicked: Ui.openControl("notes")
            }
            StepperRow {
                id: clipboard
                readonly property var days: [0, 1, 7, 30]
                readonly property int current: Math.max(0, days.indexOf(Settings.clipboardDays))
                glyph: "󰅌"
                title: "Clipboard history"
                subtitle: "Pinned entries always stay"
                valueText: ["Kept", "1 day", "7 days", "30 days"][clipboard.current]
                canDecrease: clipboard.current > 0
                canIncrease: clipboard.current < clipboard.days.length - 1
                onDecreased: Settings.clipboardDays = clipboard.days[clipboard.current - 1]
                onIncreased: Settings.clipboardDays = clipboard.days[clipboard.current + 1]
            }
        }

        // ── Accessibility ───────────────────────────────────────────
        Section { text: "Accessibility" }
        SettingsCard {
            SwitchRow {
                id: reducedMotion
                glyph: "󰘾"
                title: "Reduced motion"
                subtitle: "No animations in the shell, wallpapers or windows"
                checked: Settings.reducedMotion
                onToggled: Settings.reducedMotion = !Settings.reducedMotion
            }
            StepperRow {
                id: textSize
                glyph: "󰛖"
                title: "Text size"
                subtitle: "Scale labels across the shell"
                valueText: Settings.textSizeLabels[Settings.textSizeIndex]
                canDecrease: Settings.textSizeIndex > 0
                canIncrease: Settings.textSizeIndex < Settings.textSizes.length - 1
                onDecreased: Settings.textScale = Settings.textSizes[Settings.textSizeIndex - 1]
                onIncreased: Settings.textScale = Settings.textSizes[Settings.textSizeIndex + 1]
            }
        }

        // ── Backup & restore ────────────────────────────────────────
        Section { text: "Backup & restore" }
        SettingsCard {
            SwitchRow {
                title: "Include clipboard pins"
                subtitle: "Pinned text in exports and imports"
                checked: root.includePins
                onToggled: root.includePins = !root.includePins
            }
            SwitchRow {
                title: "Include location"
                subtitle: "Weather and night light locations"
                checked: root.includeLocation
                onToggled: root.includeLocation = !root.includeLocation
            }
            SwitchRow {
                title: "Include monitor layout"
                subtitle: "Display rules for this hardware"
                checked: root.includeMonitors
                onToggled: root.includeMonitors = !root.includeMonitors
            }
            ListRow {
                id: exportRow
                Layout.fillWidth: true
                glyph: "󰈝"
                title: "Export settings"
                subtitle: "Save portable preferences to your home folder"
                busy: Config.transferring
                onClicked: Config.transferSettings(["export"].concat(root.transferOptions))
            }
            ListRow {
                id: importRow
                Layout.fillWidth: true
                visible: root.exportFile !== ""
                glyph: "󰈞"
                title: "Preview import"
                subtitle: "From " + root.exportFile.replace(/^.*\//, "~/")
                busy: Config.transferring
                onClicked: Config.transferSettings(["import", "--json-preview", root.exportFile].concat(root.transferOptions))
            }
            PillButton {
                visible: Config.reviewedToken !== ""
                text: "Apply import"
                onClicked: Config.transferSettings(["import", "--apply", "--reviewed", Config.reviewedToken,
                                                     root.exportFile].concat(root.transferOptions))
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 4
                visible: text !== ""
                text: Config.transferMessage
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 4
                visible: root.exportFile === "" && Config.transferMessage === ""
                id: importHint
                text: "To import, put a penumbra-settings-….json file from another computer in your home folder."
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.dim
            }
        }
    }
}
