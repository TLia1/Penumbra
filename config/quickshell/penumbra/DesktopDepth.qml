import QtQuick

// SVG-space widgets: foreground scene layers occlude the lower edge of the clock and aura.
// Reuses the bar's Cava stream; no extra audio process or frame timer.
Item {
    id: root
    required property bool active
    required property bool running
    required property point center
    required property real orbitRadius
    required property real clockY
    // Eclipse feeds the same audio samples into its existing horizon aurora instead.
    property bool radialAura: true
    readonly property bool live: active && running && Settings.desktopAura
        && !Theme.reducedMotion && Ui.hasVisualizer && !!Media.playing
    visible: active
    // Disconnect the audio binding while resting or covered.
    readonly property var samples: live ? Media.bars : []

    Column {
        z: 1
        x: root.center.x - width / 2
        y: root.clockY
        width: 800
        visible: root.active && Settings.desktopClock
        spacing: -8
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(Clock.date, "dddd, d MMMM").toUpperCase()
            font.family: Theme.sans
            font.pixelSize: 23
            font.letterSpacing: 5
            font.weight: Font.Medium
            color: Theme.accentBright
            style: Text.Outline
            styleColor: Theme.alpha(Theme.base, 0.35)
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(Clock.date, "HH:mm")
            font.family: Theme.display
            font.pixelSize: 240
            font.weight: Font.DemiBold
            font.letterSpacing: -12
            color: Theme.white
            opacity: 0.86
            style: Text.Outline
            styleColor: Theme.alpha(Theme.base, 0.35)
        }
    }

    Item {
        x: root.center.x
        y: root.center.y
        visible: root.live && root.radialAura
        Repeater {
            model: root.active && root.radialAura && Settings.desktopAura ? 64 : 0
            delegate: Item {
                required property int index
                // Mirror eight frequency bands into a continuous circular spectrum.
                readonly property real band: (index % 32) / 31 * 7
                readonly property real sample: {
                    const a = root.samples[Math.floor(band)] ?? 0;
                    const b = root.samples[Math.min(7, Math.ceil(band))] ?? 0;
                    return a + (b - a) * (band % 1);
                }
                rotation: index * 360 / 64
                Rectangle {
                    x: -2.5
                    y: -root.orbitRadius - height
                    width: 5
                    height: 4 + 70 * parent.sample
                    radius: Theme.corner(2.5)
                    color: index % 16 < 8 ? Theme.accentBright : Theme.pink
                    opacity: 0.25 + 0.5 * parent.sample
                    Behavior on height {
                        enabled: root.live
                        NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
