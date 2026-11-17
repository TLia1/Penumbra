import QtQuick

// Pill switch.
Rectangle {
    id: root

    property bool checked: false
    property string accessibleLabel: "Toggle"
    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: accessibleLabel
    Accessible.checked: checked
    Accessible.onToggleAction: toggled()
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    Keys.onEnterPressed: toggled()
    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    radius: Theme.corner(12)
    color: checked ? Theme.accent : Theme.raised
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? Theme.accentBright : checked ? Theme.accentBright : Theme.lineStrong
    Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18
        height: 18
        radius: Theme.corner(9)
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.accentInk : Theme.textSoft
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
