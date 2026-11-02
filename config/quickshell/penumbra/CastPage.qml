import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Cast the screen to a TV on the same network: pick one and it shows this screen in a moment.
ColumnLayout {
    id: root

    property bool active: false
    // The screen to cast: the one the panel opened on, unless another is picked.
    property string output: ""
    readonly property string chosenOutput: output || (Ui.screen?.name ?? "")

    spacing: 12

    // Look for TVs while the page is on screen, again every so often.
    onActiveChanged: if (active) { output = ""; Cast.scan(); }
    Component.onCompleted: if (active) Cast.scan()
    Timer {
        interval: 20000
        repeat: true
        running: root.active
        onTriggered: Cast.scan()
    }

    function glyphFor(tv) {
        return tv.kind === "chromecast" ? "󰄘" : "󰔂";
    }
    function detailFor(tv) {
        const kind = tv.kind === "chromecast" ? "Chromecast" : "DLNA";
        return tv.model ? `${tv.model} · ${kind}` : kind;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Cast screen"
        status: Cast.connecting ? `Connecting to ${Cast.tvName}…`
            : Cast.casting ? `Casting to ${Cast.tvName}`
            : Cast.scanning ? "Searching for TVs…"
            : Cast.tvs.length === 1 ? "1 TV on this network"
            : Cast.tvs.length ? `${Cast.tvs.length} TVs on this network` : "No TVs found"
        showSwitch: Cast.casting
        checked: Cast.casting
        onBack: Ui.controlPage = "main"
        onToggled: Cast.stop()
    }

    // The cast in progress.
    ListRow {
        Layout.fillWidth: true
        visible: Cast.casting
        glyph: "󰄙"
        title: Cast.tvName
        subtitle: Cast.connecting ? "Connecting…" : Cast.sound ? "Showing this screen, with sound" : "Showing this screen"
        highlighted: true
        busy: Cast.connecting
        expanded: true
        PillButton {
            text: "Stop casting"
            danger: true
            onClicked: Cast.stop()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Overline { Layout.fillWidth: true; text: "TVs" }
        Glyph {
            id: refreshGlyph
            text: "󰑐"
            size: 14
            color: Cast.scanning ? Theme.accent : refreshArea.containsMouse ? Theme.text : Theme.muted
            RotationAnimation on rotation {
                running: Cast.scanning
                from: 0
                to: 360
                duration: 1200
                loops: Animation.Infinite
                onStopped: refreshGlyph.rotation = 0
            }
            MouseArea {
                id: refreshArea
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                enabled: !Cast.scanning
                cursorShape: Qt.PointingHandCursor
                onClicked: Cast.scan()
            }
        }
    }

    Flickable {
        id: scroller
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 300)
        visible: Cast.tvs.length > 0
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: scroller.contentHeight > scroller.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: list
            width: scroller.width
            spacing: 4
            Repeater {
                model: Cast.tvs
                delegate: ListRow {
                    required property var modelData
                    readonly property bool current: Cast.casting && Cast.tvId === modelData.id
                    Layout.fillWidth: true
                    glyph: root.glyphFor(modelData)
                    title: modelData.name
                    subtitle: current ? (Cast.connecting ? "Connecting…" : "Casting") : root.detailFor(modelData)
                    highlighted: current
                    busy: current && Cast.connecting
                    trailing: current ? "" : "󰄘"
                    onClicked: if (!current) Cast.start(modelData, root.chosenOutput)
                }
            }
        }
    }

    // Nothing found yet.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        visible: Cast.tvs.length === 0
        spacing: 4
        Glyph { Layout.fillWidth: true; text: Cast.scanning || !Cast.scanned ? "󰄘" : "󰔂"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Cast.scanning || !Cast.scanned ? "Searching for TVs…" : "No TVs found"
            color: Theme.muted
        }
        Label {
            Layout.fillWidth: true
            visible: Cast.scanned && !Cast.scanning
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Turn the TV on and connect it to the same network as this computer."
            font.pixelSize: Theme.textSmall
            color: Theme.dim
        }
    }

    // Which screen, when there are several.
    ColumnLayout {
        Layout.fillWidth: true
        visible: Quickshell.screens.length > 1
        spacing: 6
        Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Screen" }
        Segmented {
            Layout.fillWidth: true
            current: root.chosenOutput
            options: Quickshell.screens.map(s => ({ value: s.name, title: s.name, glyph: "󰍹" }))
            onChosen: value => root.output = value
        }
    }

    SwitchRow {
        glyph: Settings.castSound ? "󰓃" : "󰓄"
        title: "Sound on the TV"
        subtitle: Cast.casting ? "Applies to the next cast" : "What this computer plays"
        checked: Settings.castSound
        onToggled: Settings.castSound = !Settings.castSound
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        wrapMode: Text.WordWrap
        text: "The TV shows the screen a few seconds late: fine for films and slides, not for games."
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
