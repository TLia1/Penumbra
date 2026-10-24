import QtQuick

// Now and then a shooting star starts somewhere in `area` (scene coordinates) and falls along `heading`.
Item {
    id: root
    property bool running: true
    property rect area
    property real heading: 155
    property real distance: 560

    Rectangle {
        id: streak
        property real startX: 0
        property real startY: 0
        property real progress: 0
        width: 260
        height: 2
        radius: 1
        visible: falling.running
        transformOrigin: Item.Right
        rotation: root.heading
        x: startX + root.distance * progress * Math.cos(root.heading * Math.PI / 180) - width
        y: startY + root.distance * progress * Math.sin(root.heading * Math.PI / 180) - height / 2
        opacity: Math.sin(Math.PI * progress)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#f7e6ff" }
        }
        NumberAnimation on progress {
            id: falling
            running: false
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.InQuad
        }
    }

    Timer {
        interval: 20000 + Math.random() * 30000
        repeat: true
        running: root.running
        onTriggered: {
            interval = 20000 + Math.random() * 30000;
            streak.startX = root.area.x + Math.random() * root.area.width;
            streak.startY = root.area.y + Math.random() * root.area.height;
            falling.restart();
        }
    }
}
