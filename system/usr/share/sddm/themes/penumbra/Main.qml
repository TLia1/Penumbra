import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "palette.js" as P

Rectangle {
 id: root
 width: 1280; height: 800; color: P.shade
 // Every size is designed for a 1280×800 screen and grows with larger ones.
 readonly property real u: Math.max(1, Math.min(width / 1280, height / 800))
 property string clockText: Qt.formatTime(new Date(), "HH:mm")
 property bool busy: false
 function login() { if (!busy && username.text.length) { busy = true; status.text = "Signing in…"; sddm.login(username.text, password.text, session.currentIndex); } }
 // #rrggbb with an alpha, as #aarrggbb.
 function alpha(color, a) { return "#" + ("0" + Math.round(a * 255).toString(16)).slice(-2) + color.slice(1); }
 Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop }
 Rectangle { anchors.fill: parent; color: root.alpha(P.shade, 0.12) }
 Timer { interval: 1000; repeat: true; running: true; onTriggered: root.clockText = Qt.formatTime(new Date(), "HH:mm") }
 Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 46 * root.u; text: root.clockText; color: P.text; font.family: "Inter"; font.pixelSize: 36 * root.u }
 Rectangle {
  id: card
  width: 380 * root.u; height: column.implicitHeight + 87 * root.u; x: Math.max(36, parent.width * 0.09); anchors.verticalCenter: parent.verticalCenter
  radius: 24 * root.u; color: root.alpha(P.surface, 0.93); border.color: P.light; border.width: 1
  opacity: 0
  Component.onCompleted: entrance.start()
  NumberAnimation { id: entrance; target: card; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
  Rectangle { width: 42 * root.u; height: 3 * root.u; radius: 2; x: 32 * root.u; y: 32 * root.u; color: P.violet
   SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation {to: 0.4; duration: 2200} NumberAnimation {to: 1; duration: 2200} }
  }
  ColumnLayout {
   id: column
   anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
   anchors.margins: 32 * root.u; anchors.topMargin: 55 * root.u; spacing: 14 * root.u
   Text { text: "P E N U M B R A"; color: P.violet; font.family: "Inter"; font.pixelSize: 11 * root.u; font.bold: true }
   Text { text: "Welcome back."; color: P.text; font.family: "Inter"; font.pixelSize: 28 * root.u; Layout.topMargin: 6 * root.u }
   Text { text: "Your space, after dark."; color: P.muted; font.family: "Inter"; font.pixelSize: 12 * root.u; Layout.bottomMargin: 10 * root.u }
   TextField {
    id: username; Layout.fillWidth: true; implicitHeight: 46 * root.u; text: userModel.lastUser; placeholderText: "Username"
    color: P.text; placeholderTextColor: P.muted; font.family: "Inter"; font.pixelSize: 14 * root.u; leftPadding: 14 * root.u
    background: Rectangle {color: P.raised; radius: 10 * root.u; border.color: username.activeFocus ? P.violet : P.border}
    onAccepted: password.forceActiveFocus()
   }
   TextField {
    id: password; Layout.fillWidth: true; implicitHeight: 46 * root.u; placeholderText: "Password"; echoMode: TextInput.Password
    color: P.text; placeholderTextColor: P.muted; font.family: "Inter"; font.pixelSize: 14 * root.u; leftPadding: 14 * root.u
    rightPadding: layoutButton.visible ? layoutButton.width + 10 * root.u : 14 * root.u
    background: Rectangle {color: P.raised; radius: 10 * root.u; border.color: password.activeFocus ? P.violet : P.border}
    onAccepted: root.login()
    // With several keyboard layouts, the one the password is typed in; click to switch.
    Rectangle {
     id: layoutButton
     visible: keyboard.layouts.length > 1
     anchors.right: parent.right; anchors.rightMargin: 8 * root.u; anchors.verticalCenter: parent.verticalCenter
     width: layoutText.implicitWidth + 16 * root.u; height: 26 * root.u; radius: 6 * root.u
     color: layoutArea.containsMouse ? P.hover : "transparent"; border.color: P.border
     Text {
      id: layoutText; anchors.centerIn: parent
      text: (keyboard.layouts[keyboard.currentLayout] ? keyboard.layouts[keyboard.currentLayout].shortName : "").toUpperCase()
      color: P.textSoft; font.family: "Inter"; font.pixelSize: 11 * root.u; font.bold: true
     }
     MouseArea {
      id: layoutArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length; password.forceActiveFocus(); }
     }
    }
   }
   ComboBox {
    id: session; Layout.fillWidth: true; implicitHeight: 38 * root.u; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
    palette.button: P.raised; palette.buttonText: P.textSoft; palette.text: P.text; palette.base: P.raised; palette.highlight: P.selection; palette.highlightedText: P.selectionText; font.family: "Inter"; font.pixelSize: 11 * root.u
    background: Rectangle {color: P.raised; radius: 8 * root.u; border.color: P.border}
   }
   Button {
    Layout.fillWidth: true; implicitHeight: 46 * root.u; text: root.busy ? "Signing in…" : "Sign in  →"; enabled: !root.busy
    contentItem: Text {text: parent.text; color: P.violetInk; font.family: "Inter"; font.pixelSize: 14 * root.u; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter}
    background: Rectangle {color: parent.hovered ? P.violetBright : P.violet; radius: 10 * root.u; Behavior on color { ColorAnimation {duration: 160} }}
    onClicked: root.login()
   }
   // Sign-in errors, else a Caps Lock warning.
   Text {
    id: status; text: ""; color: P.rose; font.family: "Inter"; font.pixelSize: 11 * root.u; Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.minimumHeight: 16 * root.u
    visible: text !== ""
   }
   Text {
    visible: status.text === ""; text: keyboard.capsLock ? "Caps Lock is on" : ""
    color: P.amber; font.family: "Inter"; font.pixelSize: 11 * root.u; Layout.fillWidth: true; Layout.minimumHeight: 16 * root.u
   }
   RowLayout {
    Layout.alignment: Qt.AlignHCenter; spacing: 22 * root.u
    Button { visible: sddm.canSuspend; text: "Suspend"; flat: true; palette.buttonText: P.muted; font.family: "Inter"; font.pixelSize: 12 * root.u; onClicked: sddm.suspend() }
    Button { text: "Restart"; flat: true; palette.buttonText: P.muted; font.family: "Inter"; font.pixelSize: 12 * root.u; onClicked: {powerDialog.action = "restart"; powerDialog.open()} }
    Button { text: "Shut down"; flat: true; palette.buttonText: P.muted; font.family: "Inter"; font.pixelSize: 12 * root.u; onClicked: {powerDialog.action = "shutdown"; powerDialog.open()} }
   }
  }
 }
 Dialog {
  id: powerDialog; property string action: ""; anchors.centerIn: parent; title: action === "restart" ? "Restart computer?" : "Shut down computer?"; modal: true
  standardButtons: Dialog.Ok | Dialog.Cancel; font.pixelSize: 13 * root.u
  palette.window: P.surfaceAlt; palette.windowText: P.text; palette.button: P.hover; palette.buttonText: P.violet
  onAccepted: { if (action === "restart") sddm.reboot(); else sddm.powerOff(); }
 }
 Connections {
  target: sddm
  function onLoginFailed() { root.busy = false; password.text = ""; status.text = "Sign-in failed. Please try again."; password.forceActiveFocus(); }
  function onLoginSucceeded() { status.text = ""; }
 }
 Component.onCompleted: { if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus(); }
}
