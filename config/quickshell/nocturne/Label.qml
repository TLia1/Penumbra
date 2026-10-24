import QtQuick

Text {
    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: 12
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
