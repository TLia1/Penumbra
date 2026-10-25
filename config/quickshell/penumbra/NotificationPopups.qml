import QtQuick
import Quickshell
import Quickshell.Wayland

// New notifications slide in at the top right, then retire to the control center.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 10 + Theme.gap; right: Theme.edge }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: Math.max(1, column.height)
    visible: Notifs.popups.length > 0 && !Ui.controlOpen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "penumbra-popups"
    // A click gives the popup the keyboard, for inline replies.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Only the cards take input; the rest of the column passes clicks through.
    mask: Region { item: column }

    Column {
        id: column
        width: parent.width
        spacing: 8
        move: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }

        Repeater {
            model: Notifs.popups
            delegate: NotificationCard {
                id: card
                required property var modelData
                width: column.width
                notification: modelData
                opacity: 0
                x: 40
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

                Timer {
                    interval: Notifs.timeout(card.modelData)
                    running: interval > 0 && !card.hoveredCard
                    onTriggered: Notifs.retire(card.modelData)
                }
                readonly property bool hoveredCard: hover.hovered
                HoverHandler { id: hover }
            }
        }
    }
}
