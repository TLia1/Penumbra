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
    // Big images (screenshots, photos) show under the text; small ones (avatars) are the icon.
    readonly property bool largeImage: probe.status === Image.Ready && probe.implicitWidth >= 240
    readonly property string appIconSource: {
        const icon = notification?.appIcon ?? "";
        if (!icon)
            return "";
        return icon.startsWith("/") || icon.includes("://") ? icon : Quickshell.iconPath(icon, true);
    }
    readonly property string iconSource: notification?.image && !largeImage ? notification.image : appIconSource
    Image {
        id: probe
        visible: false
        source: root.notification?.image ?? ""
        asynchronous: true
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
                radius: Theme.corner(10)
                color: Theme.raised
                visible: root.iconSource !== ""
                IconImage {
                    anchors.fill: parent
                    source: root.iconSource
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: Theme.corner(10)
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
                Label {
                    text: Notifs.age(root.notification, Clock.date.getTime())
                    font.pixelSize: 10
                    color: Theme.dim
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
            ClippingRectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.preferredHeight: Math.min(root.compact ? 120 : 180, width * probe.implicitHeight / Math.max(1, probe.implicitWidth))
                visible: root.largeImage
                radius: Theme.corner(10)
                color: Theme.raised
                Image {
                    anchors.fill: parent
                    source: root.largeImage ? root.notification.image : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            // Inline reply, for chat apps that offer it.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.notification?.hasInlineReply ?? false
                implicitHeight: 34
                radius: Theme.corner(17)
                color: Theme.raised
                border.color: reply.activeFocus ? Theme.violet : Theme.line
                TextInput {
                    id: reply
                    anchors { fill: parent; leftMargin: 14; rightMargin: 40 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.sans
                    font.pixelSize: 12
                    selectionColor: Theme.violetDeep
                    clip: true
                    function send() {
                        if (!text.trim())
                            return;
                        root.notification.sendInlineReply(text);
                        root.notification.dismiss();
                    }
                    Keys.onReturnPressed: send()
                    Keys.onEnterPressed: send()
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !reply.text
                        text: root.notification?.inlineReplyPlaceholder || "Reply…"
                        font.pixelSize: 12
                        color: Theme.dim
                    }
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    radius: Theme.corner(14)
                    color: reply.text ? Theme.violet : "transparent"
                    Glyph { anchors.centerIn: parent; text: "󰒊"; size: 13; color: reply.text ? Theme.violetInk : Theme.dim }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: reply.send()
                    }
                }
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
                        radius: Theme.corner(14)
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
