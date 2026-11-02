import QtQuick

Text {
    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: Theme.textBody
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
}
