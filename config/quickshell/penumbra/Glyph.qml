import QtQuick

// A Nerd Font icon.
Text {
    property real size: 14
    color: Theme.textSoft
    font.family: Theme.mono
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
