import QtQuick
import QtQuick.Shapes

// A top-docked island with concave shoulders and rounded lower corners.
Shape {
    id: root
    property real radius: Theme.corner(16)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        fillColor: Theme.glassStrong
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathQuad { x: root.width - root.radius; y: root.radius; controlX: root.width - root.radius; controlY: 0 }
        PathLine { x: root.width - root.radius; y: root.height - root.radius }
        PathQuad { x: root.width - 2 * root.radius; y: root.height; controlX: root.width - root.radius; controlY: root.height }
        PathLine { x: 2 * root.radius; y: root.height }
        PathQuad { x: root.radius; y: root.height - root.radius; controlX: root.radius; controlY: root.height }
        PathLine { x: root.radius; y: root.radius }
        PathQuad { x: 0; y: 0; controlX: root.radius; controlY: 0 }
    }
}
