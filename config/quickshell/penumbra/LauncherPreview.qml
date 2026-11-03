import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Selected-result details. Live capture stops as soon as the launcher closes.
Rectangle {
    id: root
    property var result: null
    property bool active: false
    property url clipImage: ""
    readonly property var entry: result?.entry ?? null
    readonly property string kind: result?.kind ?? ""
    radius: Theme.radius
    color: Theme.raised
    border.color: Theme.line
    clip: true
    CardLight { radius: root.radius }
    ColumnLayout {
        anchors { fill: parent; margins: 18 }
        spacing: 12
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            radius: Theme.radiusSmall
            color: Theme.surface
            Loader {
                anchors.fill: parent
                active: root.active && root.kind === "window"
                sourceComponent: ScreencopyView {
                    captureSource: root.result?.toplevel ?? null
                    live: root.active
                    constraintSize: Qt.size(width, height)
                }
            }
            Image {
                anchors.fill: parent
                visible: root.kind === "clip" && root.clipImage.toString() !== ""
                source: visible ? root.clipImage : ""
                asynchronous: true
                sourceSize: Qt.size(560, 280)
                fillMode: Image.PreserveAspectFit
            }
            IconImage {
                anchors.centerIn: parent
                implicitSize: 64
                visible: ["app", "action"].includes(root.kind)
                source: visible ? Quickshell.iconPath(root.entry?.icon || "", "application-x-executable") : ""
                asynchronous: true
            }
            Glyph {
                anchors.centerIn: parent
                visible: !["app", "action", "window"].includes(root.kind) && !root.clipImage.toString()
                text: "󰅍"; size: 40; color: Theme.accentBright
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.kind === "window" ? root.result?.toplevel?.title ?? ""
                : root.entry?.name ?? (root.kind === "pin" ? "Pinned note" : "Clipboard")
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.pixelSize: Theme.textTitle
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.entry?.comment || root.entry?.genericName || root.result?.text || root.result?.clip?.text || ""
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignTop
            color: Theme.textSoft
            maximumLineCount: 8
        }
        Label {
            Layout.fillWidth: true
            text: root.kind === "window" ? "Enter to focus" : ["clip", "pin"].includes(root.kind) ? "Enter to copy" : "Enter to launch"
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }
}
