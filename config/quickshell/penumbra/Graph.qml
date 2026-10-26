import QtQuick
import QtQuick.Shapes

// A history graph, newest sample at the right edge: a line over a fill that fades downwards.
// While live, each new sample glides in over one sampling interval instead of jumping.
Item {
    id: root

    property var values: []
    // The value at the top edge; 0 scales to the largest value shown, but never below floor.
    property real maximum: 100
    property real floor: 1
    property color color: Theme.violet
    property real fillOpacity: 0.3
    property bool live: true

    readonly property real ceiling: maximum > 0 ? maximum : Math.max(floor, 1.15 * Math.max(0, ...values))
    // One point more than fits: the oldest sits just off the left edge, so the glide never
    // shows a gap there.
    readonly property real step: width / (Usage.historyLength - 2)
    // Inset by half the line, so a line along the top or bottom is drawn whole.
    readonly property var points: values.map((v, i) => Qt.point(width - (values.length - 1 - i) * step, 1 + (height - 2) * (1 - Math.max(0, Math.min(v, ceiling)) / ceiling)))

    clip: true
    onValuesChanged: if (live) glide.restart()

    Shape {
        id: shape
        width: root.width
        height: root.height
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer

        NumberAnimation on x {
            id: glide
            running: false
            from: root.step
            to: 0
            duration: Usage.interval
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                y1: 0
                y2: root.height
                GradientStop { position: 0; color: Theme.alpha(root.color, root.fillOpacity) }
                GradientStop { position: 1; color: Theme.alpha(root.color, 0) }
            }
            PathPolyline {
                path: root.points.length ? [Qt.point(root.points[0].x, root.height)].concat(root.points, [Qt.point(root.width, root.height)]) : []
            }
        }
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathPolyline { path: root.points }
        }
    }
}
