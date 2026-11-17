import QtQuick

// One activation path for pointer, keyboard and assistive technology.
MouseArea {
    id: action
    required property string actionName
    property bool clickActivates: true
    signal triggered()
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: actionName
    Accessible.onPressAction: if (enabled) triggered()
    Keys.onReturnPressed: triggered()
    Keys.onEnterPressed: triggered()
    Keys.onSpacePressed: triggered()
    onClicked: if (clickActivates) triggered()

    Rectangle {
        anchors.fill: parent
        visible: action.activeFocus
        color: "transparent"
        border.color: Theme.accentBright
        border.width: 2
        radius: Theme.radiusSmall
        z: 100
    }
}
