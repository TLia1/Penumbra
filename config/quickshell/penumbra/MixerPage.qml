import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// Sound: pick the output and input device, and set each app's own volume.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var audioNodes: Pipewire.nodes.values.filter(n => n.audio)
    // A laptop's HDMI and DisplayPort outputs exist even with nothing plugged in; list them only
    // while an external screen is connected, or while one is in use.
    readonly property bool externalScreen: Quickshell.screens.some(s => !/^(eDP|LVDS|DSI)/.test(s.name))
    readonly property var outputs: audioNodes.filter(n => n.isSink && !n.isStream
        && (externalScreen || !isDisplayOutput(n) || n === Pipewire.defaultAudioSink))
    readonly property var inputs: audioNodes.filter(n => !n.isSink && !n.isStream)
    // Apps playing sound. Quickshell flags playback streams as sinks (AudioOutStream =
    // Audio | Sink | Stream); recording streams are sources and are left out.
    readonly property var streams: audioNodes.filter(n => n.isStream && n.isSink)

    spacing: 12

    // Volume, mute and properties are only live on tracked nodes.
    PwObjectTracker {
        objects: root.active ? [...root.outputs, ...root.inputs, ...root.streams] : []
    }

    function isDisplayOutput(node) {
        return /hdmi|displayport/i.test(node.name + " " + node.description);
    }
    // The port ("Speaker") tells a card's devices apart, a display output goes by its short name
    // ("HDMI 1"), and Bluetooth devices by their own name.
    function deviceName(node) {
        if (isDisplayOutput(node) && node.nickname)
            return node.nickname;
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

    Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "Output"
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

    Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: root.inputs.length > 0
        text: "Input"
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

    Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
        text: "Applications"
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
                font.pixelSize: Theme.textSmall
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
        font.pixelSize: Theme.textSmall
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
