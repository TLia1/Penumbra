import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Sound: pick the output and input device, and set each app's own volume.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: audioNodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: audioNodes.filter(n => !n.isSink && !n.isStream)
    // Apps playing sound. Quickshell flags playback streams as sinks (AudioOutStream =
    // Audio | Sink | Stream); recording streams are sources and are left out.
    readonly property var streams: audioNodes.filter(n => n.isStream && n.isSink)

    spacing: 12

    // Volume, mute and properties are only live on tracked nodes.
    PwObjectTracker {
        objects: root.active ? [...root.outputs, ...root.inputs, ...root.streams] : []
    }

    // The port ("Speaker", "HDMI / DisplayPort 1 Output") tells a card's devices apart;
    // Bluetooth devices go by their own name.
    function deviceName(node) {
        const port = node.name.startsWith("bluez") ? "" : node.properties["device.profile.description"];
        return port || node.description || node.nickname || node.name;
    }
    function deviceGlyph(node, input) {
        const name = (node.name + " " + node.description).toLowerCase();
        if (name.includes("bluez") || name.includes("headset") || name.includes("headphone"))
            return input ? "󰋎" : "󰋋";
        if (name.includes("hdmi") || name.includes("displayport"))
            return "󰡁";
        return input ? "󰍬" : "󰓃";
    }
    function appName(node) {
        const p = node.properties;
        return p["application.name"] || node.description || node.name;
    }
    function appIcon(node) {
        const p = node.properties;
        const entry = DesktopEntries.heuristicLookup(p["application.process.binary"] ?? p["application.name"] ?? "");
        return Quickshell.iconPath(p["application.icon-name"] || entry?.icon || p["application.process.binary"] || "", "audio-volume-high");
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Sound"
        status: Pipewire.defaultAudioSink ? root.deviceName(Pipewire.defaultAudioSink) : "No output"
        showSwitch: false
        onBack: Ui.controlPage = "main"
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "Output"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }
    Repeater {
        model: root.outputs
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            glyph: root.deviceGlyph(modelData, false)
            title: root.deviceName(modelData)
            highlighted: Pipewire.defaultAudioSink === modelData
            subtitle: highlighted ? "In use" : ""
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: root.inputs.length > 0
        text: "Input"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }
    Repeater {
        model: root.inputs
        delegate: ListRow {
            required property var modelData
            Layout.fillWidth: true
            glyph: root.deviceGlyph(modelData, true)
            title: root.deviceName(modelData)
            highlighted: Pipewire.defaultAudioSource === modelData
            subtitle: highlighted ? "In use" : ""
            onClicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "Applications"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }
    Repeater {
        model: root.streams
        delegate: ColumnLayout {
            id: stream
            required property var modelData
            Layout.fillWidth: true
            spacing: 0
            Label {
                Layout.fillWidth: true
                Layout.leftMargin: 46
                text: root.appName(stream.modelData) + (stream.modelData.properties["media.name"] ? " · " + stream.modelData.properties["media.name"] : "")
                font.pixelSize: 11
                color: Theme.textSoft
            }
            SliderRow {
                Layout.fillWidth: true
                icon: root.appIcon(stream.modelData)
                value: Math.round((stream.modelData.audio?.volume ?? 0) * 100)
                muted: stream.modelData.audio?.muted ?? false
                onMoved: v => { stream.modelData.audio.muted = false; stream.modelData.audio.volume = v / 100; }
                onGlyphClicked: stream.modelData.audio.muted = !stream.modelData.audio.muted
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        visible: root.streams.length === 0
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰝚"; size: 26; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "No app is playing sound"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        text: "Advanced sound settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("pavucontrol"); }
        }
    }
}
