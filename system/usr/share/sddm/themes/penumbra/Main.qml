import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "palette.js" as P

// The sign-in screen. It is laid out like the shell's lock screen (the clock high in the centre,
// you and the password field below), so signing in and unlocking look like one place.
Rectangle {
 id: root
 width: 1280; height: 800; color: P.shade
 // Every size is designed for a 1280×800 screen and grows with larger ones.
 readonly property real u: Math.max(1, Math.min(width / 1280, height / 800))
 property date now: new Date()
 property bool busy: false
 property string error: ""
 function login() { if (!busy && username.text.length) { busy = true; error = ""; sddm.login(username.text, password.text, session.currentIndex); } }
 // #rrggbb with an alpha, as #aarrggbb.
 function alpha(color, a) { return "#" + ("0" + Math.round(a * 255).toString(16)).slice(-2) + color.slice(1); }

 Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop }
 // Darker toward the bottom, where the password field sits, as on the lock screen.
 Rectangle {
  anchors.fill: parent
  gradient: Gradient {
   GradientStop { position: 0; color: root.alpha(P.base, 0.25) }
   GradientStop { position: 0.55; color: root.alpha(P.base, 0.35) }
   GradientStop { position: 1; color: root.alpha(P.base, 0.78) }
  }
 }
 Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

 Item {
  id: content
  anchors.fill: parent
  opacity: 0
  Component.onCompleted: entrance.start()
  NumberAnimation { id: entrance; target: content; property: "opacity"; from: 0; to: 1; duration: 840; easing.type: Easing.OutCubic }

  // ── Clock ──
  ColumnLayout {
   anchors.horizontalCenter: parent.horizontalCenter
   y: Math.round(parent.height * 0.2)
   spacing: 0
   Text {
    Layout.alignment: Qt.AlignHCenter
    text: Qt.formatTime(root.now, "HH:mm")
    color: P.text; font.family: "Inter Display"; font.weight: Font.Light; font.pixelSize: 112 * root.u; font.letterSpacing: -1
    font.features: { "tnum": 1 }
   }
   Text {
    Layout.alignment: Qt.AlignHCenter
    text: Qt.formatDate(root.now, "dddd d MMMM")
    color: P.accent; font.family: "Inter"; font.pixelSize: 14 * root.u; font.letterSpacing: 3 * root.u; font.capitalization: Font.AllUppercase
   }
  }

  // ── You and your password ──
  ColumnLayout {
   anchors.horizontalCenter: parent.horizontalCenter
   y: Math.round(parent.height * 0.56)
   spacing: 14 * root.u

   // The initial of whoever signs in, on the violet disc the lock screen shows.
   Rectangle {
    Layout.alignment: Qt.AlignHCenter
    width: 76 * root.u; height: width; radius: width / 2
    border.width: 2; border.color: P.accent
    gradient: Gradient { GradientStop { position: 0; color: P.accent } GradientStop { position: 1; color: P.accentDeep } }
    Text {
     anchors.centerIn: parent
     text: username.text.charAt(0).toUpperCase()
     color: P.onAccent; font.family: "Inter Display"; font.bold: true; font.pixelSize: 30 * root.u
    }
   }
   TextField {
    id: username
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: 240 * root.u; implicitHeight: 34 * root.u
    text: userModel.lastUser; placeholderText: "Username"; horizontalAlignment: TextInput.AlignHCenter
    color: P.text; placeholderTextColor: P.muted; font.family: "Inter"; font.pixelSize: 15 * root.u; font.weight: Font.DemiBold
    background: Rectangle {
     radius: height / 2
     color: username.activeFocus || username.hovered ? root.alpha(P.surface, 0.7) : "transparent"
     border.color: username.activeFocus ? P.accent : "transparent"
    }
    onAccepted: password.forceActiveFocus()
   }
   TextField {
    id: password
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: 4 * root.u
    implicitWidth: 320 * root.u; implicitHeight: 52 * root.u
    placeholderText: "Password"; echoMode: TextInput.Password; passwordCharacter: "●"; horizontalAlignment: TextInput.AlignHCenter
    color: P.text; placeholderTextColor: P.muted; font.family: "Inter"; font.pixelSize: 15 * root.u
    leftPadding: rightPadding
    rightPadding: (layoutButton.visible ? layoutButton.width + 10 * root.u : 0) + 54 * root.u
    enabled: !root.busy
    background: Rectangle {
     radius: height / 2
     color: root.alpha(P.surface, 0.88)
     border.width: password.activeFocus ? 2 : 1
     border.color: root.error !== "" ? P.rose : password.activeFocus ? P.accent : root.alpha(P.accent, 0.34)
    }
    onAccepted: root.login()
    // With several keyboard layouts, the one the password is typed in; click to switch.
    Rectangle {
     id: layoutButton
     visible: keyboard.layouts.length > 1
     anchors.right: submit.left; anchors.rightMargin: 8 * root.u; anchors.verticalCenter: parent.verticalCenter
     width: layoutText.implicitWidth + 16 * root.u; height: 26 * root.u; radius: height / 2
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
    // Sign in.
    Rectangle {
     id: submit
     anchors.right: parent.right; anchors.rightMargin: 6 * root.u; anchors.verticalCenter: parent.verticalCenter
     width: 40 * root.u; height: width; radius: width / 2
     color: submitArea.containsMouse ? P.accentBright : P.accent
     opacity: root.busy ? 0.5 : 1
     Behavior on color { ColorAnimation { duration: 160 } }
     Text { anchors.centerIn: parent; text: "→"; color: P.onAccent; font.family: "Inter"; font.bold: true; font.pixelSize: 18 * root.u }
     MouseArea { id: submitArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
    }
   }
   // Signing in, a sign-in error, else a Caps Lock warning.
   Text {
    Layout.alignment: Qt.AlignHCenter
    Layout.minimumHeight: 16 * root.u
    text: root.busy ? "Signing in…" : root.error !== "" ? root.error : keyboard.capsLock ? "Caps Lock is on" : ""
    color: root.busy ? P.textSoft : root.error !== "" ? P.rose : P.amber
    font.family: "Inter"; font.pixelSize: 12 * root.u
   }
  }

  // ── Footer: the wordmark, the session, and power ──
  Text {
   anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 32 * root.u
   text: "PENUMBRA"
   color: root.alpha(P.accent, 0.8); font.family: "Inter"; font.pixelSize: 11 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 5 * root.u
  }
  RowLayout {
   anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 24 * root.u
   spacing: 6 * root.u
   ComboBox {
    id: session; implicitHeight: 34 * root.u; implicitWidth: 220 * root.u
    model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
    palette.button: P.raised; palette.buttonText: P.textSoft; palette.text: P.text; palette.base: P.raised; palette.highlight: P.selection; palette.highlightedText: P.selectionText; palette.window: P.surfaceAlt
    font.family: "Inter"; font.pixelSize: 12 * root.u
    background: Rectangle { color: session.hovered ? root.alpha(P.hover, 0.8) : root.alpha(P.surface, 0.6); radius: height / 2; border.color: root.alpha(P.accent, 0.16) }
   }
   Repeater {
    model: [
     { label: "Suspend", show: sddm.canSuspend, run: function() { sddm.suspend() } },
     { label: "Restart", show: true, run: function() { powerDialog.action = "restart"; powerDialog.open() } },
     { label: "Shut down", show: true, run: function() { powerDialog.action = "shutdown"; powerDialog.open() } }
    ]
    delegate: Rectangle {
     visible: modelData.show
     implicitWidth: powerText.implicitWidth + 28 * root.u; implicitHeight: 34 * root.u; radius: height / 2
     color: powerArea.containsMouse ? root.alpha(P.hover, 0.8) : "transparent"
     Text { id: powerText; anchors.centerIn: parent; text: modelData.label; color: powerArea.containsMouse ? P.text : P.muted; font.family: "Inter"; font.pixelSize: 12 * root.u }
     MouseArea { id: powerArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.run() }
    }
   }
  }
 }

 MouseArea { anchors.fill: parent; z: -1; onClicked: password.forceActiveFocus() }

 Dialog {
  id: powerDialog; property string action: ""; anchors.centerIn: parent; title: action === "restart" ? "Restart computer?" : "Shut down computer?"; modal: true
  standardButtons: Dialog.Ok | Dialog.Cancel; font.family: "Inter"; font.pixelSize: 13 * root.u
  palette.window: P.surfaceAlt; palette.windowText: P.text; palette.button: P.hover; palette.buttonText: P.accent
  onAccepted: { if (action === "restart") sddm.reboot(); else sddm.powerOff(); }
 }
 Connections {
  target: sddm
  function onLoginFailed() { root.busy = false; password.text = ""; root.error = "Sign-in failed. Please try again."; password.forceActiveFocus(); }
  function onLoginSucceeded() { root.error = ""; }
 }
 Component.onCompleted: { if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus(); }
}
