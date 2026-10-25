import QtQuick
import QtQuick.Layouts

// Settings: the corner style, the wallpaper and a few shell behaviours.
ColumnLayout {
    id: root

    readonly property var wallpaperNames: ({ "wallpaper": "Night", "wallpaper-dawn": "Dawn", "wallpaper-eclipse": "Eclipse" })

    spacing: 12

    component Section: Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    // A labelled on/off switch; the whole row toggles.
    component SwitchRow: Rectangle {
        id: row
        property string glyph
        property string title
        property string subtitle
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        implicitHeight: 52
        radius: Theme.radiusSmall
        color: rowArea.containsMouse ? Theme.raised : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        MouseArea {
            id: rowArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 11
            Glyph { Layout.preferredWidth: 22; text: row.glyph; size: 17 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: row.title }
                Label { Layout.fillWidth: true; text: row.subtitle; font.pixelSize: 11; color: Theme.muted }
            }
            Switch {
                checked: row.checked
                onToggled: row.toggled()
            }
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Settings"
        status: "Super+, opens this page"
        showSwitch: false
        onBack: Ui.controlPage = "main"
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
        font.pixelSize: 11
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
            subtitle: root.wallpaperNames[Ui.wallpaper] ?? Ui.wallpaper
            trailing: "󰅂"
            onClicked: Ui.toggleWallpapers()
        }
        SwitchRow {
            glyph: "󰐊"
            title: "Animated wallpapers"
            subtitle: Settings.animatedWallpapers ? "Dawn and eclipse move" : "Still images"
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
