import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
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
    MouseArea {
        anchors.fill: parent
        enabled: Ui.openPanel !== "" && Ui.panelGrabFocus
        acceptedButtons: Qt.AllButtons
        onPressed: Ui.dismiss()
    }

    // ── Left ────────────────────────────────────────────────────────
    RowLayout {
        id: leftSide
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            id: launcherCapsule
            padding: 14
            active: Ui.launcherOpen
            onClicked: m => Ui.toggleLauncher(m.button === Qt.RightButton ? "clipboard" : "apps")
            Glyph { text: Theme.distroGlyph; size: 20; color: Ui.launcherOpen ? Theme.accentInk : Theme.accentBright }
        }

        Capsule {
            id: clockCapsule
            padding: 18
            active: Ui.calendarOpen
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
            onClicked: Ui.toggle("calendar")
            Glyph { text: Weather.current?.weather_code === 0 ? "󰖙" : "󰖐"; color: Theme.accentBright }
            Label { text: Math.round(Weather.current?.temperature_2m ?? 0) + "°" }
        }

        WorkspaceStrip {
            id: workspaceStrip
            workspaces: Wm.workspacesFor(bar.screen.name)
            showIcons: Settings.workspaceStyle === "icons" && bar.width - rightSide.width > 850
        }

        // MangoWM active tiling layout capsule: click to cycle layouts, right-click for MangoWM settings.
        Capsule {
            id: layoutCapsule
            readonly property var monitor: Wm.monitorFor(bar.screen)
            readonly property var layoutInfo: monitor?.layoutInfo ?? Wm.activeLayout
            readonly property bool isScroller: layoutInfo?.id === "scroller" || layoutInfo?.id === "vertical_scroller"
            readonly property int scrollerPct: Math.round((Wm.focusedClient?.scrollerProportion ?? Settings.scrollerProportion ?? 0.8) * 100)
            shown: Wm.isMango && !!layoutInfo
            padding: 12
            spacing: 6
            active: Ui.controlOpen && Ui.controlPage === "wm"
            onClicked: m => m.button === Qt.RightButton ? Ui.openControl("wm") : (m.button === Qt.MiddleButton && isScroller ? Wm.switchProportionPreset() : Wm.nextLayout())
            onScrolled: step => isScroller && (Wm.focusedClient != null) ? Wm.switchProportionPreset() : Wm.nextLayout()
            Glyph {
                text: layoutCapsule.layoutInfo?.glyph ?? "󰕰"
                size: 14
                color: layoutCapsule.active ? Theme.accentInk : Theme.accentBright
            }
            Label {
                text: (layoutCapsule.layoutInfo?.symbol ?? "DW") + (layoutCapsule.isScroller && Wm.focusedClient ? ` · ${layoutCapsule.scrollerPct}%` : "")
                font.pixelSize: Theme.textSmall
                font.weight: Font.Bold
                color: layoutCapsule.active ? Theme.accentInk : Theme.textSoft
            }
        }

        // MangoWM active keymode submap indicator (e.g. resize mode). Click to return to default.
        Capsule {
            id: keymodeCapsule
            shown: Wm.isMango && Wm.keymode !== "" && Wm.keymode !== "default"
            padding: 12
            spacing: 6
            color: hovered ? Theme.alpha(Theme.amber, 0.32) : Theme.alpha(Theme.amber, 0.2)
            border.color: Theme.alpha(Theme.amber, 0.55)
            onClicked: Wm.setKeymode("default")
            Glyph { text: "󰌌"; size: 14; color: Theme.amber }
            Label {
                text: Wm.keymode.toUpperCase()
                font.pixelSize: Theme.textSmall
                font.weight: Font.Bold
                color: Theme.amber
            }
        }

        // MangoWM scratchpad / minimized stash indicator: click to toggle scratchpad, right-click to restore.
        Capsule {
            id: scratchpadCapsule
            shown: Wm.isMango && Wm.scratchpadCount > 0
            padding: 11
            spacing: 5
            onClicked: m => m.button === Qt.RightButton ? Wm.restoreMinimized() : Wm.toggleScratchpad()
            Glyph { text: "󰀿"; size: 14; color: Theme.accentBright }
            Label {
                text: String(Wm.scratchpadCount)
                font.pixelSize: Theme.textSmall
                font.weight: Font.Bold
                color: Theme.textSoft
            }
        }

        MediaCapsule {}
    }

    // ── Center ──────────────────────────────────────────────────────
    // The focused window holds the exact center, along with its MangoWM window state badges.
    RowLayout {
        anchors.centerIn: parent
        Capsule {
            id: title
            // The Wayland toplevel protocol knows the focused window from startup; nothing is
            // activated on an empty workspace. Show it on the bar of the screen it is on.
            readonly property var client: ToplevelManager.activeToplevel
            readonly property var mangoClient: Wm.focusedClient
            readonly property var entry: client ? DesktopEntries.heuristicLookup(client.appId) : null
            // Most windows end their title with the app's name ("… — Mozilla Firefox"); the icon says that.
            readonly property string text: {
                const t = client?.title ?? "";
                const m = t.match(/^(.+)\s[—–-]\s(.+)$/);
                const names = [entry?.name, client?.appId].filter(n => n).map(n => n.toLowerCase());
                return m && names.some(n => m[2].toLowerCase().includes(n)) ? m[1] : t;
            }
            readonly property var badges: {
                const c = mangoClient;
                if (!c)
                    return [];
                const list = [];
                if (c.tags && c.tags.length > 1)
                    list.push({ label: "TAGS " + c.tags.join("+"), color: Theme.accentBright });
                if (c.isGlobal)
                    list.push({ label: "PIN", color: Theme.accentBright });
                if (c.isOverlay)
                    list.push({ label: "TOP", color: Theme.cyan });
                if (c.isGroup)
                    list.push({ label: "GROUP", color: Theme.accent });
                if (c.isMaximized)
                    list.push({ label: "MAX", color: Theme.amber });
                if (c.isFloating)
                    list.push({ label: "FLOAT", color: Theme.textSoft });
                if (c.isSwallowing)
                    list.push({ label: "SWALLOW", color: Theme.green });
                return list;
            }
            readonly property real availableWidth: 2 * Math.min(content.width / 2 - leftSide.x - leftSide.width,
                rightSide.x - content.width / 2) - 2 * Theme.gap
            shown: !bar.island && availableWidth >= 80 && !!client && client.activated && text !== "" && client.screens.some(s => s.name === bar.screen.name)
            padding: 15
            spacing: 8
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    Ui.toggleLauncher("windows");
                else if (m.button === Qt.MiddleButton)
                    Wm.toggleMaximizeScreen(title.mangoClient);
                else
                    Ui.toggleOverview();
            }
            IconImage {
                visible: source !== ""
                implicitSize: 15
                source: title.entry?.icon ? Quickshell.iconPath(title.entry.icon, true) : ""
                asynchronous: true
            }
            Label {
                text: title.text
                // As wide as the room between the side capsules allows, up to a point.
                readonly property real maxTextWidth: Math.max(40, Math.min(280, title.availableWidth - 60 - (title.badges.length * 48)))
                Layout.preferredWidth: Math.min(implicitWidth, maxTextWidth)
                Layout.maximumWidth: maxTextWidth
                elide: Text.ElideRight
                color: Theme.textSoft
            }
            Repeater {
                model: title.badges
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: badgeText.implicitWidth + 10
                    implicitHeight: 18
                    radius: Theme.corner(9)
                    color: Theme.alpha(modelData.color, 0.18)
                    border.color: Theme.alpha(modelData.color, 0.45)
                    Label {
                        id: badgeText
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Theme.textTiny
                        font.weight: Font.Bold
                        color: modelData.color
                    }
                }
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
            onClicked: Recorder.cancel()
            Glyph { text: "󰔛"; color: Theme.amber }
            Label { text: Recorder.countdown; font.weight: Font.Bold; color: Theme.amber }
        }

        // A screen recording and how long it has run; click to stop, right-click to pause.
        Capsule {
            shown: Recorder.recording
            padding: 14
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
            onClicked: Ui.openControl("cast")
            Glyph { text: "󰄙"; color: castCapsule.active ? Theme.accentInk : Theme.accentBright }
            Label { text: Cast.tvName; font.weight: Font.Bold; color: castCapsule.active ? Theme.accentInk : Theme.accentBright }
        }

        Capsule {
            shown: Devices.layouts.length > 1
            padding: 14
            onClicked: Devices.nextLayout()
            Glyph { text: "󰌌"; color: Theme.textSoft }
            Label { text: Devices.layoutCode; font.weight: Font.Bold; color: Theme.textSoft }
        }

        // Pending updates; also there when a restart is due, with its own glyph.
        Capsule {
            shown: Sys.updates > 0 || Sys.restartReasons.length > 0
            padding: 12
            active: Ui.updatesOpen
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
            onClicked: Ui.openSession()
            Glyph { text: "󰐥"; size: 16; color: Theme.accentBright }
        }
    }

    }
}
