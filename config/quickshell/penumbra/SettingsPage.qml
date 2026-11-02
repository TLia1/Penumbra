import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings: the look, screens, keyboard, idle timings and default apps (each a page of its own), the
// wallpaper and a few shell behaviours.
ColumnLayout {
    id: root

    spacing: 12
    onVisibleChanged: if (visible) Config.loadLayouts()

    component Section: Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Settings"
        status: "Super+, opens this page"
        showSwitch: false
        onBack: Ui.controlPage = "main"
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: [
                { page: "look", glyph: "󰏘", title: "Look", subtitle: Look.summary },
                { page: "displays", glyph: "󰍹", title: "Displays", subtitle: Quickshell.screens.length > 1 ? `${Quickshell.screens.length} screens · arrangement, resolution, scale` : "Resolution, refresh rate, scale" },
                { page: "keyboard", glyph: "󰌌", title: "Keyboard", subtitle: (Config.values.kb_layout ?? "").split(",").map(l => Config.layoutName(l)).join(", ") },
                { page: "idle", glyph: "󰒲", title: "Idle and sleep", subtitle: `Lock after ${Config.duration(Config.values.idle_lock).toLowerCase()}` },
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
            onClicked: Ui.toggleWallpapers()
        }
        SwitchRow {
            glyph: "󰐊"
            title: "Animated wallpapers"
            subtitle: Settings.animatedWallpapers ? "Dawn, eclipse, GIFs and videos move" : "Still images"
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
}
