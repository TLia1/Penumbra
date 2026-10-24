import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

// Wi-Fi networks: scan, connect (with a password when needed), disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var device: Devices.wifiDevice
    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (Devices.strength(b) - Devices.strength(a)))
    property string expanded: ""
    property var failures: ({}) // network name → message

    spacing: 12

    // Scan only while the page is on screen.
    function updateScanner() {
        if (device)
            device.scannerEnabled = active && Networking.wifiEnabled;
    }
    onActiveChanged: { updateScanner(); if (!active) expanded = ""; }
    onDeviceChanged: updateScanner()
    Connections {
        target: Networking
        function onWifiEnabledChanged() { root.updateScanner(); }
    }

    function fail(name, message) {
        failures = Object.assign({}, failures, { [name]: message });
    }
    function clearFailure(name) {
        const next = Object.assign({}, failures);
        delete next[name];
        failures = next;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        status: !root.device ? "No Wi-Fi adapter" : !Networking.wifiEnabled ? "Off" : Devices.wifiNetwork ? `Connected to ${Devices.wifiNetwork.name}` : "Not connected"
        showSwitch: !!root.device
        checked: Networking.wifiEnabled
        onBack: Ui.controlPage = "main"
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Wired connection, while a cable is plugged in.
    ListRow {
        Layout.fillWidth: true
        visible: Devices.wired
        glyph: "󰈀"
        title: "Ethernet"
        subtitle: "Connected"
        highlighted: true
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: !!root.device && Networking.wifiEnabled
        text: root.networks.length ? "Networks" : "Searching for networks…"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: !!root.device && Networking.wifiEnabled
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.networks
        ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        delegate: ListRow {
            id: row
            required property var modelData
            readonly property var net: modelData
            readonly property bool secured: net.security !== WifiSecurityType.Open
            readonly property bool connecting: net.stateChanging || net.state === ConnectionState.Connecting
            readonly property string failure: root.failures[net.name] ?? ""

            width: ListView.view.width
            glyph: Devices.signalGlyph(net)
            title: net.name
            subtitle: failure !== "" ? failure : net.connected ? "Connected" : connecting ? "Connecting…" : net.known ? "Saved" : secured ? "Secured" : "Open"
            danger: failure !== ""
            trailing: secured ? "󰌾" : ""
            highlighted: net.connected
            busy: connecting
            expanded: root.expanded === net.name

            function connect() {
                root.clearFailure(net.name);
                if (net.known || !secured)
                    net.connect();
                else if (password.text !== "")
                    net.connectWithPsk(password.text);
            }

            onClicked: {
                const open = root.expanded === net.name;
                root.expanded = open ? "" : net.name;
                // Saved and open networks connect straight away; the row stays open for Forget.
                if (!open && !net.connected && (net.known || !secured))
                    connect();
                if (!open && !net.known && secured)
                    password.forceActiveFocus();
            }

            Connections {
                target: row.net
                function onConnectionFailed(reason) {
                    const wrongKey = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed;
                    root.fail(row.net.name, wrongKey ? "Wrong password, or the network refused the connection" : "Couldn't connect");
                    root.expanded = row.net.name;
                }
                function onConnectedChanged() {
                    if (row.net.connected) {
                        root.clearFailure(row.net.name);
                        password.text = "";
                    }
                }
            }

            // Password entry for new secured networks.
            RowLayout {
                Layout.fillWidth: true
                visible: !row.net.known && row.secured
                spacing: 8
                TextField {
                    id: password
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                    color: Theme.text
                    placeholderTextColor: Theme.dim
                    selectionColor: Theme.violet
                    selectedTextColor: Theme.violetInk
                    font.family: Theme.sans
                    font.pixelSize: 12
                    leftPadding: 12
                    rightPadding: 34
                    background: Rectangle {
                        implicitHeight: 32
                        radius: 10
                        color: Theme.glassStrong
                        border.color: password.activeFocus ? Theme.violet : Theme.lineStrong
                    }
                    onAccepted: row.connect()
                    Glyph {
                        id: reveal
                        property bool checked: false
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: checked ? "󰈈" : "󰈉"
                        size: 14
                        color: Theme.muted
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: reveal.checked = !reveal.checked
                        }
                    }
                }
                PillButton {
                    text: "Connect"
                    primary: true
                    available: password.text !== "" && !row.connecting
                    onClicked: row.connect()
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: row.net.known || row.net.connected || !row.secured
                spacing: 6
                PillButton {
                    visible: !row.net.connected
                    text: row.connecting ? "Connecting…" : "Connect"
                    primary: true
                    available: !row.connecting
                    onClicked: row.connect()
                }
                PillButton {
                    visible: row.net.connected
                    text: "Disconnect"
                    onClicked: row.net.disconnect()
                }
                PillButton {
                    visible: row.net.known
                    text: "Forget"
                    danger: true
                    onClicked: { row.net.forget(); root.expanded = ""; }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.device || !Networking.wifiEnabled
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰤭"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.device ? "This computer has no Wi-Fi adapter" : "Wi-Fi is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        text: "Advanced network settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("nm-connection-editor"); }
        }
    }
}
