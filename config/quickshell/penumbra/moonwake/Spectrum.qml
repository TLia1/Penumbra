import QtQuick

Item {
    id: spectrum
    required property var samples
    // The origin is the far bank. Keep the entire spectrum in the central
    // valley so the bands remain visible when the scene is cropped.
    implicitWidth: samples.length * 46.5
    Repeater {
        model: spectrum.samples.length
        delegate: Item {
            id: band
            required property int index
            x: (index + 0.5) * spectrum.width / spectrum.samples.length - width / 2
            width: 22
            readonly property real pitch: index / Math.max(1, spectrum.samples.length - 1)
            readonly property color tint: Qt.rgba(1 - 0.26 * pitch, 0.82 - 0.06 * pitch, 0.70 + 0.30 * pitch, 1)
            property real level: Math.max(0, Math.min(1, spectrum.samples[index] ?? 0))
            Behavior on level {
                NumberAnimation { duration: 85; easing.type: Easing.OutCubic }
            }
            visible: level > 0.006

            Rectangle {
                id: column
                anchors.bottom: parent.top
                width: parent.width
                height: 192 * Math.pow(band.level, 0.8)
                radius: Math.min(3, height / 2)
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(band.tint, 1.18) }
                    GradientStop { position: 0.18; color: band.tint }
                    GradientStop { position: 1; color: Qt.alpha(band.tint, 0.55) }
                }
            }
            // The lake starts 24 scene units below the bank.
            Repeater {
                model: 6
                delegate: Rectangle {
                    required property int index
                    readonly property real depth: (index + 0.5) / 6
                    y: 24 + depth * column.height * 0.41
                    x: (band.width - width) / 2 + depth * 4 * Math.sin(2.1 * index + band.index)
                    width: band.width * (1 - 0.5 * depth)
                    height: Math.min(2.8, column.height * 0.035)
                    radius: height / 2
                    color: band.tint
                    opacity: (0.66 - 0.44 * depth) * Math.sqrt(band.level)
                }
            }
        }
    }
}
