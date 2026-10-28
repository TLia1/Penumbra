import QtQuick
import QtQuick.Controls

// A slider on a track of colours: the hue's rainbow, the vividness's grey to vivid. colorAt(value)
// paints the track (sampled every twelfth of the way) and fills the handle.
Slider {
    id: root

    property var colorAt: value => Theme.accent
    // The colour a fraction of the way along the track.
    function at(fraction) { return colorAt(from + (to - from) * fraction); }

    // The custom background and handle give no implicit height, which would leave a 0 px hit area.
    implicitHeight: 32
    snapMode: Slider.SnapAlways

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 12
        radius: Theme.corner(6)
        border.color: Theme.line
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: root.at(0) }
            GradientStop { position: 1 / 12; color: root.at(1 / 12) }
            GradientStop { position: 2 / 12; color: root.at(2 / 12) }
            GradientStop { position: 3 / 12; color: root.at(3 / 12) }
            GradientStop { position: 4 / 12; color: root.at(4 / 12) }
            GradientStop { position: 5 / 12; color: root.at(5 / 12) }
            GradientStop { position: 6 / 12; color: root.at(6 / 12) }
            GradientStop { position: 7 / 12; color: root.at(7 / 12) }
            GradientStop { position: 8 / 12; color: root.at(8 / 12) }
            GradientStop { position: 9 / 12; color: root.at(9 / 12) }
            GradientStop { position: 10 / 12; color: root.at(10 / 12) }
            GradientStop { position: 11 / 12; color: root.at(11 / 12) }
            GradientStop { position: 1; color: root.at(1) }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.pressed ? 22 : 20
        height: width
        radius: Theme.corner(width / 2)
        color: Theme.white
        border.color: Theme.lineStrong
        Behavior on width { NumberAnimation { duration: Theme.fast } }
        Rectangle {
            anchors { fill: parent; margins: 4 }
            radius: Theme.corner(width / 2)
            color: root.colorAt(root.value)
        }
    }
}
