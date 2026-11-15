import QtQuick
import QtQuick.Effects

// Draw a soft shadow under each floating shell surface.
RectangularShadow {
    required property Item target

    anchors.fill: target
    radius: target.radius
    offset.y: 6
    blur: 26
    spread: -4
    color: Theme.shadow
    opacity: target.opacity
    scale: target.scale
}
