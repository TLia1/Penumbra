import QtQuick

Item {
    id: clearing
    required property real time
    required property var samples

    // Perches follow the treeline on either side of the open saddle, in scene coordinates.
    Repeater {
        model: [
            { x: 190, y: 768, band: 5 }, { x: 249, y: 868, band: 1 },
            { x: 321, y: 851, band: 3 }, { x: 356, y: 906, band: 0 },
            { x: 392, y: 802, band: 7 }, { x: 458, y: 881, band: 4 },
            { x: 538, y: 854, band: 2 },
            { x: 766, y: 894, band: 6 }, { x: 834, y: 921, band: 2 },
            { x: 905, y: 898, band: 5 }, { x: 970, y: 935, band: 1 },
            { x: 1046, y: 915, band: 7 },
            { x: 1514, y: 919, band: 4 }, { x: 1581, y: 934, band: 0 },
            { x: 1630, y: 884, band: 6 }, { x: 1693, y: 905, band: 3 },
            { x: 1785, y: 853, band: 7 },
            { x: 2008, y: 869, band: 1 }, { x: 2110, y: 809, band: 3 },
            { x: 2150, y: 875, band: 0 }, { x: 2164, y: 756, band: 5 },
            { x: 2265, y: 822, band: 2 }, { x: 2324, y: 697, band: 6 },
            { x: 2392, y: 780, band: 4 }
        ]
        delegate: Image {
            id: fly
            required property var modelData
            required property int index

            readonly property int band: modelData.band
            readonly property real phase: index * 2.4
            readonly property real flight: clearing.time * (0.53 + 0.061 * band) + phase
            readonly property real pulse: 0.5 + 0.5 * Math.sin(1.67 * flight + 0.41 * band)
            property real level: Math.sqrt(clearing.samples[band] ?? 0)
            Behavior on level {
                NumberAnimation { duration: 170 - 14 * fly.band; easing.type: Easing.OutQuad }
            }

            source: "firefly.svg"
            sourceSize: Qt.size(80, 80)
            width: (66 - 3.2 * band) * (0.72 + 0.45 * level)
            height: width
            x: modelData.x - width / 2 + (16 + 14 * level) * Math.sin(flight)
            y: modelData.y - height / 2 + 9 * Math.sin(1.6 * flight + phase)
                - level * (12 + band * 2.4) * (0.5 + 0.5 * pulse)
            rotation: 21 * Math.sin(flight + phase)
            opacity: level * (0.24 + 0.76 * pulse)
            visible: opacity > 0.012
        }
    }
}
