import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets

// Glyph (or app icon) button for mute, plus a soft violet slider, 0–100.
RowLayout {
    id: root

    property string glyph
    property string icon: ""
    property real value: 0
    property bool muted: false
    signal moved(real value)
    signal glyphClicked()

    spacing: 10

    Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: Theme.corner(18)
        color: button.containsMouse ? Theme.hover : Theme.raised
        Glyph {
            anchors.centerIn: parent
            visible: root.icon === ""
            text: root.glyph
            size: 16
            color: root.muted ? Theme.dim : Theme.violetBright
        }
        IconImage {
            anchors.centerIn: parent
            visible: root.icon !== ""
            implicitSize: 20
            source: root.icon
            opacity: root.muted ? 0.4 : 1
        }
        MouseArea {
            id: button
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.glyphClicked()
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        // The custom background and handle give no implicit height, which would leave a 0 px hit area.
        implicitHeight: 36
        from: 0
        to: 100
        value: root.value
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 8
            radius: Theme.corner(4)
            color: Theme.raised
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: Theme.corner(4)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.violetDeep }
                    GradientStop { position: 1; color: root.muted ? Theme.dim : Theme.violet }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 18 : 16
            height: width
            radius: Theme.corner(width / 2)
            color: Theme.white
            border.color: Theme.violet
            border.width: 2
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    Label {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value) + "%"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.muted
    }
}
