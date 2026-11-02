import QtQuick
import Quickshell
import Quickshell.Wayland

// New notifications slide in at the top right, then retire to the control center.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; right: true }
    // Room around the cards for their shadows.
    readonly property int shadowRoom: Theme.edge
    margins { top: Theme.barHeight + 10 + Theme.gap - shadowRoom; right: Theme.edge - shadowRoom }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360 + 2 * shadowRoom
    implicitHeight: Math.max(1, column.height + 2 * shadowRoom)
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
        x: root.shadowRoom
        y: root.shadowRoom
        width: parent.width - 2 * root.shadowRoom
        spacing: 8
        move: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }

        // ScriptModel keeps existing cards when the array is replaced, so their
        // timers, hover state and reply text survive a new notification.
        Repeater {
            model: ScriptModel { values: Notifs.popups }
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
