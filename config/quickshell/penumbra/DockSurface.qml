import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Visual dock shared by the live layer-shell window and the offscreen preview harness.
Item {
    id: root
    property var apps: []
    property bool shown: false
    property string hoveredKey: ""
    readonly property var hoveredApp: apps.find(a => a.key === hoveredKey) ?? null
    readonly property bool previewing: shown && (hoveredApp?.windows.length ?? 0) > 0
    readonly property real trayWidth: tray.width
    signal togglePin(var app)
    signal launchApp(var entry)
    signal activateWindow(var window)
    signal openLauncher()
    Rectangle {
        id: tray
        anchors { bottom: parent.bottom; bottomMargin: 10; horizontalCenter: parent.horizontalCenter }
        width: Math.min(root.width - 20, root.apps.length * 56 + 64)
        height: 64
        radius: Theme.radiusLarge
        color: Theme.panel
        border.color: Theme.line
        opacity: root.shown ? 1 : 0
        transform: Translate { y: root.shown ? 0 : 80; Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } } }
        Behavior on opacity { NumberAnimation { duration: Theme.fast } }
        GlassEdge { radius: parent.radius }
        Flickable {
            anchors { fill: parent; margins: 6 }
            contentWidth: row.width
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            Row {
                id: row
                spacing: 4
                Repeater {
                    model: root.apps
                    delegate: Rectangle {
                        id: app
                        required property var modelData
                        readonly property bool focused: modelData.windows.some(w => w.activated)
                        width: 52
                        height: 52
                        radius: Theme.corner(14)
                        color: pointer.containsMouse ? Theme.hover : "transparent"
                        scale: Theme.reducedMotion ? 1 : pointer.pressed ? 0.94 : pointer.containsMouse ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast } }
                        AppIcon {
                            id: appIcon
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                            implicitSize: 32
                            icon: app.modelData.entry?.icon ?? ""
                            asynchronous: true
                        }
                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            spacing: 3
                            Repeater {
                                model: Math.min(3, app.modelData.windows.length)
                                delegate: Rectangle { width: app.focused ? 10 : 4; height: 3; radius: Theme.corner(2); color: app.focused ? Theme.accentBright : Theme.muted }
                            }
                        }
                        Rectangle {
                            visible: !!app.modelData.pin
                            x: 3; y: 3; width: 3; height: 3; radius: 2; color: Theme.accent
                        }
                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hoveredKey = app.modelData.key
                            onClicked: event => {
                                const a = app.modelData;
                                if (event.button === Qt.RightButton && a.entry) {
                                    root.togglePin(a);
                                } else if (event.button === Qt.MiddleButton || !a.windows.length) {
                                    root.launchApp(a.entry);
                                } else {
                                    const index = a.windows.findIndex(w => w.activated);
                                    root.activateWindow(a.windows[(index + 1) % a.windows.length]);
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    width: 48; height: 52; radius: Theme.corner(14)
                    color: launcher.containsMouse ? Theme.hover : "transparent"
                    Glyph { anchors.centerIn: parent; text: "󰀻"; size: 26; color: Theme.accentBright }
                    MouseArea {
                        id: launcher
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredKey = ""
                        onClicked: root.openLauncher()
                    }
                }
            }
        }
    }
    Rectangle {
        id: preview
        visible: root.previewing
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        height: 156
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.line
        GlassEdge { radius: parent.radius }
        Flickable {
            anchors { fill: parent; margins: 8 }
            contentWidth: previews.width
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            Row {
                id: previews
                spacing: 8
                Repeater {
                    model: root.previewing ? root.hoveredApp.windows : []
                    delegate: Column {
                        id: thumb
                        required property var modelData
                        width: 200
                        spacing: 5
                        ClippingRectangle {
                            width: 200; height: 110; radius: Theme.corner(8); color: Theme.raised
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: root.visible && root.previewing ? thumb.modelData.wayland : null
                                live: root.visible && root.previewing
                                constraintSize: Qt.size(width, height)
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activateWindow(thumb.modelData) }
                        }
                        Label { width: parent.width; text: thumb.modelData.title; textFormat: Text.PlainText; font.pixelSize: Theme.textSmall }
                    }
                }
            }
        }
    }
}
