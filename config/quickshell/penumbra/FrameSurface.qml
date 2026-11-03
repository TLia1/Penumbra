import QtQuick
import QtQuick.Shapes

// A bezel with a clear capsule row and concave inner corners below it.
Shape {
    id: root
    readonly property real edge: 3
    readonly property real topEdge: 10 + Theme.barHeight + 4
    readonly property real radius: Theme.corner(22)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: "transparent"
        fillColor: Theme.surface
        fillRule: ShapePath.OddEvenFill
        startX: 0; startY: 0
        PathLine { x: root.width; y: 0 }
        PathLine { x: root.width; y: root.height }
        PathLine { x: 0; y: root.height }
        PathLine { x: 0; y: 0 }
        // Leave the capsule row clear even when this surface maps above the bar.
        PathMove { x: root.edge; y: root.edge }
        PathLine { x: root.width - root.edge; y: root.edge }
        PathLine { x: root.width - root.edge; y: root.topEdge - 4 }
        PathLine { x: root.edge; y: root.topEdge - 4 }
        PathLine { x: root.edge; y: root.edge }
        PathMove { x: root.edge + root.radius; y: root.topEdge }
        PathLine { x: root.width - root.edge - root.radius; y: root.topEdge }
        PathArc { x: root.width - root.edge; y: root.topEdge + root.radius; radiusX: root.radius; radiusY: root.radius }
        PathLine { x: root.width - root.edge; y: root.height - root.edge - root.radius }
        PathArc { x: root.width - root.edge - root.radius; y: root.height - root.edge; radiusX: root.radius; radiusY: root.radius }
        PathLine { x: root.edge + root.radius; y: root.height - root.edge }
        PathArc { x: root.edge; y: root.height - root.edge - root.radius; radiusX: root.radius; radiusY: root.radius }
        PathLine { x: root.edge; y: root.topEdge + root.radius }
        PathArc { x: root.edge + root.radius; y: root.topEdge; radiusX: root.radius; radiusY: root.radius }
    }
}
