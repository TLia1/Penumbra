import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
 id: root
 width: 1280; height: 800; color: "#08070d"
 property string clockText: Qt.formatTime(new Date(), "HH:mm")
 property bool busy: false
 function login() { if (!busy && username.text.length) { busy = true; status.text = "Signing in…"; sddm.login(username.text, password.text, session.currentIndex); } }
 Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop }
 Rectangle { anchors.fill: parent; color: "#2008070d" }
 Timer { interval: 1000; repeat: true; running: true; onTriggered: root.clockText = Qt.formatTime(new Date(), "HH:mm") }
 Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 46; text: root.clockText; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 36 }
 Rectangle {
  id: card
  width: 380; height: 500; x: Math.max(36, parent.width * 0.09); anchors.verticalCenter: parent.verticalCenter
  radius: 24; color: "#ed100d18"; border.color: "#443253"; border.width: 1
  opacity: 0
  Component.onCompleted: entrance.start()
  NumberAnimation { id: entrance; target: card; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
  Rectangle { width: 42; height: 3; radius: 2; x: 32; y: 32; color: "#b69af7"
   SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation {to: 0.4; duration: 2200} NumberAnimation {to: 1; duration: 2200} }
  }
  ColumnLayout {
   anchors.fill: parent; anchors.margins: 32; anchors.topMargin: 55; spacing: 14
   Text { text: "N O C T U R N E"; color: "#b69af7"; font.family: "Inter"; font.pixelSize: 11; font.bold: true }
   Text { text: "Welcome back."; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 28; Layout.topMargin: 6 }
   Text { text: "Your space, after dark."; color: "#8f809f"; font.family: "Inter"; font.pixelSize: 12; Layout.bottomMargin: 10 }
   TextField {
    id: username; Layout.fillWidth: true; implicitHeight: 46; text: userModel.lastUser; placeholderText: "Username"
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: username.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: password.forceActiveFocus()
   }
   TextField {
    id: password; Layout.fillWidth: true; implicitHeight: 46; placeholderText: "Password"; echoMode: TextInput.Password
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: password.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: root.login()
   }
   ComboBox {
    id: session; Layout.fillWidth: true; implicitHeight: 38; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
    palette.button: "#1c1528"; palette.buttonText: "#b9abc9"; palette.text: "#e9e1f5"; palette.base: "#1c1528"; palette.highlight: "#694797"; palette.highlightedText: "#ffffff"; font.family: "Inter"; font.pixelSize: 11
    background: Rectangle {color: "#1c1528"; radius: 8; border.color: "#33263f"}
   }
   Button {
    Layout.fillWidth: true; implicitHeight: 46; text: root.busy ? "Signing in…" : "Sign in  →"; enabled: !root.busy
    contentItem: Text {text: parent.text; color: "#100b1b"; font.family: "Inter"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter}
    background: Rectangle {color: parent.hovered ? "#cbb0ff" : "#b69af7"; radius: 10; Behavior on color { ColorAnimation {duration: 160} }}
    onClicked: root.login()
   }
   Text { id: status; text: ""; color: "#ef8fa4"; font.family: "Inter"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.minimumHeight: 16 }
   RowLayout {
    Layout.alignment: Qt.AlignHCenter; spacing: 22
    Button { text: "Restart"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "restart"; powerDialog.open()} }
    Button { text: "Shut down"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "shutdown"; powerDialog.open()} }
   }
  }
 }
 Dialog {
  id: powerDialog; property string action: ""; anchors.centerIn: parent; title: action === "restart" ? "Restart computer?" : "Shut down computer?"; modal: true
  standardButtons: Dialog.Ok | Dialog.Cancel
  palette.window: "#16111f"; palette.windowText: "#e9e1f5"; palette.button: "#292039"; palette.buttonText: "#b69af7"
  onAccepted: { if (action === "restart") sddm.reboot(); else sddm.powerOff(); }
 }
 Connections {
  target: sddm
  function onLoginFailed() { root.busy = false; password.text = ""; status.text = "Sign-in failed. Please try again."; password.forceActiveFocus(); }
  function onLoginSucceeded() { status.text = "Welcome."; }
 }
 Component.onCompleted: { if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus(); }
}
