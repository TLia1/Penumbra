import QtQuick
import QtQuick.Layouts

// Look: dark or light, the accent colours and the corner style, for the shell and the apps at once.
// Look and penumbra-theme apply a change; the shell fades to it.
ColumnLayout {
    id: root

    spacing: 12

    component Section: Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
    }

    // A choice drawn as a card: its picture above, its name below, the current one outlined.
    component Choice: Rectangle {
        id: choice
        property bool current
        property string title
        default property alias picture: holder.data
        signal picked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal shares
        implicitHeight: 118
        radius: Theme.radius
        color: current ? Theme.alpha(Theme.accent, 0.12) : choiceArea.containsMouse ? Theme.hover : Theme.raised
        border.width: current ? 2 : 1
        border.color: current ? Theme.accent : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.fast } }

        Item {
            id: holder
            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
            width: 116
            height: 62
        }
        RowLayout {
            anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
            spacing: 6
            Rectangle {
                visible: choice.current
                implicitWidth: 6
                implicitHeight: 6
                radius: Theme.corner(3)
                color: Theme.accent
            }
            Label {
                text: choice.title
                font.weight: choice.current ? Font.DemiBold : Font.Normal
                color: choice.current ? Theme.text : Theme.textSoft
            }
        }
        MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!choice.current) choice.picked()
        }
    }

    // A line standing in for text in the previews.
    component Line: Rectangle {
        implicitHeight: 4
        radius: Theme.corner(height / 2)
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Look"
        status: Look.error || "Mode, colours and corners"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // A little desktop in the colours on screen: a bar, a window and a panel. They fade with the
    // shell, so it shows each change as it happens.
    Rectangle {
        id: desktop
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.line
        clip: true

        // A faint wash of the accent, where a wallpaper would be.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(Theme.accentDeep, Theme.light ? 0.16 : 0.32) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // The bar: workspaces, the clock, the status capsule.
        Rectangle {
            id: bar
            x: 10
            y: 10
            width: parent.width - 20
            height: 18
            radius: Theme.corner(9)
            color: Theme.glassStrong
            border.color: Theme.line
            Row {
                anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                spacing: 4
                Line { width: 14; height: 6; color: Theme.accent }
                Line { width: 6; height: 6; color: Theme.dim }
                Line { width: 6; height: 6; color: Theme.dim }
            }
            Line { anchors.centerIn: parent; width: 28; color: Theme.textSoft }
            Row {
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                spacing: 4
                Line { width: 6; height: 6; color: Theme.muted }
                Line { width: 6; height: 6; color: Theme.muted }
                Line { width: 18; height: 6; color: Theme.textSoft }
            }
        }

        // A window: a title, some text, a primary and a plain button.
        Rectangle {
            x: 10
            y: bar.y + bar.height + 8
            width: parent.width - panel.width - 28
            height: parent.height - y - 10
            radius: Theme.corner(10)
            color: Theme.surface
            border.color: Theme.lineStrong
            Column {
                anchors { left: parent.left; top: parent.top; margins: 11 }
                spacing: 6
                Line { width: 64; height: 6; color: Theme.text }
                Line { width: 120; color: Theme.textSoft }
                Line { width: 96; color: Theme.muted }
                Line { width: 108; color: Theme.dim }
            }
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 11 }
                spacing: 6
                Rectangle {
                    width: 46
                    height: 16
                    radius: Theme.corner(8)
                    color: Theme.accent
                    Line { anchors.centerIn: parent; width: 24; color: Theme.onAccent }
                }
                Rectangle {
                    width: 40
                    height: 16
                    radius: Theme.corner(8)
                    color: Theme.raised
                    border.color: Theme.line
                    Line { anchors.centerIn: parent; width: 20; color: Theme.textSoft }
                }
            }
        }

        // A panel: two tiles (one on), a slider.
        Rectangle {
            id: panel
            anchors { right: parent.right; rightMargin: 10 }
            y: bar.y + bar.height + 8
            width: 128
            height: parent.height - y - 10
            radius: Theme.corner(12)
            color: Theme.glassStrong
            border.color: Theme.line
            Row {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
                spacing: 6
                Repeater {
                    model: [true, false]
                    delegate: Rectangle {
                        required property bool modelData
                        width: (parent.width - 6) / 2
                        height: 34
                        radius: Theme.corner(8)
                        color: modelData ? Theme.alpha(Theme.accent, 0.22) : Theme.raised
                        border.color: modelData ? Theme.alpha(Theme.accentBright, 0.55) : Theme.line
                        Line { x: 7; y: 8; width: 8; height: 8; color: modelData ? Theme.accentBright : Theme.muted }
                        Line { x: 7; y: 22; width: 30; color: modelData ? Theme.text : Theme.textSoft }
                    }
                }
            }
            Line {
                id: track
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 16 }
                color: Theme.overlayStrong
                Line { width: parent.width * 0.6; color: Theme.accent }
                Rectangle {
                    x: parent.width * 0.6 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: Theme.corner(5)
                    color: Theme.white
                    border.color: Theme.accent
                }
            }
        }
    }

    Section { text: "Mode" }
    Segmented {
        Layout.fillWidth: true
        current: Look.choice.mode
        options: [
            { value: "dark", title: "Dark", glyph: "󰖔" },
            { value: "light", title: "Light", glyph: "󰖙" }
        ]
        onChosen: value => Look.set({ mode: value })
    }

    Section { text: "Colours" }
    // Each card shows its accent family in the current mode.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { name: "default", title: "Default" },
                { name: "custom", title: "Custom" }
            ]
            delegate: Choice {
                id: colours
                required property var modelData
                readonly property var swatches: Look.swatches(Look.choice.mode, modelData.name, Look.choice.hue, Look.choice.vividness)
                current: Look.choice.colors === modelData.name
                title: modelData.title
                onPicked: Look.set({ colors: modelData.name })
                Row {
                    anchors.centerIn: parent
                    spacing: -10
                    Repeater {
                        model: colours.swatches
                        delegate: Rectangle {
                            required property color modelData
                            width: 34
                            height: 34
                            radius: Theme.corner(17)
                            color: modelData
                            border.width: 2
                            border.color: Theme.surface
                            Behavior on color { ColorAnimation { duration: Theme.slow } }
                        }
                    }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        visible: Look.choice.colors === "custom"
        text: `Hue ${Math.round(Look.choice.hue)}° · vividness ${Math.round(Look.choice.vividness * 100)} %`
        font.pixelSize: Theme.textSmall
        color: Theme.muted
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
            delegate: Choice {
                id: corners
                required property var modelData
                readonly property color ink: current ? Theme.accent : Theme.lineStrong
                function r(px) { return modelData.round ? px : 0; }
                current: Theme.corners === modelData.name
                title: modelData.title
                onPicked: Ui.run(Ui.bin + "penumbra-corners " + modelData.name)
                Rectangle {
                    width: parent.width
                    height: 10
                    radius: corners.r(5)
                    color: Theme.glass
                    border.color: corners.ink
                    Rectangle { x: 4; y: 3; width: 14; height: 4; radius: corners.r(2); color: corners.ink }
                }
                Rectangle {
                    y: 16
                    width: parent.width
                    height: parent.height - y
                    radius: corners.r(9)
                    color: Theme.surface
                    border.color: corners.ink
                    Rectangle { x: 9; y: 10; width: 44; height: 5; radius: corners.r(2.5); color: corners.ink }
                    Rectangle { x: 9; y: 21; width: 70; height: 4; radius: corners.r(2); color: Theme.line }
                    Rectangle { x: 9; y: 30; width: 56; height: 4; radius: corners.r(2); color: Theme.line }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        text: "The shell, windows, launcher and lock screen follow at once; open apps pick up some changes when they restart"
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
