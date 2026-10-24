import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// One notification: icon, app, summary, body and actions. Click runs the default action.
Rectangle {
    id: root

    required property var notification
    property bool compact: false
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + 28
    radius: Theme.radius
    color: compact ? (area.containsMouse ? Theme.hover : Theme.raised) : Theme.glassStrong
    border.color: critical ? Theme.rose : compact ? Theme.line : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const n = root.notification;
            const action = n.actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            n.dismiss();
        }
    }

    RowLayout {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource !== ""
                IconImage {
                    anchors.fill: parent
                    source: root.iconSource
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource === ""
                Glyph {
                    anchors.centerIn: parent
                    text: root.critical ? "󰀦" : "󰂚"
                    size: 17
                    color: root.critical ? Theme.rose : Theme.violetBright
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: root.notification?.appName || "Notification"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: root.critical ? Theme.rose : Theme.violet
                }
                Glyph {
                    text: "󰅖"
                    size: 13
                    color: close.containsMouse ? Theme.text : Theme.dim
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 4
                color: Theme.textSoft
                linkColor: Theme.violetBright
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: actionLabel.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: actionArea.containsMouse ? Theme.violet : Theme.raised
                        border.color: Theme.line
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: 11
                            color: actionArea.containsMouse ? Theme.violetInk : Theme.text
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke();
                                root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
