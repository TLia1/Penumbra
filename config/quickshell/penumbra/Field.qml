import QtQuick
import QtQuick.Controls

// A one-line text box in the panels' style; `invalid` rings it in rose.
TextField {
    id: root

    property bool invalid: false

    color: Theme.text
    placeholderTextColor: Theme.dim
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentInk
    font.family: Theme.sans
    font.pixelSize: Theme.textBody
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        implicitHeight: 32
        radius: Theme.corner(10)
        color: Theme.glassStrong
        border.color: root.invalid ? Theme.rose : root.activeFocus ? Theme.accent : Theme.lineStrong
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }
}
