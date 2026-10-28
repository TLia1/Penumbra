import QtQuick
import QtQuick.Layouts

// Keyboard layouts, their variants and XKB options, and Num Lock: settings.conf's, applied to
// Hyprland at once by penumbra-settings.
ColumnLayout {
    id: root

    spacing: 12
    onVisibleChanged: if (visible) Config.loadLayouts()

    // The comma-separated entry being typed in a field: its index and text.
    function token(field) {
        const before = field.text.slice(0, field.cursorPosition);
        return { index: before.split(",").length - 1, text: before.slice(before.lastIndexOf(",") + 1).trim().toLowerCase() };
    }
    function replaceToken(field, index, value) {
        const parts = field.text.split(",").map(p => p.trim());
        parts[index] = value;
        field.text = parts.join(",");
        field.cursorPosition = field.text.length;
    }

    // Up to five matches for what is being typed; a click puts one in.
    component Suggestions: ColumnLayout {
        id: suggestions
        property var field
        property var choices: [] // [[code, name]]
        readonly property var current: field.activeFocus ? root.token(field) : null
        readonly property var matches: !current || current.text === "" ? []
            : choices.filter(c => c[0].startsWith(current.text) || c[1].toLowerCase().includes(current.text))
                .sort((a, b) => (b[0] === current.text) - (a[0] === current.text) || (b[0].startsWith(current.text)) - (a[0].startsWith(current.text)))
                .slice(0, 5)
        Layout.fillWidth: true
        visible: matches.length > 0
        spacing: 0
        Repeater {
            model: suggestions.matches
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.radiusSmall
                color: pick.containsMouse ? Theme.raised : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Label { Layout.preferredWidth: 90; text: modelData[0]; font.family: Theme.mono; font.pixelSize: Theme.textSmall; color: Theme.accentBright }
                    Label { Layout.fillWidth: true; text: modelData[1]; font.pixelSize: Theme.textSmall; color: Theme.textSoft }
                }
                MouseArea {
                    id: pick
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.replaceToken(suggestions.field, suggestions.current.index, modelData[0]);
                        suggestions.field.forceActiveFocus();
                    }
                }
            }
        }
    }

    // A labelled text field, saved on Enter or when it loses focus.
    component SettingField: ColumnLayout {
        id: setting
        property string key
        property string title
        property alias field: input
        property alias placeholder: input.placeholderText
        Layout.fillWidth: true
        spacing: 6
        Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: setting.title }
        Field {
            id: input
            Layout.fillWidth: true
            text: Config.values[setting.key] ?? ""
            font.family: Theme.mono
            function save() {
                const value = text.split(",").map(p => p.trim()).join(",");
                if (value !== (Config.values[setting.key] ?? ""))
                    Config.set({ [setting.key]: value });
            }
            onAccepted: save()
            onEditingFinished: save()
            // Follow the saved value whenever this field isn't being edited.
            Connections {
                target: Config
                function onValuesChanged() {
                    if (!input.activeFocus)
                        input.text = Config.values[setting.key] ?? "";
                }
            }
        }
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Keyboard"
        status: Config.busy ? "Applying…" : "Changes apply as you press Enter"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    SettingField {
        id: layouts
        key: "kb_layout"
        title: "Layouts"
        placeholder: "us, or several: us,fr"
    }
    Suggestions {
        field: layouts.field
        choices: Config.layouts
    }
    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: (Config.values.kb_layout ?? "").includes(",")
        text: (Config.values.kb_layout ?? "").split(",").map(l => Config.layoutName(l)).join(" · ") + " · the bar's layout capsule switches between them"
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.muted
    }

    SettingField {
        id: variants
        key: "kb_variant"
        title: "Variants"
        placeholder: "None; one per layout, e.g. intl or ,dvorak"
    }
    Suggestions {
        field: variants.field
        // Variants of the layout in the same place in the list.
        choices: Config.variants[(Config.values.kb_layout ?? "").split(",")[root.token(variants.field).index] ?? ""] ?? []
    }

    SettingField {
        key: "kb_options"
        title: "Options"
        placeholder: "e.g. caps:escape,grp:alt_shift_toggle"
    }

    SwitchRow {
        glyph: "󰎠"
        title: "Num Lock at login"
        subtitle: "Applies from your next login"
        checked: Config.values.numlock === "on"
        onToggled: Config.set({ numlock: Config.values.numlock === "on" ? "off" : "on" })
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: Config.error !== ""
        text: Config.error
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.rose
    }
}
