import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Selected-result details. Live capture stops as soon as the launcher closes.
Rectangle {
    id: root
    property var result: null
    signal launchAction(var action)
    property bool active: false
    property url clipImage: ""
    readonly property var entry: result?.entry ?? null
    readonly property string kind: result?.kind ?? ""
    readonly property bool textSizeSetting: kind === "setting" && result.title === "Text size"
    readonly property bool nightSetting: kind === "setting" && result.setting.page === "night"
    radius: Theme.radius
    color: Theme.raised
    border.color: Theme.line
    clip: true
    CardLight { radius: root.radius }
    ColumnLayout {
        anchors { fill: parent; margins: Theme.padding }
        spacing: 12
        ClippingRectangle {
            Layout.fillWidth: true
            visible: !["workspace", "setting"].includes(root.kind)
            Layout.preferredHeight: 100
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
            AppIcon {
                anchors.centerIn: parent
                implicitSize: 64
                visible: ["app", "action"].includes(root.kind)
                icon: visible ? root.entry?.icon ?? "" : ""
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
            textFormat: Text.PlainText
            text: root.kind === "window" ? root.result?.toplevel?.title ?? ""
                : root.result?.title ?? root.entry?.name ?? (root.kind === "pin" ? "Pinned note" : "Clipboard")
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font.pixelSize: Theme.textTitle
            font.weight: Font.DemiBold
        }
        Stepper {
            visible: root.textSizeSetting
            accessibleLabel: "Text size"
            text: root.textSizeSetting ? Settings.textSizeLabels[Settings.textSizeIndex] : ""
            canDecrease: Settings.textSizeIndex > 0
            canIncrease: root.textSizeSetting && Settings.textSizeIndex < Settings.textSizes.length - 1
            onDecreased: Settings.textScale = Settings.textSizes[Settings.textSizeIndex - 1]
            onIncreased: Settings.textScale = Settings.textSizes[Settings.textSizeIndex + 1]
        }
        ColumnLayout {
            visible: root.nightSetting
            Layout.fillWidth: true
            Label { text: "Schedule"; color: Theme.textSoft }
            Repeater {
                model: root.nightSetting ? Settings.nightSchedules : []
                delegate: PillButton {
                    required property var modelData
                    text: modelData.title
                    primary: modelData.value === Settings.nightSchedule
                    onClicked: Settings.nightSchedule = modelData.value
                }
            }
        }
        Flickable {
            id: workspaceDetails
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.kind === "workspace"
            contentHeight: tags.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onVisibleChanged: contentY = 0
            Connections {
                target: root
                function onResultChanged() { workspaceDetails.contentY = 0; }
            }
            ColumnLayout {
                id: tags
                width: workspaceDetails.width
                spacing: 10
                Repeater {
                    model: root.kind === "workspace" ? root.result.profile.places : []
                    delegate: ColumnLayout {
                        id: place
                        required property var modelData
                        readonly property var apps: (root.result?.profile?.apps ?? []).filter(app =>
                            app.output === modelData[0] && app.tags.includes(modelData[1]))
                        Layout.fillWidth: true
                        spacing: 4
                        Label {
                            Layout.fillWidth: true
                            text: place.modelData[0] + " · Tag " + place.modelData[1]
                            textFormat: Text.PlainText
                            color: Theme.textSoft
                            font.pixelSize: Theme.textSmall
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.preferredHeight: childrenRect.height
                            spacing: 4
                            Repeater {
                                model: place.apps
                                delegate: Rectangle {
                                    id: appChip
                                    required property var modelData
                                    readonly property var application: DesktopEntries.heuristicLookup(modelData.app)
                                    width: Math.min(place.width, icon.implicitWidth + appName.implicitWidth + 24)
                                    height: Math.max(32, appName.implicitHeight + 10)
                                    radius: Theme.radiusSmall
                                    color: Theme.surface
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                        spacing: 6
                                        AppIcon { id: icon; implicitSize: 18; icon: appChip.application?.icon ?? "" }
                                        Label {
                                            id: appName
                                            Layout.fillWidth: true
                                            textFormat: Text.PlainText
                                            text: appChip.application?.name || appChip.modelData.app
                                        }
                                    }
                                }
                            }
                        }
                        Label { visible: place.apps.length === 0; text: "Empty"; color: Theme.muted }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    visible: !!text
                    text: root.result?.profile?.project ?? ""
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.kind !== "workspace"
            textFormat: Text.PlainText
            text: root.textSizeSetting ? "Shell labels use this size."
                : root.nightSetting ? ""
                : root.kind === "setting" ? "Settings › " + root.result.title
                : root.entry?.comment || root.entry?.genericName || root.result?.text || root.result?.clip?.text || ""
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignTop
            color: Theme.textSoft
            maximumLineCount: 8
        }
        Repeater {
            model: root.kind === "app" ? (root.entry?.actions ?? []).slice(0, 3) : []
            delegate: PillButton {
                required property var modelData
                text: modelData.name
                onClicked: root.launchAction(modelData)
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.kind === "workspace" ? "Enter to restore" : root.kind === "setting" ? "Enter to open setting" : root.kind === "window" ? "Enter to focus" : ["clip", "pin"].includes(root.kind) ? "Enter to copy" : "Enter to launch"
            color: Theme.muted
            font.pixelSize: Theme.textSmall
        }
    }
}
