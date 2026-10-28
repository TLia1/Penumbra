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
    // Decoded no wider than 240: an image only ever shrinks to fit, so it still tells which are
    // that wide, and their shape, without holding a whole screenshot.
    Image {
        id: probe
        visible: false
        source: root.notification?.image ?? ""
        sourceSize.width: 240
        asynchronous: true
    }

    implicitHeight: layout.implicitHeight + 28
    radius: Theme.radius
    color: compact ? (area.containsMouse ? Theme.hover : Theme.raised) : Theme.glassStrong
    border.color: critical ? Theme.rose : compact ? Theme.line : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Shadow {
        z: -1
        target: root
        visible: !root.compact
        // A child already takes the card's fade and scale.
        opacity: 1
        scale: 1
    }
    GlassEdge {
        visible: !root.compact
        radius: root.radius
    }

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
                    color: root.critical ? Theme.rose : Theme.accentBright
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
                    font.pixelSize: Theme.textTiny
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: root.critical ? Theme.rose : Theme.accent
                }
                Label {
                    text: Notifs.age(root.notification, Clock.date.getTime())
                    font.pixelSize: Theme.textTiny
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
                font.pixelSize: Theme.textMedium
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
                linkColor: Theme.accentBright
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
                    // Twice the card's width, at most 360.
                    sourceSize.width: 720
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
                border.color: reply.activeFocus ? Theme.accent : Theme.line
                TextInput {
                    id: reply
                    anchors { fill: parent; leftMargin: 14; rightMargin: 40 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.sans
                    font.pixelSize: Theme.textBody
                    selectionColor: Theme.accentDeep
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
                        font.pixelSize: Theme.textBody
                        color: Theme.dim
                    }
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 3; verticalCenter: parent.verticalCenter }
                    width: 28
                    height: 28
                    radius: Theme.corner(14)
                    color: reply.text ? Theme.accent : "transparent"
                    Glyph { anchors.centerIn: parent; text: "󰒊"; size: 13; color: reply.text ? Theme.onAccent : Theme.dim }
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
                        color: actionArea.containsMouse ? Theme.accent : Theme.raised
                        border.color: Theme.line
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: Theme.textSmall
                            color: actionArea.containsMouse ? Theme.onAccent : Theme.text
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
