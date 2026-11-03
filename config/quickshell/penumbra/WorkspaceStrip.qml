import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// One shared glass surface; the two edges of its active pill travel at different speeds.
Rectangle {
    id: root
    required property var workspaces
    // Compact to numbers when the rest of the bar needs the space.
    property bool showIcons: true
    readonly property int activeIndex: workspaces.findIndex(w => w.active)
    readonly property Item activeItem: spaces.count > activeIndex && activeIndex >= 0 ? spaces.itemAt(activeIndex) : null
    readonly property real targetLeft: activeItem ? activeItem.x + row.x : 4
    readonly property real targetRight: activeItem ? targetLeft + activeItem.width : 4
    property real previousLeft: 4
    property bool movingRight: true
    property bool ready: false
    onTargetLeftChanged: {
        movingRight = targetLeft >= previousLeft;
        previousLeft = targetLeft;
    }
    Component.onCompleted: Qt.callLater(() => root.ready = true)

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.barHeight
    radius: Theme.corner(height / 2)
    color: Theme.glass
    border.color: Theme.line
    clip: true

    Rectangle {
        id: indicator
        property real leftEdge: root.targetLeft
        property real rightEdge: root.targetRight
        x: Math.min(leftEdge, rightEdge)
        y: 4
        width: Math.max(0, Math.abs(rightEdge - leftEdge))
        height: parent.height - 8
        radius: Theme.corner(height / 2)
        visible: !!root.activeItem
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accentBright }
            GradientStop { position: 1; color: Theme.accent }
        }
        Behavior on leftEdge {
            enabled: root.ready
            NumberAnimation { duration: (root.movingRight ? 340 : 220) * Theme.motion; easing.type: Easing.OutCubic }
        }
        Behavior on rightEdge {
            enabled: root.ready
            NumberAnimation { duration: (root.movingRight ? 220 : 340) * Theme.motion; easing.type: Easing.OutCubic }
        }
        GlassEdge { radius: indicator.radius; strength: 0.55 }
    }

    GlassEdge { radius: root.radius; strength: 0.2 }
    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
            id: spaces
            model: ScriptModel { values: root.workspaces }
            delegate: Rectangle {
                id: workspace
                required property var modelData
                readonly property bool current: modelData.active
                readonly property var windows: modelData.toplevels.values
                readonly property string tip: "Workspace " + modelData.name + (windows.length ? " · " + windows.length + " windows" : "")
                width: Math.max(36, contents.implicitWidth + 20)
                height: root.height - 8
                radius: Theme.corner(height / 2)
                color: current ? "transparent" : modelData.urgent ? Theme.alpha(Theme.rose, 0.3) : mouse.containsMouse ? Theme.hover : "transparent"
                Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }
                RowLayout {
                    id: contents
                    anchors.centerIn: parent
                    spacing: 5
                    Label {
                        text: workspace.modelData.name
                        color: workspace.current ? Theme.onAccent : workspace.modelData.urgent ? Theme.rose : Theme.textSoft
                        font.weight: workspace.current ? Font.Bold : Font.DemiBold
                    }
                    Repeater {
                        model: root.showIcons ? workspace.windows.slice(0, 2) : []
                        delegate: Item {
                            id: app
                            required property var modelData
                            readonly property string appId: modelData.wayland?.appId || modelData.lastIpcObject?.class || ""
                            readonly property var entry: appId ? DesktopEntries.heuristicLookup(appId) : null
                            implicitWidth: 15
                            implicitHeight: 15
                            IconImage {
                                id: icon
                                anchors.fill: parent
                                source: app.entry?.icon ? Quickshell.iconPath(app.entry.icon, true) : ""
                                asynchronous: true
                            }
                            Glyph {
                                anchors.centerIn: parent
                                visible: icon.status !== Image.Ready
                                text: "󰣆"
                                size: 13
                                color: workspace.current ? Theme.onAccent : Theme.subtle
                            }
                        }
                    }
                    Label {
                        visible: root.showIcons && workspace.windows.length > 2
                        text: "+" + (workspace.windows.length - 2)
                        font.pixelSize: Theme.textTiny
                        color: workspace.current ? Theme.onAccent : Theme.subtle
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: workspace.modelData.activate()
                }
            }
        }
    }
}
