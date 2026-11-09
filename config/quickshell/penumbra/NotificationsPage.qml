import QtQuick
import QtQuick.Layouts
import "sun.js" as Sun

// Notifications: when Do not disturb comes on by itself, sounds, the lock screen, and each app's rule.
ColumnLayout {
    id: root

    spacing: 12

    // Steps a "HH:MM" setting by a quarter of an hour.
    function shifted(text, quarters) {
        const m = Math.max(0, Sun.minutes(text));
        return Sun.clock(Math.round(m / 15) * 15 + 15 * quarters);
    }
    readonly property var ruleNames: ({ "silent": "No popups", "mute": "Muted", "keep": "Always kept" })
    readonly property var ruleApps: Object.keys(Settings.notificationRules).sort((a, b) => a.localeCompare(b))

    PageHeader {
        Layout.fillWidth: true
        title: "Notifications"
        status: Notifs.dnd ? "Do not disturb · " + Notifs.dndStatus.toLowerCase() : "Do not disturb is off"
        checked: Notifs.dnd
        onBack: Ui.controlPage = Ui.previousControlPage === "settings" ? "settings" : "main"
        onToggled: Notifs.toggleDnd()
    }

    Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Do not disturb by itself" }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        SwitchRow {
            glyph: "󰑊"
            title: "While sharing the screen"
            subtitle: "Recording or casting, so nothing private shows"
            checked: Settings.dndWhileSharing
            onToggled: Settings.dndWhileSharing = !Settings.dndWhileSharing
        }
        SwitchRow {
            glyph: "󰊓"
            title: "While a window is fullscreen"
            subtitle: "Videos, games and presentations"
            checked: Settings.dndFullscreen
            onToggled: Settings.dndFullscreen = !Settings.dndFullscreen
        }
        SwitchRow {
            glyph: "󰔛"
            title: "On a schedule"
            subtitle: Settings.dndSchedule ? `${Settings.dndFrom} to ${Settings.dndTo}` : "Every day at set times"
            checked: Settings.dndSchedule
            onToggled: Settings.dndSchedule = !Settings.dndSchedule
        }
        // Fixed times, a quarter of an hour at a time.
        Repeater {
            model: Settings.dndSchedule ? [
                { title: "From", glyph: "󰖔", key: "dndFrom" },
                { title: "Until", glyph: "󰖙", key: "dndTo" }
            ] : []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: 10
                spacing: 11
                Glyph { Layout.preferredWidth: 22; text: modelData.glyph; size: 17 }
                Label { Layout.fillWidth: true; text: modelData.title }
                Stepper {
                    text: Settings[modelData.key]
                    lessGlyph: "󰍴"
                    moreGlyph: "󰐕"
                    onDecreased: Settings[modelData.key] = root.shifted(Settings[modelData.key], -1)
                    onIncreased: Settings[modelData.key] = root.shifted(Settings[modelData.key], 1)
                }
            }
        }
    }

    Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Alerts" }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        SwitchRow {
            glyph: "󰂞"
            title: "Sounds"
            subtitle: "For new notifications; critical ones sound different"
            checked: Settings.notificationSounds
            onToggled: Settings.notificationSounds = !Settings.notificationSounds
        }
        SwitchRow {
            glyph: "󰌾"
            title: "Count on the lock screen"
            subtitle: "How many came in while locked, never what they say"
            checked: Settings.lockNotificationCount
            onToggled: Settings.lockNotificationCount = !Settings.lockNotificationCount
        }
    }

    Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Apps" }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: root.ruleApps
            delegate: RowLayout {
                id: app
                required property string modelData
                Layout.fillWidth: true
                Layout.leftMargin: 10
                spacing: 11
                Glyph { Layout.preferredWidth: 22; text: "󰂚"; size: 17 }
                Label { Layout.fillWidth: true; text: app.modelData; elide: Text.ElideRight }
                Segmented {
                    Layout.preferredWidth: 220
                    current: Settings.notificationRules[app.modelData] ?? ""
                    options: [
                        { value: "", title: "Normal" },
                        { value: "silent", title: "Quiet" },
                        { value: "mute", title: "Mute" },
                        { value: "keep", title: "Keep" }
                    ]
                    onChosen: value => Settings.setRule(app.modelData, value)
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: (root.ruleApps.length ? "" : "No app has a rule yet. ")
                + "The bell next to an app in the notification history sets one: Quiet keeps its notifications out of the popups, Mute drops them, Keep holds them past the history's limit of " + Notifs.limit + "."
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textSmall
            color: Theme.dim
        }
    }
}
