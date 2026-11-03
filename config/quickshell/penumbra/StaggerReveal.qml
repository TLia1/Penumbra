import QtQuick

// Attach to a layout section or delegate. Transforming avoids moving the layout's geometry.
// Closing resets immediately; reopening during a reveal cancels its old delay and starts fresh.
Item {
    id: root
    property Item target: parent
    required property bool shown
    property int order: 0
    property real progress: 0
    visible: false

    function reset() {
        entrance.stop();
        if (!shown) {
            progress = 0;
        } else if (Theme.reducedMotion) {
            progress = 1;
        } else {
            progress = 0;
            entrance.start();
        }
    }
    onShownChanged: reset()
    Connections {
        target: Theme
        function onReducedMotionChanged() { root.reset(); }
    }
    Component.onCompleted: {
        target.transform = [...target.transform, offset];
        reset();
    }
    Binding { target: root.target; property: "opacity"; value: root.progress }
    Translate { id: offset; y: 10 * (1 - root.progress) }
    SequentialAnimation {
        id: entrance
        PauseAnimation { duration: Math.min(12, Math.max(0, root.order)) * 18 * Theme.motion }
        NumberAnimation {
            target: root
            property: "progress"
            to: 1
            duration: Theme.normal
            easing.type: Easing.OutQuint
        }
    }
}
