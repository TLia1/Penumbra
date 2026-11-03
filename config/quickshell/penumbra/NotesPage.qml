import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 12
    PageHeader {
        Layout.fillWidth: true
        title: "Quick notes"
        status: Notes.error || (Notes.dirty ? "Saving…" : "Saved on this computer")
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 300
        radius: Theme.radius
        color: Theme.raised
        border.color: Theme.line
        ScrollView {
            anchors { fill: parent; margins: 12 }
            clip: true
            TextArea {
                enabled: Notes.ready
                text: Notes.draft
                placeholderText: "A thought to keep close…"
                wrapMode: TextEdit.Wrap
                color: Theme.text
                placeholderTextColor: Theme.dim
                selectionColor: Theme.accentDeep
                selectedTextColor: Theme.white
                font.family: Theme.sans
                font.pixelSize: Theme.textBody
                background: null
                onTextChanged: if (activeFocus && text !== Notes.draft) Notes.edit(text)
            }
        }
    }
    PillButton { visible: Notes.error !== ""; text: "Retry save"; onClicked: Notes.save() }
    Label {
        Layout.fillWidth: true
        text: "Local plain text · ~/.local/state/penumbra/notes.txt"
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
