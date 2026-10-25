import QtQuick
import QtQuick.Layouts

// Pending updates by source, under the updates capsule; "Update now" opens the Kitty session.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge - shadowRoom
    sheetWidth: 400
    open: Ui.updatesOpen
    onDismissed: Ui.dismiss()

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 42
                implicitHeight: 42
                radius: Theme.corner(21)
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.violet }
                    GradientStop { position: 1; color: Theme.violetDeep }
                }
                Glyph { anchors.centerIn: parent; text: "󰚰"; size: 19; color: Theme.violetInk }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Label {
                    text: Sys.updates === 1 ? "1 update" : `${Sys.updates} updates`
                    font.pixelSize: Theme.textLarge
                    font.weight: Font.DemiBold
                }
                Label {
                    text: Sys.checkingUpdates ? "Checking…" : "Checked every 15 minutes"
                    font.pixelSize: Theme.textSmall
                    color: Theme.muted
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: list
                width: parent.width
                spacing: 6

                Repeater {
                    model: Sys.updateSources
                    delegate: ColumnLayout {
                        id: source
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2

                        Overline {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            Layout.bottomMargin: 2
                            text: `${source.modelData.name} · ${source.modelData.packages.length}`
                        }
                        Repeater {
                            model: source.modelData.packages
                            // "name old -> new", or just a Flatpak ref.
                            delegate: RowLayout {
                                required property string modelData
                                readonly property var parts: modelData.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)$/)
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                spacing: 8
                                Label {
                                    Layout.fillWidth: true
                                    text: parent.parts ? parent.parts[1] : parent.modelData
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.textSmall
                                }
                                Label {
                                    visible: !!parent.parts
                                    text: parent.parts ? `${parent.parts[2]} → ${parent.parts[3]}` : ""
                                    Layout.maximumWidth: 190
                                    font.family: Theme.mono
                                    font.pixelSize: Theme.textTiny
                                    color: Theme.violet
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8
            Item { Layout.fillWidth: true }
            PillButton {
                text: "Check again"
                implicitHeight: 34
                available: !Sys.checkingUpdates
                onClicked: Sys.refreshUpdates()
            }
            PillButton {
                text: "Update now"
                primary: true
                implicitHeight: 34
                onClicked: {
                    Ui.close();
                    Ui.run(Ui.bin + "penumbra-updates open");
                }
            }
        }
    }
}
