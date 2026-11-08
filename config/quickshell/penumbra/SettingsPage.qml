import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings: the look, screens, keyboard, idle timings, default apps and notifications (each a page
// of its own), the wallpaper, accessibility, battery care, the clipboard and a few shell
// behaviours. Typing in the search field finds any of them, on this page or another.
ColumnLayout {
    id: root

    spacing: 12
    onVisibleChanged: if (visible) { Config.loadLayouts(); findExport.running = true; }
    Component.onCompleted: { Config.loadLayouts(); findExport.running = true; }

    component Section: Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
    }

    // What search finds: a page to open (page), or a row of this page (page: "settings").
    readonly property var index: [
        { page: "packages", glyph: "󰏗", title: "Installed packages", words: "software pacman aur foreign flatpak appimage uninstall update manage" },
        { page: "notes", glyph: "󰎞", title: "Quick notes", words: "notes draft text writing local sidebar" },
        { page: "look", glyph: "󰏘", title: "Look", words: "theme dark light auto colours colors accent hue vividness corners rounded sharp harmonize depth clock audio aura screen frame bezel" },
        { page: "displays", glyph: "󰍹", title: "Displays", words: "monitors screens resolution refresh rate scale rotation arrangement" },
        { page: "keyboard", glyph: "󰌌", title: "Keyboard", words: "layout variant options num lock xkb" },
        { page: "idle", glyph: "󰒲", title: "Idle and sleep", words: "dim lock screens off suspend timeout stay awake apps inhibit video calls" },
        { page: "apps", glyph: "󰀻", title: "Default apps", words: "browser file manager terminal" },
        { page: "notifications", glyph: "󰂚", title: "Notifications", words: "do not disturb dnd schedule fullscreen sharing sounds lock screen count mute quiet keep rules" },
        { page: "night", glyph: "󰖔", title: "Night light", words: "warmth temperature kelvin sunset sunrise schedule hyprsunset" },
        { page: "weather", glyph: "󰖐", title: "Weather", words: "location city coordinates forecast temperature calendar clock bar" },
        { page: "wifi", glyph: "󰤨", title: "Wi-Fi", words: "wireless network internet" },
        { page: "bluetooth", glyph: "󰂯", title: "Bluetooth", words: "devices headphones mouse pair battery" },
        { page: "mixer", glyph: "󰕾", title: "Sound", words: "audio volume output input microphone speakers apps" },
        { page: "cast", glyph: "󰄘", title: "Cast screen", words: "tv chromecast dlna firewall port" },
        { page: "wallpapers", glyph: "󰸉", title: "Wallpaper", words: "background picture image video gif" },
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
            Ui.controlPage = entry.page;
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
        placeholderText: "Search settings"
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
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.query !== ""
        spacing: 2
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
            Layout.leftMargin: 4
            visible: root.matches.length === 0
            text: "No setting matches"
            color: Theme.muted
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.query === ""
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: [
                    { page: "packages", glyph: "󰏗", title: "Installed packages", subtitle: "pacman, AUR, Flatpak and AppImage" },
                    { page: "notes", glyph: "󰎞", title: "Quick notes", subtitle: "A local draft, saved as you type" },
                    { page: "look", glyph: "󰏘", title: "Look", subtitle: Look.summary },
                    { page: "displays", glyph: "󰍹", title: "Displays", subtitle: Quickshell.screens.length > 1 ? `${Quickshell.screens.length} screens · arrangement, resolution, scale` : "Resolution, refresh rate, scale" },
                    { page: "keyboard", glyph: "󰌌", title: "Keyboard", subtitle: (Config.values.kb_layout ?? "").split(",").map(l => Config.layoutName(l)).join(", ") },
                    { page: "idle", glyph: "󰒲", title: "Idle and sleep", subtitle: `Lock after ${Config.duration(Config.values.idle_lock).toLowerCase()}` },
                    { page: "notifications", glyph: "󰂚", title: "Notifications", subtitle: "Do not disturb, sounds, app rules" },
                    { page: "apps", glyph: "󰀻", title: "Default apps", subtitle: "Browser, file manager, terminal" }
                ]
                delegate: ListRow {
                    required property var modelData
                    Layout.fillWidth: true
                    glyph: modelData.glyph
                    title: modelData.title
                    subtitle: modelData.subtitle
                    trailing: "󰅂"
                    onClicked: Ui.controlPage = modelData.page
                }
            }
        }

        Section { text: "Desktop" }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
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
            SwitchRow {
                visible: Settings.animatedWallpapers
                glyph: "󰖯"
                title: "Hold still behind windows"
                subtitle: "While tiled windows hide the wallpaper"
                checked: Settings.stillWhenCovered
                onToggled: Settings.stillWhenCovered = !Settings.stillWhenCovered
            }
            SwitchRow {
                visible: Settings.animatedWallpapers
                glyph: "󰌪"
                title: "Hold still to save power"
                subtitle: "On battery or in power saver"
                checked: Settings.stillOnBattery
                onToggled: Settings.stillOnBattery = !Settings.stillOnBattery
            }
            SwitchRow {
                glyph: "󰆾"
                title: "Hot corner"
                subtitle: "Top-right corner opens the control center"
                checked: Settings.hotCorner
                onToggled: Settings.hotCorner = !Settings.hotCorner
            }
        }

        Section { text: "Accessibility" }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            SwitchRow {
                glyph: "󰘾"
                title: "Reduced motion"
                subtitle: "No animations in the shell, wallpapers or windows"
                checked: Settings.reducedMotion
                onToggled: Settings.reducedMotion = !Settings.reducedMotion
            }
            RowLayout {
                id: textSize
                readonly property var sizes: [1, 1.1, 1.25, 1.4]
                readonly property int current: Math.max(0, sizes.indexOf(Settings.textScale))
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                spacing: 11
                Glyph { Layout.preferredWidth: 22; text: "󰛖"; size: 17 }
                Label { Layout.fillWidth: true; text: "Text size" }
                Stepper {
                    text: ["Default", "Large", "Larger", "Largest"][textSize.current]
                    textWidth: 92
                    canDecrease: textSize.current > 0
                    canIncrease: textSize.current < textSize.sizes.length - 1
                    onDecreased: Settings.textScale = textSize.sizes[textSize.current - 1]
                    onIncreased: Settings.textScale = textSize.sizes[textSize.current + 1]
                }
            }
        }

        Section { text: "Battery and clipboard" }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            // Only where the battery's firmware can stop charging early.
            RowLayout {
                id: battery
                readonly property var limits: [100, 90, 80, 60]
                readonly property int current: Math.max(0, limits.indexOf(Settings.batteryLimit))
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                visible: Sys.chargeLimitFile !== ""
                spacing: 11
                Glyph { Layout.preferredWidth: 22; text: "󰂄"; size: 17 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { Layout.fillWidth: true; text: "Battery care" }
                    Label {
                        Layout.fillWidth: true
                        text: !Sys.chargeLimitWritable ? "Run ./install.sh again to allow it" : Settings.batteryLimit < 100 ? "Stops charging early; the battery lasts more years" : "Charges to full"
                        font.pixelSize: Theme.textSmall
                        color: Sys.chargeLimitWritable ? Theme.muted : Theme.amber
                        wrapMode: Text.Wrap
                    }
                }
                Stepper {
                    text: Settings.batteryLimit < 100 ? `Up to ${Settings.batteryLimit}%` : "Full"
                    textWidth: 92
                    canDecrease: Sys.chargeLimitWritable && battery.current < battery.limits.length - 1
                    canIncrease: Sys.chargeLimitWritable && battery.current > 0
                    onDecreased: Settings.batteryLimit = battery.limits[battery.current + 1]
                    onIncreased: Settings.batteryLimit = battery.limits[battery.current - 1]
                }
            }
            RowLayout {
                id: clipboard
                readonly property var days: [0, 1, 7, 30]
                readonly property int current: Math.max(0, days.indexOf(Settings.clipboardDays))
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                spacing: 11
                Glyph { Layout.preferredWidth: 22; text: "󰅌"; size: 17 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { Layout.fillWidth: true; text: "Clipboard history" }
                    Label {
                        Layout.fillWidth: true
                        text: "Pinned entries always stay"
                        font.pixelSize: Theme.textSmall
                        color: Theme.muted
                    }
                }
                Stepper {
                    text: ["Kept", "1 day", "7 days", "30 days"][clipboard.current]
                    textWidth: 92
                    canDecrease: clipboard.current > 0
                    canIncrease: clipboard.current < clipboard.days.length - 1
                    onDecreased: Settings.clipboardDays = clipboard.days[clipboard.current - 1]
                    onIncreased: Settings.clipboardDays = clipboard.days[clipboard.current + 1]
                }
            }
        }

        Section { text: "Moving to another computer" }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
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
                Layout.leftMargin: 4
                visible: text !== ""
                text: root.transferMessage
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                visible: root.exportFile === "" && root.transferMessage === ""
                text: "To import, put a penumbra-settings-….json file from another computer in your home folder."
                wrapMode: Text.Wrap
                font.pixelSize: Theme.textSmall
                color: Theme.dim
            }
        }
    }
}
