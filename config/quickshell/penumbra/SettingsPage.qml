import QtQuick
import QtQuick.Layouts
import Quickshell

// Settings: screens, keyboard, idle timings and default apps (each a page of its own), the corner
// style, the wallpaper and a few shell behaviours.
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

    Section { text: "Corners" }

    // Each card draws a little bar and window in its own style.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { name: "rounded", title: "Rounded", round: true },
                { name: "sharp", title: "Sharp", round: false }
            ]
            delegate: Rectangle {
                id: choice
                required property var modelData
                readonly property bool current: Theme.corners === modelData.name
                readonly property color ink: current ? Theme.violet : Theme.lineStrong
                function r(px) { return modelData.round ? px : 0; }

                Layout.fillWidth: true
                Layout.preferredWidth: 1 // equal halves
                implicitHeight: 118
                radius: Theme.radius
                color: current ? Theme.alpha(Theme.violet, 0.12) : area.containsMouse ? Theme.hover : Theme.raised
                border.width: current ? 2 : 1
                border.color: current ? Theme.violet : Theme.line
                Behavior on color { ColorAnimation { duration: Theme.fast } }

                Item {
                    id: preview
                    anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                    width: 116
                    height: 62
                    Rectangle {
                        width: parent.width
                        height: 10
                        radius: choice.r(5)
                        color: Theme.glass
                        border.color: choice.ink
                        Rectangle { x: 4; y: 3; width: 14; height: 4; radius: choice.r(2); color: choice.ink }
                    }
                    Rectangle {
                        y: 16
                        width: parent.width
                        height: parent.height - y
                        radius: choice.r(9)
                        color: Theme.surface
                        border.color: choice.ink
                        Rectangle { x: 9; y: 10; width: 44; height: 5; radius: choice.r(2.5); color: choice.ink }
                        Rectangle { x: 9; y: 21; width: 70; height: 4; radius: choice.r(2); color: Theme.line }
                        Rectangle { x: 9; y: 30; width: 56; height: 4; radius: choice.r(2); color: Theme.line }
                    }
                }
                RowLayout {
                    anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
                    spacing: 6
                    Rectangle {
                        visible: choice.current
                        implicitWidth: 6
                        implicitHeight: 6
                        radius: Theme.corner(3)
                        color: Theme.violet
                    }
                    Label {
                        text: choice.modelData.title
                        font.weight: choice.current ? Font.DemiBold : Font.Normal
                        color: choice.current ? Theme.text : Theme.textSoft
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!choice.current)
                            Ui.run(Ui.bin + "penumbra-corners " + choice.modelData.name);
                    }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        text: "The shell, windows, launcher and lock screen follow it"
        font.pixelSize: Theme.textSmall
        color: Theme.dim
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
            glyph: "󰆾"
            title: "Hot corner"
            subtitle: "Top-right corner opens the control center"
            checked: Settings.hotCorner
            onToggled: Settings.hotCorner = !Settings.hotCorner
        }
    }
}
