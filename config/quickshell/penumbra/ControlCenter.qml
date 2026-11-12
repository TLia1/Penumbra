import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower

// Quick settings, sliders and notification history, under the status capsule.
Panel {
    id: root
    originKey: "control"
    anchors { top: true; right: true }
    margins.right: edgeMargin - shadowRoom
    preferredSheetWidth: 440
    open: Ui.controlOpen
    onDismissed: Ui.dismiss()

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
    // and the settings' own pages. A page taller than the room under the bar scrolls.
    Flickable {
        id: scroller
        x: Theme.padding
        y: Theme.padding
        width: root.sheetWidth - 2 * Theme.padding
        // The sheet's padding and shadow room above and below.
        height: Math.min(pages.implicitHeight, root.height - 2 * root.shadowRoom - 2 * Theme.padding)
        contentWidth: width
        contentHeight: pages.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        // Each page, and each opening, starts at the top.
        Connections {
            target: root
            function onOpenChanged() { scroller.contentY = 0; }
        }

        ColumnLayout {
            id: pages
            width: scroller.width
            spacing: 0

            Connections {
                target: Ui
                function onControlPageChanged() { scroller.contentY = 0; pageIn.restart(); }
            }
            ParallelAnimation {
                id: pageIn
                NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
                NumberAnimation { target: pages; property: "x"; from: Ui.controlPage === "main" ? -24 : 24; to: 0; duration: Theme.slow; easing.type: Easing.OutExpo }
            }

            // Pages are built when first shown and dropped when left: most of the time the control
            // center is closed, and what must outlive a page lives in the singletons.
            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "wifi"
                visible: active
                sourceComponent: Component { WifiPage { active: root.open } }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "bluetooth"
                visible: active
                sourceComponent: Component { BluetoothPage { active: root.open } }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "mixer"
                visible: active
                sourceComponent: Component { MixerPage { active: root.open } }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "night"
                visible: active
                sourceComponent: Component { NightLightPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "weather"
                visible: active
                sourceComponent: Component { WeatherPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "cast"
                visible: active
                sourceComponent: Component { CastPage { active: root.open } }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "settings"
                visible: active
                sourceComponent: Component { SettingsPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "look"
                visible: active
                sourceComponent: Component { LookPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "displays"
                visible: active
                sourceComponent: Component { DisplaysPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "keyboard"
                visible: active
                sourceComponent: Component { KeyboardPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "idle"
                visible: active
                sourceComponent: Component { IdlePage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "notifications"
                visible: active
                sourceComponent: Component { NotificationsPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "packages"
                visible: active
                sourceComponent: Component { PackagesPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "apps"
                visible: active
                sourceComponent: Component { AppsPage {} }
            }

            Loader {
                Layout.fillWidth: true
                active: Ui.controlPage === "notes"
                visible: active
                sourceComponent: Component { NotesPage {} }
            }

            ColumnLayout {
                id: mainPage
                Layout.fillWidth: true
                visible: Ui.controlPage === "main"
                spacing: 12

                // Header: who, how long, and session shortcuts.
                RowLayout {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 0 }
                    Layout.fillWidth: true
                    spacing: 10
                    Avatar { size: 42 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label { text: Quickshell.env("USER"); font.pixelSize: Theme.textLarge; font.weight: Font.DemiBold }
                        Label { text: root.uptime; font.pixelSize: Theme.textSmall; color: Theme.muted }
                    }
                    Repeater {
                        model: [
                            { glyph: "󰒓", tip: "Settings", run: () => Ui.openControl("settings") },
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

                // Six toggleable quick states in a symmetrical 2x3 grid.
                GridLayout {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 1 }
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
                        onToggled: Devices.wifiDevice ? Networking.wifiEnabled = !Networking.wifiEnabled : Ui.openControl("wifi")
                        onMore: Ui.openControl("wifi")
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
                        onMore: Ui.openControl("bluetooth")
                    }
                    Tile {
                        Layout.fillWidth: true
                        glyph: Notifs.dnd ? "󰂛" : "󰂚"
                        title: "Do not disturb"
                        subtitle: Notifs.dndStatus
                        on: Notifs.dnd
                        hasMore: true
                        onToggled: Notifs.toggleDnd()
                        onMore: Ui.openControl("notifications")
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
                        onMore: Ui.openControl("night")
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
                        glyph: Cast.casting ? "󰄙" : "󰄘"
                        title: "Cast screen"
                        subtitle: Cast.connecting ? "Connecting…" : Cast.casting ? Cast.tvName : "Off"
                        on: Cast.casting
                        hasMore: true
                        onToggled: Cast.casting ? Cast.stop() : Ui.openControl("cast")
                        onMore: Ui.openControl("cast")
                    }
                }

                // Quick actions strip for instant tools (Screenshot, Wallpaper, Download, Quick notes).
                RowLayout {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 2 }
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { glyph: "󰹑", title: "Screenshot", run: () => Ui.openShot() },
                            { glyph: "󰸉", title: "Wallpaper", run: () => Ui.toggle("wallpapers") },
                            { glyph: "󰇚", title: "Download", run: () => Ui.toggle("downloads") },
                            { glyph: "󰎞", title: "Notes", run: () => Ui.openControl("notes") }
                        ]
                        delegate: Rectangle {
                            id: quickAction
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 38
                            radius: Theme.radiusSmall
                            color: actionArea.containsMouse ? Theme.hover : Theme.control
                            border.color: Theme.line
                            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
                            CardLight { radius: quickAction.radius; pointer: Qt.point(actionArea.mouseX, actionArea.mouseY); hovered: actionArea.containsMouse }
                            RowLayout {
                                anchors.centerIn: parent
                                width: Math.min(implicitWidth, parent.width - 10)
                                spacing: 6
                                Glyph { text: quickAction.modelData.glyph; size: 15; color: Theme.accentBright }
                                Label { Layout.fillWidth: true; text: quickAction.modelData.title; font.pixelSize: Theme.textSmall; font.weight: Font.Medium; color: Theme.textSoft }
                            }
                            MouseArea {
                                id: actionArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: quickAction.modelData.run()
                            }
                        }
                    }
                }

                // Audio, brightness and power profile grouped into a single clean surface.
                Rectangle {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 3 }
                    Layout.fillWidth: true
                    implicitHeight: slidersColumn.implicitHeight + 20
                    radius: Theme.radius
                    color: Theme.alpha(Theme.control, 0.45)
                    border.color: Theme.line

                    ColumnLayout {
                        id: slidersColumn
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        spacing: 6

                        SliderRow {
                            Layout.fillWidth: true
                            glyph: Devices.volumeGlyph
                            value: Devices.volume
                            muted: Devices.muted
                            hasMore: true
                            onMoved: v => Devices.setVolume(v)
                            onGlyphClicked: if (Devices.sink) Devices.sink.muted = !Devices.sink.muted
                            onMore: Ui.openControl("mixer")
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            Layout.rightMargin: 36
                            visible: !!Devices.source
                            glyph: Devices.micMuted ? "󰍭" : "󰍬"
                            value: Devices.source ? Math.round(Devices.source.volume * 100) : 0
                            muted: Devices.micMuted
                            onMoved: v => { Devices.source.muted = false; Devices.source.volume = v / 100; }
                            onGlyphClicked: Devices.source.muted = !Devices.source.muted
                        }
                        SliderRow {
                            Layout.fillWidth: true
                            Layout.rightMargin: 36
                            visible: Sys.brightness >= 0
                            glyph: "󰃟"
                            value: Sys.brightness
                            onMoved: v => Sys.setBrightness(v)
                        }

                        // Power profile, through power-profiles-daemon.
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            Layout.bottomMargin: 2
                            visible: Ui.hasPowerProfiles
                            implicitHeight: 1
                            color: Theme.line
                        }
                        Segmented {
                            Layout.fillWidth: true
                            visible: Ui.hasPowerProfiles
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
                            visible: Ui.hasPowerProfiles && PowerProfiles.profile === PowerProfile.Performance && PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                            text: PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
                                ? "Performance is limited while the laptop is on your lap"
                                : "Performance is limited while the computer is hot"
                            font.pixelSize: Theme.textSmall
                            color: Theme.amber
                        }
                    }
                }

                // Notifications
                RowLayout {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 4 }
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
                    Layout.preferredHeight: Notifs.count ? Math.min(contentHeight, 340) : 0
                    visible: Notifs.count > 0
                    clip: true
                    spacing: 12
                    // Keyed by app name: the group objects are rebuilt on every notification,
                    // but the names stay, so existing delegates are kept and `displaced` runs.
                    model: ScriptModel { values: Notifs.groups.map(g => g.app) }
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: ColumnLayout {
                        id: group
                        required property int index
                        StaggerReveal { shown: root.open && mainPage.visible; order: 5 + group.index }
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
                                // While the pointer is on the rule button, what it does instead of the count.
                                text: group.app + (ruleArea.containsMouse
                                    ? " · " + ({ "": "click: no popups", "silent": "no popups · click: mute",
                                                 "mute": "muted · click: always keep", "keep": "always kept · click: normal" })[Notifs.rule(group.app)]
                                    : group.items.length > 1 ? ` · ${group.items.length}` : "")
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
                            // The app's rule: normal, no popups, muted, or kept; each click moves to the next.
                            Glyph {
                                Layout.leftMargin: 8
                                readonly property string rule: Notifs.rule(group.app)
                                readonly property var next: ({ "": "silent", "silent": "mute", "mute": "keep", "keep": "" })
                                text: ({ "": "󰂚", "silent": "󰂠", "mute": "󰂛", "keep": "󰐃" })[rule] ?? "󰂚"
                                size: 13
                                color: ruleArea.containsMouse ? Theme.text : rule ? Theme.accent : Theme.dim
                                MouseArea {
                                    id: ruleArea
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Settings.setRule(group.app, parent.next[parent.rule] ?? "")
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

                Rectangle {
                    StaggerReveal { shown: root.open && mainPage.visible; order: 5 }
                    Layout.fillWidth: true
                    visible: Notifs.count === 0
                    implicitHeight: 42
                    radius: Theme.radiusSmall
                    color: Theme.alpha(Theme.control, 0.35)
                    border.color: Theme.line
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Glyph { text: "󰂜"; size: 16; color: Theme.dim }
                        Label { text: "All caught up"; font.pixelSize: Theme.textSmall; color: Theme.muted }
                    }
                }
            }
        }
    }
}
