import QtQuick
import QtQuick.Effects

// The soft shadow under a floating surface. Hyprland only shadows windows, so shell surfaces
// draw their own. Declare it just before the surface it lies under.
RectangularShadow {
    required property Item target

    anchors.fill: target
    radius: target.radius
    offset.y: 6
    blur: 26
    spread: -4
    color: Qt.rgba(0, 0, 0, 0.55)
    opacity: target.opacity
    scale: target.scale
}
