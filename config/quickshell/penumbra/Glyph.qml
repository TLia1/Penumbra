import QtQuick

// A Nerd Font icon.
Text {
    id: root
    property real size: 14
    color: Theme.textSoft
    font.family: Theme.mono
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    // The non-Mono Nerd Font draws most icons wider than their one-cell advance, hanging off to
    // the right, so centring the advance leaves the icon off-centre. Pad the short side so the
    // ink, not the advance, sits in the middle.
    TextMetrics {
        id: ink
        font: root.font
        text: root.text
    }
    readonly property real inkOffset: ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2 - ink.advanceWidth / 2
    leftPadding: Math.max(0, -2 * inkOffset)
    rightPadding: Math.max(0, 2 * inkOffset)
}
