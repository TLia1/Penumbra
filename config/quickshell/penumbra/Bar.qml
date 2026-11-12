import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Floating capsules: launcher, clock, workspaces and media left; focused window centered; status right.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    readonly property bool island: Settings.barStyle === "island"
    margins { top: island ? 0 : 10; left: Settings.barStyle === "framed" ? 3 : Theme.edge; right: Settings.barStyle === "framed" ? 3 : Theme.edge }
    implicitHeight: Theme.barHeight + (island ? 10 : 0)
    exclusiveZone: Theme.barHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "penumbra-bar"

    // Explicit layout coordinates keep the origin live as capsules resize or appear.
    readonly property var panelOrigins: ({
        calendar: margins.left + content.x + leftSide.x + clockCapsule.x + clockCapsule.width / 2,
        control: margins.left + content.x + rightSide.x + controls.x + controls.width / 2,
        monitor: margins.left + content.x + rightSide.x + monitor.x + monitor.width / 2,
        updates: margins.left + content.x + rightSide.x + updatesCapsule.x + updatesCapsule.width / 2,
        wallpapers: margins.left + content.x + rightSide.x + controls.x + controls.width / 2,
        downloads: margins.left + content.x + rightSide.x + controls.x + controls.width / 2
    })
    onPanelOriginsChanged: if (screen) Ui.setPanelOrigins(screen.name, panelOrigins)
    Component.onCompleted: if (screen) Ui.setPanelOrigins(screen.name, panelOrigins)

    IdleInhibitor {
        window: bar
        // Stay awake, or an app chosen in Settings → Idle and sleep is open.
        enabled: Ui.stayAwake
    }

    Item {
    id: content
    anchors.horizontalCenter: parent.horizontalCenter
    y: bar.island ? 6 : 0
    width: bar.island ? Math.min(bar.width, leftSide.implicitWidth + rightSide.implicitWidth + 3 * Theme.gap) : bar.width
    height: Theme.barHeight
    Rectangle { anchors.fill: parent; visible: Settings.barStyle === "framed"; color: Theme.surface }
    IslandSurface {
        visible: bar.island
        x: -Theme.gap; y: -6
        width: parent.width + 2 * Theme.gap
        height: parent.height + 10
    }
    HoverHandler {
        onPointChanged: bar.updateTip(point.position)
        onHoveredChanged: if (!hovered) bar.updateTip(null)
    }

    // ── Left ────────────────────────────────────────────────────────
    RowLayout {
        id: leftSide
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            id: launcherCapsule
            padding: 14
            tip: "Applications · right-click for the clipboard"
            active: Ui.launcherOpen
            onClicked: m => Ui.toggleLauncher(m.button === Qt.RightButton ? "clipboard" : "apps")
            Glyph { text: Theme.distroGlyph; size: 20; color: Ui.launcherOpen ? Theme.accentInk : Theme.accentBright }
        }

        Capsule {
            id: clockCapsule
            padding: 18
            active: Ui.calendarOpen
            tip: Qt.formatDateTime(Clock.date, "dddd d MMMM yyyy")
            onClicked: Ui.toggle("calendar")
            Label {
                text: Qt.formatDateTime(Clock.date, "HH:mm")
                font.pixelSize: Theme.textLarge
                font.weight: Font.Bold
                color: Ui.calendarOpen ? Theme.accentInk : Theme.text
            }
        }

        // Weather uses the same opt-in cached request as Calendar.
        Capsule {
            id: weatherCapsule
            shown: Settings.weatherEnabled && Settings.weatherInBar && !!Weather.current && !Weather.stale
            padding: 10
            tip: Weather.description
            onClicked: Ui.toggle("calendar")
            Glyph { text: Weather.current?.weather_code === 0 ? "󰖙" : "󰖐"; color: Theme.accentBright }
            Label { text: Math.round(Weather.current?.temperature_2m ?? 0) + "°" }
        }

        WorkspaceStrip {
            id: workspaceStrip
            workspaces: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor?.name === bar.screen.name && (w.toplevels.values.length > 0 || w.focused || w.active))
                .sort((a, b) => a.id - b.id)
            showIcons: Settings.workspaceStyle === "icons" && bar.width - rightSide.width > 850
        }

        MediaCapsule {}
    }

    // ── Center ──────────────────────────────────────────────────────
    // The focused window holds the exact center.
    RowLayout {
        anchors.centerIn: parent
        Capsule {
            id: title
            // The Wayland toplevel protocol knows the focused window from startup; nothing is
            // activated on an empty workspace. Show it on the bar of the screen it is on.
            readonly property var client: ToplevelManager.activeToplevel
            readonly property var entry: client ? DesktopEntries.heuristicLookup(client.appId) : null
            // Most windows end their title with the app's name ("… — Mozilla Firefox"); the icon says that.
            readonly property string text: {
                const t = client?.title ?? "";
                const m = t.match(/^(.+)\s[—–-]\s(.+)$/);
                const names = [entry?.name, client?.appId].filter(n => n).map(n => n.toLowerCase());
                return m && names.some(n => m[2].toLowerCase().includes(n)) ? m[1] : t;
            }
            readonly property real availableWidth: 2 * Math.min(content.width / 2 - leftSide.x - leftSide.width,
                rightSide.x - content.width / 2) - 2 * Theme.gap
            shown: !bar.island && availableWidth >= 80 && !!client && client.activated && text !== "" && client.screens.some(s => s.name === bar.screen.name)
            interactive: false
            padding: 15
            spacing: 8
            tip: shown ? client.title : ""
            IconImage {
                visible: source !== ""
                implicitSize: 15
                source: title.entry?.icon ? Quickshell.iconPath(title.entry.icon, true) : ""
                asynchronous: true
            }
            Label {
                text: title.text
                // As wide as the room between the side capsules allows, up to a point.
                Layout.maximumWidth: Math.max(0, Math.min(300, title.availableWidth - 60))
                color: Theme.textSoft
            }
        }
    }

    // ── Right ───────────────────────────────────────────────────────
    RowLayout {
        id: rightSide
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        // A capture's timer counting down; click to cancel.
        Capsule {
            shown: Recorder.countdown > 0
            padding: 14
            tip: "Click to cancel"
            onClicked: Recorder.cancel()
            Glyph { text: "󰔛"; color: Theme.amber }
            Label { text: Recorder.countdown; font.weight: Font.Bold; color: Theme.amber }
        }

        // A screen recording and how long it has run; click to stop, right-click to pause.
        Capsule {
            shown: Recorder.recording
            padding: 14
            tip: Recorder.paused ? "Paused · right-click to go on · click to stop" : "Recording · click to stop (or Ctrl+Print) · right-click to pause"
            color: hovered ? Theme.alpha(Theme.rose, 0.3) : Theme.alpha(Theme.rose, 0.16)
            border.color: Theme.alpha(Theme.rose, 0.5)
            onClicked: m => m.button === Qt.RightButton ? Recorder.togglePause() : Recorder.stop()
            Glyph { visible: Recorder.paused; text: "󰏤"; size: 12; color: Theme.rose }
            Rectangle {
                visible: !Recorder.paused
                implicitWidth: 9
                implicitHeight: 9
                radius: Theme.corner(4.5)
                color: Theme.rose
                SequentialAnimation on opacity {
                    running: Recorder.recording && !Recorder.paused && !Theme.reducedMotion
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }
            Label { text: Recorder.elapsedText; font.weight: Font.Bold; color: Theme.rose }
        }

        // Casting to a TV; click for the Cast page.
        Capsule {
            id: castCapsule
            shown: Cast.casting
            padding: 14
            active: Ui.controlOpen && Ui.controlPage === "cast"
            tip: Cast.connecting ? `Connecting to ${Cast.tvName}…` : `Casting to ${Cast.tvName} · click to manage`
            onClicked: Ui.openControl("cast")
            Glyph { text: "󰄙"; color: castCapsule.active ? Theme.accentInk : Theme.accentBright }
            Label { text: Cast.tvName; font.weight: Font.Bold; color: castCapsule.active ? Theme.accentInk : Theme.accentBright }
        }

        Capsule {
            shown: Devices.layouts.length > 1
            padding: 14
            tip: `${Devices.layoutName} · click to switch`
            onClicked: Devices.nextLayout()
            Glyph { text: "󰌌"; color: Theme.textSoft }
            Label { text: Devices.layoutCode; font.weight: Font.Bold; color: Theme.textSoft }
        }

        // Pending updates; also there when a restart is due, with its own glyph.
        Capsule {
            shown: Sys.updates > 0 || Sys.restartReasons.length > 0
            padding: 12
            active: Ui.updatesOpen
            tip: Sys.updatesDetail
            id: updatesCapsule
            onClicked: Ui.toggle("updates")
            Glyph { visible: Sys.updates > 0; text: "󰚰"; color: Ui.updatesOpen ? Theme.accentInk : Theme.accentBright }
            Label { visible: Sys.updates > 0; text: Sys.updates; color: Ui.updatesOpen ? Theme.accentInk : Theme.accentBright }
            Glyph { visible: Sys.restartReasons.length > 0; text: "󰜉"; color: Ui.updatesOpen ? Theme.accentInk : Theme.amber }
        }

        Capsule {
            id: monitor
            padding: 12
            spacing: 12
            active: Ui.monitorOpen
            tip: `CPU ${Usage.cpu}% · Memory ${Usage.memoryDetail}`
            onClicked: m => m.button === Qt.RightButton ? Ui.spawn(Ui.terminal(["btop"], ["--class", "penumbra-monitor"])) : Ui.toggle("monitor")
            readonly property color tint: Ui.monitorOpen ? Theme.accentInk : Theme.subtle
            Repeater {
                model: ["CPU", "RAM"]
                delegate: RowLayout {
                    required property string modelData
                    spacing: 5
                    Label {
                        text: modelData
                        font.pixelSize: Theme.textTiny
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        color: Ui.monitorOpen ? Theme.accentInk : Theme.dim
                    }
                    Label { text: (modelData === "CPU" ? Usage.cpu : Usage.memory) + "%"; color: monitor.tint }
                }
            }
        }

        Capsule {
            // nm-applet and blueman keep running for password and pairing prompts,
            // but the control center replaces their tray icons.
            readonly property var items: SystemTray.items.values.filter(i => !["nm-applet", "blueman"].includes(i.id))
            id: tray
            shown: items.length > 0
            interactive: false
            padding: 12
            spacing: 10
            Repeater {
                model: tray.items
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    implicitWidth: 18
                    implicitHeight: 18
                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        visible: false
                    }
                    // Tinted to match the bar; full color on hover.
                    MultiEffect {
                        anchors.fill: parent
                        source: trayIcon
                        saturation: trayMouse.containsMouse ? 0 : -1
                        colorization: trayMouse.containsMouse ? 0 : 0.35
                        colorizationColor: Theme.accent
                        brightness: trayMouse.containsMouse ? 0 : 0.1
                        Behavior on saturation { NumberAnimation { duration: Theme.fast } }
                        Behavior on colorization { NumberAnimation { duration: Theme.fast } }
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const item = trayItem.modelData;
                            if (m.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (m.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) {
                                    const p = trayItem.mapToItem(bar.contentItem, 0, trayItem.height + 14);
                                    item.display(bar, p.x, p.y);
                                }
                            } else
                                item.activate();
                        }
                        onWheel: w => trayItem.modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }

        // Network, Bluetooth, audio, battery and notifications open the control center.
        Capsule {
            id: controls
            padding: 14
            spacing: 13
            active: Ui.controlOpen
            tip: `${Devices.networkName} · Bluetooth ${Devices.bluetoothName}` + (Devices.hasBattery ? `\n${Devices.batteryDetail}` : "")
                + (Devices.peripheralBatteries.length ? "\n" + Devices.peripheralBatteries.join(" · ") : "")
            onClicked: m => m.button === Qt.RightButton ? Ui.run("pavucontrol") : Ui.toggle("control")
            onScrolled: step => Devices.adjust("volume", step > 0 ? "up" : "down")
            readonly property color tint: Ui.controlOpen ? Theme.accentInk : Theme.textSoft

            Glyph { text: Devices.networkGlyph; color: Devices.networkName === "Offline" && !Ui.controlOpen ? Theme.dim : controls.tint }
            Glyph { text: Devices.bluetoothGlyph; color: !Devices.bluetoothOn && !Ui.controlOpen ? Theme.dim : controls.tint }
            RowLayout {
                spacing: 5
                Glyph { text: Devices.volumeGlyph; color: Devices.muted && !Ui.controlOpen ? Theme.dim : controls.tint }
                Label {
                    visible: !Devices.muted
                    text: Devices.volume + "%"
                    color: controls.tint
                }
            }
            RowLayout {
                visible: Devices.hasBattery
                spacing: 5
                Glyph { text: Devices.batteryGlyph; color: Ui.controlOpen ? Theme.accentInk : Devices.batteryColor }
                Label { text: Devices.batteryPercent + "%"; color: Ui.controlOpen ? Theme.accentInk : Devices.batteryColor }
            }
            Item {
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight
                Glyph {
                    id: bell
                    text: Notifs.dnd ? "󰂛" : Notifs.count ? "󰂚" : "󰂜"
                    color: Ui.controlOpen ? Theme.accentInk : Notifs.dnd ? Theme.dim : Theme.textSoft
                }
                Rectangle {
                    visible: Notifs.count > 0 && !Notifs.dnd
                    width: 6; height: 6; radius: Theme.corner(3)
                    color: Ui.controlOpen ? Theme.accentInk : Theme.accentBright
                    anchors { right: bell.right; top: bell.top; rightMargin: -2; topMargin: 1 }
                }
            }
        }

        Capsule {
            padding: 14
            tip: "Session & power"
            onClicked: Ui.openSession()
            Glyph { text: "󰐥"; size: 16; color: Theme.accentBright }
        }
    }

    }

    // ── Tooltip ─────────────────────────────────────────────────────
    property Item tipTarget: null
    function updateTip(pos) {
        const target = pos && !Ui.openPanel ? capsuleAt(pos) : null;
        if (target !== tipTarget) {
            tipTarget = target;
            tipWindow.visible = false;
            tipDelay.restart();
        }
    }
    Connections {
        target: Ui
        function onOpenPanelChanged() {
            if (Ui.openPanel)
                bar.updateTip(null);
        }
    }
    // Innermost item under the pointer that declares a tooltip.
    function capsuleAt(pos) {
        let found = null, item = content, p = pos;
        for (let child = item.childAt(p.x, p.y); child; child = item.childAt(p.x, p.y)) {
            p = item.mapToItem(child, p.x, p.y);
            if (child.tip !== undefined)
                found = child;
            item = child;
        }
        return found;
    }
    Timer {
        id: tipDelay
        interval: 550
        onTriggered: tipWindow.visible = !!bar.tipTarget && bar.tipTarget.tip !== "" && !Ui.openPanel
    }
    PopupWindow {
        id: tipWindow
        anchor.item: bar.tipTarget ?? bar.contentItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        implicitWidth: tipText.implicitWidth + 24
        implicitHeight: tipText.implicitHeight + 16
        color: "transparent"
        mask: Region {}
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: Theme.glassStrong
            border.color: Theme.lineStrong
            Label {
                id: tipText
                anchors.centerIn: parent
                text: bar.tipTarget?.tip ?? ""
                color: Theme.text
                elide: Text.ElideNone
            }
        }
    }
}
