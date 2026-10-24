import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth devices: discover, pair, connect, disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var adapter: Devices.adapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var all: Bluetooth.devices.values
    readonly property var paired: all.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices only advertise their address; leave them out.
    readonly property var available: all.filter(d => !d.paired && !d.bonded && d.deviceName && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name))
        .sort((a, b) => a.name.localeCompare(b.name))
    property string expanded: ""
    property string pairingAddress: ""

    spacing: 12

    // Discover only while the page is on screen.
    function updateDiscovery() {
        if (adapter && adapter.enabled && adapter.discovering !== active)
            adapter.discovering = active;
    }
    onActiveChanged: { updateDiscovery(); if (!active) expanded = ""; }
    onPoweredChanged: updateDiscovery()

    function glyphFor(device) {
        const icon = device.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone"))
            return "󰋋";
        if (icon.includes("audio") || icon.includes("speaker"))
            return "󰓃";
        if (icon.includes("mouse"))
            return "󰍽";
        if (icon.includes("keyboard"))
            return "󰌌";
        if (icon.includes("gaming") || icon.includes("joystick"))
            return "󰊴";
        if (icon.includes("phone"))
            return "󰏲";
        if (icon.includes("computer"))
            return "󰌢";
        return "󰂯";
    }
    function statusFor(device) {
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (device.connected)
            return device.batteryAvailable ? `Connected · ${Math.round(device.battery > 1 ? device.battery : device.battery * 100)}% battery` : "Connected";
        return "Not connected";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        status: !root.adapter ? "No adapter" : !root.powered ? "Off" : root.adapter.discovering ? "On · searching for devices" : "On"
        showSwitch: !!root.adapter
        checked: root.powered
        onBack: Ui.controlPage = "main"
        onToggled: root.adapter.enabled = !root.adapter.enabled
    }

    component SectionTitle: Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    Flickable {
        id: scroller
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 400)
        visible: root.powered
        contentHeight: sections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: scroller.contentHeight > scroller.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: sections
            width: scroller.width
            spacing: 4

            SectionTitle { visible: root.paired.length > 0; text: "My devices" }
            Repeater {
                model: root.paired
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    readonly property bool changing: dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: root.statusFor(dev)
                    highlighted: dev.connected
                    busy: changing
                    expanded: root.expanded === dev.address
                    onClicked: {
                        const open = root.expanded === dev.address;
                        root.expanded = open ? "" : dev.address;
                        // One click connects; the row stays open for Disconnect and Forget.
                        if (!open && !dev.connected && !changing)
                            dev.connect();
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        PillButton {
                            text: row.dev.connected ? "Disconnect" : "Connect"
                            primary: !row.dev.connected
                            available: !row.changing
                            onClicked: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                        }
                        PillButton {
                            text: "Forget"
                            danger: true
                            onClicked: { root.expanded = ""; row.dev.forget(); }
                        }
                    }
                }
            }

            SectionTitle {
                Layout.topMargin: root.paired.length ? 10 : 2
                text: root.available.length ? "Available devices" : "Searching for devices…"
            }
            Repeater {
                model: root.available
                delegate: ListRow {
                    id: candidate
                    required property var modelData
                    readonly property var dev: modelData
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: dev.pairing ? "Pairing…" : "Click to pair"
                    busy: dev.pairing
                    onClicked: {
                        if (dev.pairing)
                            return;
                        root.pairingAddress = dev.address;
                        dev.pair();
                    }
                    // Trust and connect as soon as pairing completes.
                    Connections {
                        target: candidate.dev
                        function onPairedChanged() {
                            if (candidate.dev.paired && root.pairingAddress === candidate.dev.address) {
                                root.pairingAddress = "";
                                candidate.dev.trusted = true;
                                candidate.dev.connect();
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.powered
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰂲"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.adapter ? "This computer has no Bluetooth adapter" : "Bluetooth is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        visible: !!root.adapter
        text: "Advanced Bluetooth settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("blueman-manager"); }
        }
    }
}
