import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Quick settings, sliders, media and notification history, under the status capsule.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge
    sheetWidth: 400
    open: Ui.controlOpen
    onDismissed: Ui.dismiss()

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    property string uptime: ""
    onOpenChanged: if (open) { uptimeFile.reload(); Sys.refreshBrightness(); }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = Number(text().split(" ")[0]), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = h ? `up ${h} h ${m} min` : `up ${m} min`;
        }
    }

    // One page at a time: the main view, or Wi-Fi / Bluetooth settings.
    ColumnLayout {
        id: pages
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 0

        Connections {
            target: Ui
            function onControlPageChanged() { pageIn.restart(); }
        }
        ParallelAnimation {
            id: pageIn
            NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
            NumberAnimation { target: pages; property: "x"; from: Ui.controlPage === "main" ? -6 : 42; to: 18; duration: Theme.slow; easing.type: Easing.OutExpo }
        }

        WifiPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "wifi"
            active: root.open && visible
        }

        BluetoothPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "bluetooth"
            active: root.open && visible
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Ui.controlPage === "main"
            spacing: 14

            // Header: who, how long, and session shortcuts.
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.violet }
                        GradientStop { position: 1; color: Theme.violetDeep }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: Quickshell.env("USER").charAt(0).toUpperCase()
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: Theme.violetInk
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: Quickshell.env("USER"); font.pixelSize: 14; font.weight: Font.DemiBold }
                    Label { text: root.uptime; font.pixelSize: 11; color: Theme.muted }
                }
                Repeater {
                    model: [
                        { glyph: "󰸉", tip: "Next wallpaper", run: () => Ui.run(Ui.bin + "nocturne-wallpaper next") },
                        { glyph: "󰌾", tip: "Lock", run: () => { Ui.close(); Ui.run("loginctl lock-session"); } },
                        { glyph: "󰐥", tip: "Session", run: () => Ui.openSession() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: headerArea.containsMouse ? Theme.hover : Theme.raised
                        border.color: Theme.line
                        Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 15; color: Theme.violetBright }
                        MouseArea {
                            id: headerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.run()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.networkGlyph
                    title: Devices.wifiDevice ? "Wi-Fi" : "Network"
                    subtitle: Devices.networkName
                    on: Devices.wifiDevice ? Networking.wifiEnabled : Devices.wired
                    hasMore: true
                    onToggled: Devices.wifiDevice ? Networking.wifiEnabled = !Networking.wifiEnabled : Ui.controlPage = "wifi"
                    onMore: Ui.controlPage = "wifi"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.bluetoothGlyph
                    title: "Bluetooth"
                    subtitle: Devices.bluetoothName
                    on: Devices.bluetoothOn
                    available: !!Devices.adapter
                    hasMore: true
                    onToggled: Devices.adapter.enabled = !Devices.adapter.enabled
                    onMore: Ui.controlPage = "bluetooth"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Notifs.dnd ? "󰂛" : "󰂚"
                    title: "Do not disturb"
                    subtitle: Notifs.dnd ? "Only critical alerts" : "Off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Ui.caffeine ? "󰅶" : "󰛊"
                    title: "Stay awake"
                    subtitle: Ui.caffeine ? "Idle lock paused" : "Off"
                    on: Ui.caffeine
                    onToggled: Ui.caffeine = !Ui.caffeine
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                SliderRow {
                    Layout.fillWidth: true
                    glyph: Devices.volumeGlyph
                    value: Devices.volume
                    muted: Devices.muted
                    onMoved: v => Devices.setVolume(v)
                    onGlyphClicked: if (Devices.sink) Devices.sink.muted = !Devices.sink.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: !!Devices.source
                    glyph: Devices.micMuted ? "󰍭" : "󰍬"
                    value: Devices.source ? Math.round(Devices.source.volume * 100) : 0
                    muted: Devices.micMuted
                    onMoved: v => { Devices.source.muted = false; Devices.source.volume = v / 100; }
                    onGlyphClicked: Devices.source.muted = !Devices.source.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: Sys.brightness >= 0
                    glyph: "󰃟"
                    value: Sys.brightness
                    onMoved: v => Sys.setBrightness(v)
                }
            }

            // Media
            Rectangle {
                Layout.fillWidth: true
                visible: !!root.player
                implicitHeight: 76
                radius: Theme.radius
                color: Theme.raised
                border.color: Theme.line
                RowLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 12
                    ClippingRectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 12
                        color: Theme.hover
                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: !root.player?.trackArtUrl
                            text: "󰎆"
                            size: 22
                            color: Theme.violetBright
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { Layout.fillWidth: true; text: root.player?.trackTitle || root.player?.identity || ""; font.weight: Font.DemiBold }
                        Label { Layout.fillWidth: true; text: root.player?.trackArtist || root.player?.identity || ""; font.pixelSize: 11; color: Theme.muted }
                    }
                    Repeater {
                        model: [
                            { glyph: "󰒮", run: () => root.player.previous(), ok: root.player?.canGoPrevious },
                            { glyph: root.player?.isPlaying ? "󰏤" : "󰐊", run: () => root.player.togglePlaying(), ok: root.player?.canTogglePlaying, main: true },
                            { glyph: "󰒭", run: () => root.player.next(), ok: root.player?.canGoNext }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: modelData.main ? 38 : 30
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            opacity: modelData.ok ? 1 : 0.4
                            color: modelData.main ? Theme.violet : mediaArea.containsMouse ? Theme.hover : "transparent"
                            Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 16; color: modelData.main ? Theme.violetInk : Theme.text }
                            MouseArea {
                                id: mediaArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!modelData.ok
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.run()
                            }
                        }
                    }
                }
            }

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Label {
                    Layout.fillWidth: true
                    text: Notifs.count ? `Notifications · ${Notifs.count}` : "Notifications"
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: Theme.muted
                }
                Label {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    font.pixelSize: 11
                    color: clearArea.containsMouse ? Theme.violetBright : Theme.violet
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clear()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Notifs.count ? Math.min(contentHeight, 340) : 0
                visible: Notifs.count > 0
                clip: true
                spacing: 8
                model: Notifs.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    required property var modelData
                    width: ListView.view.width
                    notification: modelData
                    compact: true
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                visible: Notifs.count === 0
                spacing: 4
                Glyph { Layout.fillWidth: true; text: "󰂜"; size: 26; color: Theme.dim }
                Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "All caught up"; color: Theme.muted }
            }
        }
    }
}
