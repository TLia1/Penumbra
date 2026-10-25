import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// The polkit agent: when an app asks for administrator rights, a password card over the dimmed screen.
Scope {
    id: root

    readonly property var flow: agent.flow
    property bool shown: false
    property string error: ""

    PolkitAgent {
        id: agent
        onAuthenticationRequestStarted: {
            root.error = "";
            root.shown = true;
        }
    }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.error = "Wrong password";
            shake.restart();
        }
        function onIsCompletedChanged() {
            if (root.flow?.isCompleted)
                root.shown = false;
        }
    }
    onFlowChanged: {
        input.text = "";
        if (!flow)
            shown = false;
    }

    function submit() {
        if (flow && flow.isResponseRequired) {
            error = "";
            flow.submit(input.text);
            input.text = "";
        }
    }
    function cancel() {
        flow?.cancelAuthenticationRequest();
        shown = false;
    }

    PanelWindow {
        screen: Ui.screen
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        visible: root.shown || card.opacity > 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "penumbra-polkit"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.62)
            opacity: card.opacity
        }

        Shadow { target: card }
        Rectangle {
            id: card
            width: 420
            height: column.implicitHeight + 48
            anchors.centerIn: parent
            radius: Theme.radiusLarge
            color: Theme.glassStrong
            border.color: Theme.lineStrong
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.normal } }
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            GlassEdge { radius: card.radius }

            SequentialAnimation {
                id: shake
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 14; duration: 50 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -12; duration: 70 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 8; duration: 60 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }

            ColumnLayout {
                id: column
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 14

                RowLayout {
                    spacing: 14
                    Rectangle {
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: Theme.corner(24)
                        gradient: Gradient {
                            GradientStop { position: 0; color: Theme.violet }
                            GradientStop { position: 1; color: Theme.violetDeep }
                        }
                        Glyph { anchors.centerIn: parent; text: "󰒃"; size: 22; color: Theme.violetInk }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "A U T H E N T I C A T E"
                            font.pixelSize: Theme.textTiny
                            color: Theme.violet
                        }
                        Label {
                            Layout.fillWidth: true
                            text: "Administrator rights needed"
                            font.pixelSize: Theme.textLarge
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    wrapMode: Text.Wrap
                    color: Theme.textSoft
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.actionId ?? ""
                    font.family: Theme.mono
                    font.pixelSize: Theme.textTiny
                    color: Theme.dim
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 48
                    radius: Theme.corner(24)
                    color: Theme.raised
                    border.width: input.activeFocus ? 2 : 1
                    border.color: root.error ? Theme.rose : input.activeFocus ? Theme.violet : Theme.lineStrong
                    Behavior on border.color { ColorAnimation { duration: Theme.fast } }

                    TextInput {
                        id: input
                        anchors { fill: parent; leftMargin: 20; rightMargin: 44 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: Theme.textLarge
                        font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                        selectionColor: Theme.violetDeep
                        enabled: !!root.flow?.isResponseRequired
                        focus: root.shown
                        onVisibleChanged: if (visible) forceActiveFocus()
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.cancel()
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !input.text
                            text: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "") || "Password"
                            color: Theme.dim
                            font.pixelSize: Theme.textMedium
                        }
                    }
                    Glyph {
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        text: root.flow?.isResponseRequired === false ? "󰔟" : "󰌆"
                        size: 15
                        color: Theme.dim
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.error || (root.flow?.supplementaryMessage ?? "")
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.textBody
                    color: root.error || root.flow?.supplementaryIsError ? Theme.rose : Theme.muted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    PillButton {
                        text: "Cancel"
                        implicitHeight: 36
                        implicitWidth: 96
                        onClicked: root.cancel()
                    }
                    PillButton {
                        text: "Authenticate"
                        primary: true
                        implicitHeight: 36
                        implicitWidth: 124
                        available: !!root.flow?.isResponseRequired
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
