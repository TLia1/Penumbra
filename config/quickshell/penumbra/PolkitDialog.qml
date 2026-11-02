import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland

// The polkit agent: when an app asks for administrator rights, a password card over the dimmed screen.
// When the system's polkit stack asks for a finger first (install.sh adds pam_fprintd to it once
// fprintd is installed), a fingerprint glyph pulses; a password typed meanwhile goes in as soon as
// the stack asks for it.
Scope {
    id: root

    readonly property var flow: agent.flow
    property bool shown: false
    property string error: ""
    // The fingerprint reader is waiting: pam_fprintd said so and nothing is asked for yet.
    readonly property bool fingerWaiting: !!flow && !flow.isResponseRequired && !flow.isCompleted
        && /finger|swipe/i.test(flow.supplementaryMessage ?? "") && !flow.supplementaryIsError
    // A password typed while the reader waited.
    property string queued: ""

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
        queued = "";
        if (!flow)
            shown = false;
    }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired && root.queued !== "") {
                root.flow.submit(root.queued);
                root.queued = "";
            }
        }
    }

    function submit() {
        if (flow && flow.isResponseRequired) {
            error = "";
            flow.submit(input.text);
            input.text = "";
        } else if (fingerWaiting && input.text !== "") {
            queued = input.text;
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
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 14; duration: 50 * Theme.motion }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -12; duration: 70 * Theme.motion }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 8; duration: 60 * Theme.motion }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 * Theme.motion }
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
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.accentDeep }
                        }
                        Glyph { anchors.centerIn: parent; text: "󰒃"; size: 22; color: Theme.onAccent }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: "A U T H E N T I C A T E"
                            font.pixelSize: Theme.textTiny
                            color: Theme.accent
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
                    border.color: root.error ? Theme.rose : input.activeFocus ? Theme.accent : Theme.lineStrong
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
                        selectionColor: Theme.accentDeep
                        enabled: !!root.flow?.isResponseRequired || root.fingerWaiting
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
                        property real pulse: 1
                        anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                        text: root.fingerWaiting ? "󰈷" : root.flow?.isResponseRequired === false ? "󰔟" : "󰌆"
                        size: root.fingerWaiting ? 18 : 15
                        color: root.fingerWaiting ? Theme.accentBright : Theme.dim
                        opacity: root.fingerWaiting ? pulse : 1
                        SequentialAnimation on pulse {
                            running: root.fingerWaiting && !Theme.reducedMotion
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.error || (root.queued !== "" ? "Your password goes in once the reader gives up" : root.fingerWaiting ? "Touch the fingerprint reader, or type your password" : root.flow?.supplementaryMessage ?? "")
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
                        available: !!root.flow?.isResponseRequired || root.fingerWaiting && input.text !== ""
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
