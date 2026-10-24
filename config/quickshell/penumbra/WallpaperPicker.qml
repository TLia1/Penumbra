import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// The three wallpapers side by side; click one to switch with penumbra-wallpaper's transition.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge
    sheetWidth: 620
    open: Ui.wallpapersOpen
    onDismissed: Ui.dismiss()

    readonly property var choices: [
        { name: "wallpaper", title: "Night", animated: false },
        { name: "wallpaper-dawn", title: "Dawn", animated: true },
        { name: "wallpaper-eclipse", title: "Eclipse", animated: true }
    ]

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12

        Label {
            text: "Wallpaper"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: root.choices
                delegate: ColumnLayout {
                    id: choice
                    required property var modelData
                    readonly property bool current: Ui.wallpaper === modelData.name
                    Layout.fillWidth: true
                    // Equal thirds, whatever the labels' widths.
                    Layout.preferredWidth: 1
                    spacing: 6

                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width * 9 / 16
                        radius: Theme.radiusSmall
                        color: Theme.raised
                        border.width: choice.current ? 2 : 1
                        border.color: choice.current ? Theme.violet : area.containsMouse ? Theme.lineStrong : Theme.line
                        contentUnderBorder: true
                        Image {
                            anchors.fill: parent
                            source: "file://" + Ui.wallpapers + choice.modelData.name + ".png"
                            sourceSize.width: 360
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            scale: area.containsMouse ? 1.04 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
                        }
                        Rectangle {
                            visible: choice.modelData.animated
                            anchors { left: parent.left; top: parent.top; margins: 8 }
                            implicitWidth: badge.implicitWidth + 14
                            implicitHeight: 20
                            radius: 10
                            color: Theme.glassStrong
                            Label {
                                id: badge
                                anchors.centerIn: parent
                                text: "Animated"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Theme.violetBright
                            }
                        }
                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!choice.current)
                                    Ui.run(Ui.bin + "penumbra-wallpaper " + choice.modelData.name);
                            }
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6
                        Rectangle {
                            visible: choice.current
                            implicitWidth: 6
                            implicitHeight: 6
                            radius: 3
                            color: Theme.violet
                        }
                        Label {
                            text: choice.modelData.title
                            font.weight: choice.current ? Font.DemiBold : Font.Normal
                            color: choice.current ? Theme.text : Theme.muted
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Super+W cycles through them · the lock screen follows your choice"
            font.pixelSize: 11
            color: Theme.dim
        }
    }
}
