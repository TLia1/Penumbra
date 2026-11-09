import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings: organized into clean card groups for personalization, hardware, apps & tools,
// accessibility, and backup. Typing in the search field finds any setting across all pages.
ColumnLayout {
    id: root

    spacing: 10
    onVisibleChanged: if (visible) { Config.loadLayouts(); findExport.running = true; }
    Component.onCompleted: { Config.loadLayouts(); findExport.running = true; }

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
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }
    }

    readonly property string barSummary: ({ floating: "Capsules", island: "Island", framed: "Framed" })[Settings.barStyle] ?? "Capsules"
    readonly property string dockSummary: ({ off: "Dock off", auto: "Dock auto-hide", empty: "Dock on empty" })[Settings.dockMode] ?? "Dock off"

    // What search finds: a page to open (page), or a row of this page (page: "settings").
    readonly property var index: [
        { page: "look", tab: "theme", glyph: "󰏘", title: "Look", words: "theme dark light auto colours colors accent hue vividness corners rounded sharp harmonize glass frost" },
        { page: "look", tab: "desktop", glyph: "󰍹", title: "Bar, dock & desktop", words: "bar island capsules framed workspaces dock depth clock audio aura screen frame bezel signature layout osd" },
        { page: "wallpapers", glyph: "󰸉", title: "Wallpaper", words: "background picture image video gif" },
        { page: "displays", glyph: "󰍹", title: "Displays", words: "monitors screens resolution refresh rate scale rotation arrangement" },
        { page: "mixer", glyph: "󰕾", title: "Sound", words: "audio volume output input microphone speakers apps" },
        { page: "keyboard", glyph: "󰌌", title: "Keyboard", words: "layout variant options num lock xkb" },
        { page: "idle", glyph: "󰒲", title: "Idle and sleep", words: "dim lock screens off suspend timeout stay awake apps inhibit video calls" },
        { page: "notifications", glyph: "󰂚", title: "Notifications", words: "do not disturb dnd schedule fullscreen sharing sounds lock screen count mute quiet keep rules" },
        { page: "apps", glyph: "󰀻", title: "Default apps", words: "browser file manager terminal" },
        { page: "packages", glyph: "󰏗", title: "Installed packages", words: "software pacman aur foreign flatpak appimage uninstall update manage" },
        { page: "weather", glyph: "󰖐", title: "Weather", words: "location city coordinates forecast temperature calendar clock bar" },
        { page: "notes", glyph: "󰎞", title: "Quick notes", words: "notes draft text writing local sidebar" },
        { page: "night", glyph: "󰖔", title: "Night light", words: "warmth temperature kelvin sunset sunrise schedule hyprsunset" },
        { page: "wifi", glyph: "󰤨", title: "Wi-Fi", words: "wireless network internet" },
        { page: "bluetooth", glyph: "󰂯", title: "Bluetooth", words: "devices headphones mouse pair battery" },
        { page: "cast", glyph: "󰄘", title: "Cast screen", words: "tv chromecast dlna firewall port" },
        { page: "settings", glyph: "󰐊", title: "Animated wallpapers", words: "motion still battery power covered windows" },
        { page: "settings", glyph: "󰆾", title: "Hot corner", words: "corner control center" },
        { page: "settings", glyph: "󰘾", title: "Reduced motion", words: "animations accessibility" },
        { page: "settings", glyph: "󰛖", title: "Text size", words: "font larger bigger accessibility zoom" },
        { page: "settings", glyph: "󰂄", title: "Battery care", words: "charge limit threshold power" },
        { page: "settings", glyph: "󰅌", title: "Clipboard history", words: "copy paste keep days expire pins" },
        { page: "settings", glyph: "󰈝", title: "Export settings", words: "backup move another computer save file" },
        { page: "settings", glyph: "󰈞", title: "Import settings", words: "restore another computer load file" }
    ]
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: query === "" ? [] : index.filter(e => query.split(/\s+/).every(q => (e.title + " " + e.words).toLowerCase().includes(q)))
    function open(entry) {
        search.text = "";
        if (entry.page === "wallpapers")
            Ui.toggle("wallpapers");
        else if (entry.page !== "settings")
            Ui.openControl(entry.page, entry.tab);
    }

    // The newest export in the home folder, offered for import.
    property string exportFile: ""
    Process {
        id: findExport
        command: ["bash", "-c", "ls -t \"$HOME\"/penumbra-settings-*.json 2>/dev/null | head -n 1"]
        stdout: StdioCollector { onStreamFinished: root.exportFile = text.trim() }
    }
    property string transferMessage: ""
    Process {
        id: transfer
        stdout: StdioCollector { id: transferOut }
        stderr: StdioCollector { id: transferErr }
        onExited: code => {
            root.transferMessage = code === 0 ? transferOut.text.trim().replace(Quickshell.env("HOME"), "~") : transferErr.text.trim();
            findExport.running = true;
        }
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
                glyph: "󰐊"
                title: "Animated wallpapers"
                subtitle: Settings.reducedMotion ? "Still while Reduced motion is on" : Settings.animatedWallpapers ? "Dawn, eclipse, GIFs and videos move" : "Still images"
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
                glyph: "󰘾"
                title: "Reduced motion"
                subtitle: "No animations in the shell, wallpapers or windows"
                checked: Settings.reducedMotion
                onToggled: Settings.reducedMotion = !Settings.reducedMotion
            }
            StepperRow {
                id: textSize
                readonly property var sizes: [1, 1.1, 1.25, 1.4]
                readonly property int current: Math.max(0, sizes.indexOf(Settings.textScale))
                glyph: "󰛖"
                title: "Text size"
                subtitle: "Scale labels across the shell"
                valueText: ["Default", "Large", "Larger", "Largest"][textSize.current]
                canDecrease: textSize.current > 0
                canIncrease: textSize.current < textSize.sizes.length - 1
                onDecreased: Settings.textScale = textSize.sizes[textSize.current - 1]
                onIncreased: Settings.textScale = textSize.sizes[textSize.current + 1]
            }
        }

        // ── Backup & restore ────────────────────────────────────────
        Section { text: "Backup & restore" }
        SettingsCard {
            ListRow {
                Layout.fillWidth: true
                glyph: "󰈝"
                title: "Export settings"
                subtitle: "Settings, look and screens, to one file in your home folder"
                busy: transfer.running
                onClicked: if (!transfer.running) {
                    transfer.command = [Ui.bin + "penumbra-settings", "export"];
                    transfer.running = true;
                }
            }
            ListRow {
                Layout.fillWidth: true
                visible: root.exportFile !== ""
                glyph: "󰈞"
                title: "Import settings"
                subtitle: "From " + root.exportFile.replace(/^.*\//, "~/")
                busy: transfer.running
                onClicked: if (!transfer.running) {
                    transfer.command = [Ui.bin + "penumbra-settings", "import", root.exportFile];
                    transfer.running = true;
                }
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 4
                visible: text !== ""
                text: root.transferMessage
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 4
                visible: root.exportFile === "" && root.transferMessage === ""
                text: "To import, put a penumbra-settings-….json file from another computer in your home folder."
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.dim
            }
        }
    }
}
