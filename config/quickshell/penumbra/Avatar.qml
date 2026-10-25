import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

// Your ~/.face when there is one, else your initial on a violet disc. The control center and
// the lock screen show the same one.
ClippingRectangle {
    id: root

    property int size: 42
    property bool ring: false

    implicitWidth: size
    implicitHeight: size
    radius: Theme.corner(size / 2)
    border.width: ring ? 2 : 0
    border.color: Theme.violet

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.violet }
            GradientStop { position: 1; color: Theme.violetDeep }
        }
    }
    Label {
        anchors.centerIn: parent
        visible: face.status !== Image.Ready
        text: Quickshell.env("USER").charAt(0).toUpperCase()
        font.family: Theme.display
        font.pixelSize: Math.round(root.size * 0.4)
        font.weight: Font.Bold
        color: Theme.violetInk
    }
    Image {
        id: face
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        asynchronous: true
    }
    FileView {
        path: Quickshell.env("HOME") + "/.face"
        printErrors: false
        onLoaded: face.source = "file://" + path
    }
}
