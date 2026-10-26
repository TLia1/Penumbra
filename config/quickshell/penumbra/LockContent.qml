import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

// One monitor of the lock screen: the wordmark-free wallpaper (dawn and eclipse keep moving),
// the time, and the password field. Every monitor shows the same password dots.
Rectangle {
    id: surface
    required property var lock
    property real pixelRatio: 1
    color: Theme.base

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? null

    // ── Wallpaper ───────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: Ui.fileUrl(Ui.wallpaperStill)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    // Cover the screen like `awww img --resize crop`.
    Loader {
        id: scene
        anchors.centerIn: parent
        // Not before the surface has a size: the scene decodes its layers for it.
        active: surface.width > 0 && ["wallpaper-dawn", "wallpaper-eclipse"].includes(Ui.wallpaper)
        scale: item ? Math.max(surface.width / item.width, surface.height / item.height) : 1
        sourceComponent: Ui.wallpaper === "wallpaper-eclipse" ? eclipse : dawn
        Component {
            id: dawn
            DawnScene {
                clean: true
                pixelScale: width > 0 && height > 0 ? Math.max(surface.width / width, surface.height / height) * surface.pixelRatio : 1
            }
        }
        Component {
            id: eclipse
            EclipseScene {
                clean: true
                pixelScale: width > 0 && height > 0 ? Math.max(surface.width / width, surface.height / height) * surface.pixelRatio : 1
            }
        }
    }
    // Darker toward the bottom, where the password field sits.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.alpha(Theme.base, 0.25) }
            GradientStop { position: 0.55; color: Theme.alpha(Theme.base, 0.35) }
            GradientStop { position: 1; color: Theme.alpha(Theme.base, 0.78) }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    // ── Content ─────────────────────────────────────────────────────
    Item {
        id: content
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: { opacity = 1; input.forceActiveFocus(); }
        Behavior on opacity { NumberAnimation { duration: Theme.slow * 2; easing.type: Easing.OutCubic } }

        // Battery and network, top right.
        RowLayout {
            anchors { top: parent.top; right: parent.right; margins: 28 }
            spacing: 16
            Glyph { text: Devices.networkGlyph; size: 16; color: Theme.textSoft }
            RowLayout {
                visible: Devices.hasBattery
                spacing: 6
                Glyph { text: Devices.batteryGlyph; size: 16; color: Devices.batteryColor }
                Label { text: Devices.batteryPercent + "%"; color: Devices.batteryColor }
            }
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.2)
            spacing: 0
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(Clock.date, "HH:mm")
                font.family: Theme.display
                font.pixelSize: Theme.textDisplay
                font.weight: Font.Light
                font.letterSpacing: -1
                color: Theme.text
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(Clock.date, "dddd d MMMM")
                font.pixelSize: Theme.textLarge
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
                color: Theme.violet
            }
        }

        ColumnLayout {
            id: login
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.58)
            spacing: 14

            Avatar {
                Layout.alignment: Qt.AlignHCenter
                size: 76
                ring: true
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER")
                font.pixelSize: Theme.textLarge
                font.weight: Font.DemiBold
            }

            // The typed password shows as dots; the real field is invisible behind them.
            Rectangle {
                id: field
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                implicitWidth: 320
                implicitHeight: 52
                radius: Theme.corner(26)
                color: Theme.glassStrong
                border.width: input.activeFocus ? 2 : 1
                border.color: surface.lock.message && !surface.lock.busy ? Theme.rose : input.activeFocus ? Theme.violet : Theme.lineStrong
                Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                TextInput {
                    id: input
                    anchors.fill: parent
                    opacity: 0
                    echoMode: TextInput.Password
                    enabled: !surface.lock.busy
                    onTextChanged: if (surface.lock.password !== text) surface.lock.password = text
                    Keys.onReturnPressed: surface.lock.submit()
                    Keys.onEnterPressed: surface.lock.submit()
                    Keys.onEscapePressed: text = ""
                    Keys.onPressed: event => {
                        surface.lock.checkCaps();
                        event.accepted = false;
                    }
                }
                Connections {
                    target: surface.lock
                    function onPasswordChanged() {
                        if (input.text !== surface.lock.password)
                            input.text = surface.lock.password;
                    }
                    function onRejected() { shake.restart(); }
                }

                Label {
                    anchors.centerIn: parent
                    visible: surface.lock.password === "" && !surface.lock.busy
                    text: "Enter password"
                    color: Theme.dim
                    font.pixelSize: Theme.textMedium
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Repeater {
                        model: Math.min(surface.lock.password.length, 22)
                        delegate: Rectangle {
                            width: 9
                            height: 9
                            radius: Theme.corner(4.5)
                            color: Theme.violetBright
                            scale: 0
                            Component.onCompleted: scale = 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }
                        }
                    }
                }
                Glyph {
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    text: surface.lock.busy ? "󰔟" : "󰌆"
                    size: 15
                    color: surface.lock.busy ? Theme.violet : Theme.dim
                    RotationAnimation on rotation { running: surface.lock.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
                }

                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: field; property: "Layout.leftMargin"; to: 18; duration: 50 }
                    NumberAnimation { target: field; property: "Layout.leftMargin"; to: -14; duration: 70 }
                    NumberAnimation { target: field; property: "Layout.leftMargin"; to: 10; duration: 60 }
                    NumberAnimation { target: field; property: "Layout.leftMargin"; to: 0; duration: 60 }
                }
            }

            // With several keyboard layouts, the one the password is typed in; click to switch.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: Devices.layouts.length > 1
                implicitWidth: layoutRow.implicitWidth + 24
                implicitHeight: 28
                radius: Theme.corner(14)
                color: layoutArea.containsMouse ? Theme.hover : Theme.glass
                border.color: Theme.line
                RowLayout {
                    id: layoutRow
                    anchors.centerIn: parent
                    spacing: 6
                    Glyph { text: "󰌌"; size: 13; color: Theme.textSoft }
                    Label { text: Devices.layoutCode; font.weight: Font.Bold; color: Theme.textSoft }
                }
                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Devices.nextLayout(); input.forceActiveFocus(); }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 16
                text: surface.lock.message || (surface.lock.capsLock ? "Caps Lock is on" : "")
                font.pixelSize: Theme.textBody
                color: surface.lock.message ? Theme.rose : Theme.amber
            }
        }

        // What's playing, with its controls.
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
            visible: !!surface.player
            implicitWidth: 360
            implicitHeight: 64
            radius: Theme.corner(32)
            color: Theme.glassStrong
            border.color: Theme.line
            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 12 }
                spacing: 12
                ClippingRectangle {
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: Theme.corner(24)
                    color: Theme.raised
                    Image {
                        anchors.fill: parent
                        source: surface.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Glyph {
                        anchors.centerIn: parent
                        visible: !surface.player?.trackArtUrl
                        text: "󰎆"
                        size: 19
                        color: Theme.violetBright
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { Layout.fillWidth: true; text: surface.player?.trackTitle || Media.appName(surface.player); font.weight: Font.DemiBold }
                    Label { Layout.fillWidth: true; text: surface.player?.trackArtist || Media.appName(surface.player); font.pixelSize: Theme.textSmall; color: Theme.muted }
                }
                Repeater {
                    model: [
                        { glyph: "󰒮", run: () => surface.player.previous() },
                        { glyph: surface.player?.isPlaying ? "󰏤" : "󰐊", run: () => surface.player.togglePlaying(), main: true },
                        { glyph: "󰒭", run: () => surface.player.next() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: modelData.main ? 36 : 28
                        implicitHeight: implicitWidth
                        radius: Theme.corner(implicitWidth / 2)
                        color: modelData.main ? Theme.violet : lockMedia.containsMouse ? Theme.hover : "transparent"
                        Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 15; color: modelData.main ? Theme.violetInk : Theme.text }
                        MouseArea {
                            id: lockMedia
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { modelData.run(); input.forceActiveFocus(); }
                        }
                    }
                }
            }
        }
    }
}
