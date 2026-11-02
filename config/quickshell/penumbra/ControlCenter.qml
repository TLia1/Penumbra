import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Widgets

// Quick settings, sliders, media and notification history, under the status capsule.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge - shadowRoom
    sheetWidth: 400
    open: Ui.controlOpen
    onDismissed: Ui.dismiss()

    readonly property var player: Media.player
    property var expandedApps: []

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

    // One page at a time: the main view, or Wi-Fi, Bluetooth, sound, night light, casting, settings
    // and the settings' own pages.
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

        MixerPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "mixer"
            active: root.open && visible
        }

        NightLightPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "night"
        }

        CastPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "cast"
            active: root.open && visible
        }

        SettingsPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "settings"
        }

        LookPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "look"
        }

        DisplaysPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "displays"
        }

        KeyboardPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "keyboard"
        }

        IdlePage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "idle"
        }

        AppsPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "apps"
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Ui.controlPage === "main"
            spacing: 14

            // Header: who, how long, and session shortcuts.
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Avatar { size: 42 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: Quickshell.env("USER"); font.pixelSize: Theme.textLarge; font.weight: Font.DemiBold }
                    Label { text: root.uptime; font.pixelSize: Theme.textSmall; color: Theme.muted }
                }
                Repeater {
                    model: [
                        { glyph: "󰒓", tip: "Settings", run: () => Ui.controlPage = "settings" },
                        { glyph: "󰸉", tip: "Wallpaper", run: () => Ui.toggleWallpapers() },
                        { glyph: "󰌾", tip: "Lock", run: () => { Ui.close(); Ui.run("loginctl lock-session"); } },
                        { glyph: "󰐥", tip: "Session", run: () => Ui.openSession() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: Theme.corner(18)
                        color: headerArea.containsMouse ? Theme.hover : Theme.raised
                        border.color: Theme.line
                        Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 15; color: Theme.accentBright }
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
                Tile {
                    Layout.fillWidth: true
                    glyph: "󱩌"
                    title: "Night light"
                    subtitle: NightLight.status
                    on: NightLight.on
                    available: NightLight.available
                    hasMore: true
                    onToggled: NightLight.toggle()
                    onMore: Ui.controlPage = "night"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: "󰹑"
                    title: "Screenshot"
                    subtitle: "Picture or video"
                    onToggled: Ui.openShot()
                }
                // The odd one out spans the row.
                Tile {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    glyph: Cast.casting ? "󰄙" : "󰄘"
                    title: "Cast screen"
                    subtitle: Cast.connecting ? `Connecting to ${Cast.tvName}…` : Cast.casting ? `Casting to ${Cast.tvName}` : "Show this screen on a TV"
                    on: Cast.casting
                    hasMore: true
                    onToggled: Cast.casting ? Cast.stop() : Ui.controlPage = "cast"
                    onMore: Ui.controlPage = "cast"
                }
            }

            // Power profile, through power-profiles-daemon.
            ColumnLayout {
                Layout.fillWidth: true
                visible: Ui.hasPowerProfiles
                spacing: 6
                Segmented {
                    Layout.fillWidth: true
                    current: PowerProfiles.profile
                    options: [
                        { value: PowerProfile.PowerSaver, glyph: "󰌪", title: "Power saver" },
                        { value: PowerProfile.Balanced, glyph: "󰗑", title: "Balanced" },
                        { value: PowerProfile.Performance, glyph: "󰓅", title: "Performance", available: PowerProfiles.hasPerformanceProfile }
                    ]
                    onChosen: value => PowerProfiles.profile = value
                }
                // Performance can be held back by the hardware; say why.
                Label {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    visible: PowerProfiles.profile === PowerProfile.Performance && PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                    text: PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
                        ? "Performance is limited while the laptop is on your lap"
                        : "Performance is limited while the computer is hot"
                    font.pixelSize: Theme.textSmall
                    color: Theme.amber
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    SliderRow {
                        Layout.fillWidth: true
                        glyph: Devices.volumeGlyph
                        value: Devices.volume
                        muted: Devices.muted
                        onMoved: v => Devices.setVolume(v)
                        onGlyphClicked: if (Devices.sink) Devices.sink.muted = !Devices.sink.muted
                    }
                    // Devices and per-app volume.
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 36
                        radius: Theme.radiusSmall
                        color: mixerArea.containsMouse ? Theme.hover : "transparent"
                        Glyph { anchors.centerIn: parent; text: "󰅂"; color: Theme.muted }
                        MouseArea {
                            id: mixerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ui.controlPage = "mixer"
                        }
                    }
                }
                SliderRow {
                    Layout.fillWidth: true
                    Layout.rightMargin: 28
                    visible: !!Devices.source
                    glyph: Devices.micMuted ? "󰍭" : "󰍬"
                    value: Devices.source ? Math.round(Devices.source.volume * 100) : 0
                    muted: Devices.micMuted
                    onMoved: v => { Devices.source.muted = false; Devices.source.volume = v / 100; }
                    onGlyphClicked: Devices.source.muted = !Devices.source.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    Layout.rightMargin: 28
                    visible: Sys.brightness >= 0
                    glyph: "󰃟"
                    value: Sys.brightness
                    onMoved: v => Sys.setBrightness(v)
                }
            }

            // Media: blurred cover art behind the track, controls and a seek bar.
            ClippingRectangle {
                id: media
                Layout.fillWidth: true
                visible: !!root.player
                implicitHeight: mediaColumn.implicitHeight + 20
                radius: Theme.radius
                color: Theme.raised
                border.color: Theme.line

                Image {
                    id: artwork
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    sourceSize.width: 200
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: artwork
                    visible: artwork.status === Image.Ready
                    blurEnabled: true
                    blur: 1
                    blurMax: 48
                    saturation: 0.2
                    opacity: 0.45
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.alpha(Theme.surface, 0.55) }
                        GradientStop { position: 1; color: Theme.alpha(Theme.surface, 0.15) }
                    }
                }

                // MPRIS doesn't announce position changes; ask while it's on screen.
                Timer {
                    interval: 1000
                    repeat: true
                    running: root.open && !!root.player?.isPlaying
                    onTriggered: root.player.positionChanged()
                }
                ColumnLayout {
                    id: mediaColumn
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        ClippingRectangle {
                            implicitWidth: 56
                            implicitHeight: 56
                            radius: Theme.corner(12)
                            color: Theme.hover
                            Image {
                                anchors.fill: parent
                                source: root.player?.trackArtUrl ?? ""
                                sourceSize: Qt.size(112, 112)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: !root.player?.trackArtUrl
                                text: "󰎆"
                                size: 22
                                color: Theme.accentBright
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label { Layout.fillWidth: true; text: root.player?.trackTitle || Media.appName(root.player); font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                // A live stream has nothing to seek through; say so instead.
                                Rectangle {
                                    visible: Media.isLive(root.player)
                                    implicitWidth: liveLabel.implicitWidth + 12
                                    implicitHeight: 16
                                    radius: Theme.corner(8)
                                    color: Theme.alpha(Theme.rose, 0.18)
                                    border.color: Theme.alpha(Theme.rose, 0.5)
                                    Label {
                                        id: liveLabel
                                        anchors.centerIn: parent
                                        text: "LIVE"
                                        font.pixelSize: Theme.textTiny
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.8
                                        color: Theme.rose
                                    }
                                }
                                Label { Layout.fillWidth: true; text: root.player?.trackArtist || Media.appName(root.player); font.pixelSize: Theme.textSmall; color: Theme.textSoft }
                            }
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
                                radius: Theme.corner(implicitWidth / 2)
                                opacity: modelData.ok ? 1 : 0.4
                                color: modelData.main ? Theme.accent : mediaArea.containsMouse ? Theme.hover : "transparent"
                                Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 16; color: modelData.main ? Theme.onAccent : Theme.text }
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
                    RowLayout {
                        Layout.fillWidth: true
                        visible: Media.hasLength(root.player)
                        spacing: 10
                        Label {
                            text: Media.time(root.player?.position ?? 0)
                            font.pixelSize: Theme.textTiny
                            color: Theme.textSoft
                        }
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: 14
                            readonly property real progress: root.player?.length > 0 ? Math.min(1, root.player.position / root.player.length) : 0
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: seekArea.containsMouse ? 6 : 4
                                radius: Theme.corner(height / 2)
                                color: Theme.overlayStrong
                                Behavior on height { NumberAnimation { duration: Theme.fast } }
                                Rectangle {
                                    width: parent.width * parent.parent.progress
                                    height: parent.height
                                    radius: Theme.corner(height / 2)
                                    color: Theme.accent
                                }
                            }
                            MouseArea {
                                id: seekArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: root.player?.canSeek ?? false
                                cursorShape: Qt.PointingHandCursor
                                function seek(x) {
                                    root.player.position = Math.max(0, Math.min(1, x / width)) * root.player.length;
                                }
                                onPressed: m => seek(m.x)
                                onPositionChanged: m => { if (pressed) seek(m.x); }
                            }
                        }
                        Label {
                            text: Media.time(root.player?.length ?? 0)
                            font.pixelSize: Theme.textTiny
                            color: Theme.textSoft
                        }
                    }
                }
            }

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Overline {
                    Layout.fillWidth: true
                    text: Notifs.count ? `Notifications · ${Notifs.count}` : "Notifications"
                }
                Label {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    font.pixelSize: Theme.textSmall
                    color: clearArea.containsMouse ? Theme.accentBright : Theme.accent
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

            // Grouped by app; each group shows its newest notification until expanded.
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Notifs.count ? Math.min(contentHeight, 360) : 0
                visible: Notifs.count > 0
                clip: true
                spacing: 12
                // Keyed by app name: the group objects are rebuilt on every notification,
                // but the names stay, so existing delegates are kept and `displaced` runs.
                model: ScriptModel { values: Notifs.groups.map(g => g.app) }
                boundsBehavior: Flickable.StopAtBounds
                delegate: ColumnLayout {
                    id: group
                    required property string modelData
                    readonly property string app: modelData
                    readonly property var items: Notifs.groups.find(g => g.app === app)?.items ?? []
                    readonly property bool expanded: root.expandedApps.includes(app)
                    width: ListView.view.width
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Label {
                            Layout.fillWidth: true
                            text: group.app + (group.items.length > 1 ? ` · ${group.items.length}` : "")
                            font.pixelSize: Theme.textSmall
                            font.weight: Font.DemiBold
                            color: Theme.textSoft
                        }
                        Label {
                            visible: group.items.length > 1
                            text: group.expanded ? "Show less" : "Show all"
                            font.pixelSize: Theme.textSmall
                            color: expandArea.containsMouse ? Theme.accentBright : Theme.accent
                            MouseArea {
                                id: expandArea
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expandedApps = group.expanded
                                    ? root.expandedApps.filter(a => a !== group.app)
                                    : [...root.expandedApps, group.app]
                            }
                        }
                        Glyph {
                            Layout.leftMargin: 8
                            text: "󰎟"
                            size: 13
                            color: clearGroup.containsMouse ? Theme.text : Theme.dim
                            MouseArea {
                                id: clearGroup
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.clearApp(group.app)
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel { values: group.expanded ? group.items : group.items.slice(0, 1) }
                        delegate: NotificationCard {
                            required property var modelData
                            Layout.fillWidth: true
                            notification: modelData
                            compact: true
                        }
                    }
                }
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
