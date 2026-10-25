import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Floating capsules: launcher and clock left; workspaces and title centered; status right.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: 10; left: Theme.edge; right: Theme.edge }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "penumbra-bar"

    IdleInhibitor {
        window: bar
        enabled: Ui.caffeine
    }

    Item {
    id: content
    anchors.fill: parent
    HoverHandler {
        onPointChanged: bar.updateTip(point.position)
        onHoveredChanged: if (!hovered) bar.updateTip(null)
    }

    // ── Left ────────────────────────────────────────────────────────
    RowLayout {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            padding: 14
            tip: "Applications · right-click for the clipboard"
            active: Ui.launcherOpen
            onClicked: m => Ui.toggleLauncher(m.button === Qt.RightButton ? "clipboard" : "apps")
            Glyph { text: "󰣇"; size: 20; color: Ui.launcherOpen ? Theme.violetInk : Theme.violetBright }
        }

        Capsule {
            id: clockCapsule
            padding: 18
            active: Ui.calendarOpen
            tip: Qt.formatDateTime(Clock.date, "dddd d MMMM yyyy")
            onClicked: Ui.toggleCalendar()
            Label {
                text: Qt.formatDateTime(Clock.date, "HH:mm")
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Ui.calendarOpen ? Theme.violetInk : "#eee8ff"
            }
        }

        // What's playing, with cava's spectrum when it is installed; hidden while paused.
        Capsule {
            visible: !!Media.playing
            padding: 14
            spacing: 10
            tip: Media.player ? [Media.player.trackTitle, Media.player.trackArtist].filter(t => t).join(" · ") + "\nMiddle-click to pause · scroll to skip" : ""
            onClicked: m => m.button === Qt.MiddleButton ? Media.player.togglePlaying() : Ui.toggleControl()
            onScrolled: delta => delta > 0 ? Media.player.previous() : Media.player.next()
            Row {
                visible: Ui.hasVisualizer
                spacing: 2
                Layout.preferredHeight: 18
                Repeater {
                    model: Media.bars
                    delegate: Rectangle {
                        required property real modelData
                        anchors.bottom: parent?.bottom
                        width: 3
                        height: 3 + modelData * 15
                        radius: Theme.corner(1.5)
                        color: Theme.violetBright
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
            Glyph { visible: !Ui.hasVisualizer; text: "󰎆"; color: Theme.violetBright }
            Label {
                text: Media.player?.trackTitle || Media.player?.identity || ""
                Layout.maximumWidth: 170
                color: "#c8b8dc"
            }
        }
    }

    // ── Center ──────────────────────────────────────────────────────
    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.gap

        Repeater {
            model: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor?.name === bar.screen.name && (w.toplevels.values.length > 0 || w.focused || w.active))
                .sort((a, b) => a.id - b.id)
            delegate: Capsule {
                required property var modelData
                readonly property bool current: modelData.active && modelData.monitor?.name === bar.screen.name
                implicitWidth: current ? 52 : Theme.barHeight
                padding: 0
                active: current
                color: current ? Theme.violet : modelData.urgent ? Theme.rose : (hovered ? Theme.hover : Theme.glass)
                onClicked: modelData.activate()
                Label {
                    text: modelData.name
                    color: current || modelData.urgent ? Theme.violetInk : hovered ? "#eee8ff" : "#aa97bf"
                    font.family: Theme.mono
                    font.weight: current ? Font.Bold : Font.Normal
                }
            }
        }

        Capsule {
            id: title
            // The Wayland toplevel protocol knows the focused window from startup; nothing is
            // activated on an empty workspace. Show it on the bar of the screen it is on.
            readonly property var client: ToplevelManager.activeToplevel
            readonly property bool shown: !!client && client.activated && client.title !== "" && client.screens.some(s => s.name === bar.screen.name)
            visible: shown
            interactive: false
            padding: 16
            tip: shown ? client.title : ""
            Label {
                text: title.shown ? title.client.title : ""
                Layout.maximumWidth: 260
                font.family: Theme.mono
                color: "#c8b8dc"
            }
        }
    }

    // ── Right ───────────────────────────────────────────────────────
    RowLayout {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            visible: Devices.layouts.length > 1
            padding: 14
            tip: `${Devices.layoutName} · click to switch`
            onClicked: Devices.nextLayout()
            Glyph { text: "󰌌"; color: Theme.textSoft }
            Label { text: Devices.layoutCode; font.family: Theme.mono; font.weight: Font.Bold; color: Theme.textSoft }
        }

        Capsule {
            visible: Sys.updates > 0
            padding: 12
            active: Ui.updatesOpen
            tip: Sys.updatesDetail
            onClicked: Ui.toggleUpdates()
            Glyph { text: "󰚰"; color: Ui.updatesOpen ? Theme.violetInk : Theme.violetBright }
            Label { text: Sys.updates; color: Ui.updatesOpen ? Theme.violetInk : Theme.violetBright }
        }

        Capsule {
            id: monitor
            padding: 12
            spacing: 12
            active: Ui.monitorOpen
            tip: `CPU ${Sys.cpu}% · Memory ${Sys.memoryDetail}`
            onClicked: m => m.button === Qt.RightButton ? Ui.run("kitty --class penumbra-monitor htop") : Ui.toggleMonitor()
            readonly property color tint: Ui.monitorOpen ? Theme.violetInk : "#aaa0bb"
            RowLayout {
                spacing: 5
                Glyph { text: "󰻠"; size: 12; color: monitor.tint }
                Label { text: Sys.cpu + "%"; font.pixelSize: 11; color: monitor.tint; font.family: Theme.mono }
            }
            RowLayout {
                spacing: 5
                Glyph { text: "󰍛"; size: 12; color: monitor.tint }
                Label { text: Sys.memory + "%"; font.pixelSize: 11; color: monitor.tint; font.family: Theme.mono }
            }
        }

        Capsule {
            // nm-applet and blueman keep running for password and pairing prompts,
            // but the control center replaces their tray icons.
            readonly property var items: SystemTray.items.values.filter(i => !["nm-applet", "blueman"].includes(i.id))
            id: tray
            visible: items.length > 0
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
                        colorizationColor: Theme.violet
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
            onClicked: m => m.button === Qt.RightButton ? Ui.run("pavucontrol") : Ui.toggleControl()
            onScrolled: delta => Ui.run(Ui.bin + "penumbra-osd volume " + (delta > 0 ? "up" : "down"))
            readonly property color tint: Ui.controlOpen ? Theme.violetInk : Theme.textSoft

            Glyph { text: Devices.networkGlyph; color: Devices.networkName === "Offline" && !Ui.controlOpen ? Theme.dim : controls.tint }
            Glyph { text: Devices.bluetoothGlyph; color: !Devices.bluetoothOn && !Ui.controlOpen ? Theme.dim : controls.tint }
            RowLayout {
                spacing: 5
                Glyph { text: Devices.volumeGlyph; color: Devices.muted && !Ui.controlOpen ? Theme.dim : controls.tint }
                Label {
                    visible: !Devices.muted
                    text: Devices.volume + "%"
                    font.family: Theme.mono
                    color: controls.tint
                }
            }
            RowLayout {
                visible: Devices.hasBattery
                spacing: 5
                Glyph { text: Devices.batteryGlyph; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
                Label { text: Devices.batteryPercent + "%"; font.family: Theme.mono; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
            }
            Item {
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight
                Glyph {
                    id: bell
                    text: Notifs.dnd ? "󰂛" : Notifs.count ? "󰂚" : "󰂜"
                    color: Ui.controlOpen ? Theme.violetInk : Notifs.dnd ? Theme.dim : Theme.textSoft
                }
                Rectangle {
                    visible: Notifs.count > 0 && !Notifs.dnd
                    width: 6; height: 6; radius: Theme.corner(3)
                    color: Ui.controlOpen ? Theme.violetInk : Theme.violetBright
                    anchors { right: bell.right; top: bell.top; rightMargin: -2; topMargin: 1 }
                }
            }
        }

        Capsule {
            padding: 14
            tip: "Session & power"
            onClicked: Ui.openSession()
            Glyph { text: "󰐥"; size: 16; color: Theme.violetBright }
        }
    }

    }

    // ── Tooltip ─────────────────────────────────────────────────────
    property Item tipTarget: null
    function updateTip(pos) {
        const target = pos ? capsuleAt(pos) : null;
        if (target !== tipTarget) {
            tipTarget = target;
            tipWindow.visible = false;
            tipDelay.restart();
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
        onTriggered: tipWindow.visible = !!bar.tipTarget && bar.tipTarget.tip !== ""
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
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: Theme.glassStrong
            border.color: Theme.lineStrong
            Label {
                id: tipText
                anchors.centerIn: parent
                text: bar.tipTarget?.tip ?? ""
                color: "#e8e1f3"
                elide: Text.ElideNone
            }
        }
    }
}
