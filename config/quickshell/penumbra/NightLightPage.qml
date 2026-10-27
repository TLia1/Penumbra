import QtQuick
import QtQuick.Layouts
import "sun.js" as Sun

// Night light: how warm, and when it comes on by itself.
ColumnLayout {
    id: root

    spacing: 12

    // Steps a "HH:MM" setting by a quarter of an hour.
    function shifted(text, quarters) {
        const m = Math.max(0, Sun.minutes(text));
        return Sun.clock(Math.round(m / 15) * 15 + 15 * quarters);
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Night light"
        status: NightLight.status
        checked: NightLight.on
        showSwitch: NightLight.available
        onBack: Ui.controlPage = "main"
        onToggled: NightLight.toggle()
    }

    Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Warmth" }
    SliderRow {
        Layout.fillWidth: true
        glyph: "󱩌"
        // Warmer to the right.
        from: 6000
        to: 2500
        stepSize: 100
        value: Settings.nightTemperature
        label: Settings.nightTemperature + " K"
        labelWidth: 48
        muted: !NightLight.on
        onMoved: v => Settings.nightTemperature = Math.round(v / 100) * 100
        onGlyphClicked: NightLight.toggle()
    }

    Overline { Layout.fillWidth: true; Layout.topMargin: 2; text: "Schedule" }
    Segmented {
        Layout.fillWidth: true
        current: Settings.nightSchedule
        options: [
            { value: "manual", title: "By hand" },
            { value: "times", title: "Set times" },
            { value: "sun", title: "Sunset to sunrise" }
        ]
        onChosen: value => Settings.nightSchedule = value
    }

    // Fixed times, a quarter of an hour at a time.
    ColumnLayout {
        Layout.fillWidth: true
        visible: Settings.nightSchedule === "times"
        spacing: 2
        Repeater {
            model: [
                { title: "Turns on", glyph: "󰖔", key: "nightFrom" },
                { title: "Turns off", glyph: "󰖙", key: "nightTo" }
            ]
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

    // Sunset and sunrise where you are: a city or coordinates, worked out on this computer.
    ColumnLayout {
        Layout.fillWidth: true
        visible: Settings.nightSchedule === "sun"
        spacing: 6
        Field {
            id: place
            Layout.fillWidth: true
            text: Settings.nightPlace
            placeholderText: NightLight.locate("")?.name ? `${NightLight.locate("").name} (your time zone) · or a city, or latitude, longitude` : "A city, or latitude, longitude"
            invalid: text.trim() !== "" && !NightLight.locate(text)
            onTextEdited: if (!invalid) Settings.nightPlace = text.trim()
            onEditingFinished: if (!invalid) Settings.nightPlace = text.trim()
        }
        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            readonly property var where: NightLight.place
            readonly property var sun: where ? Sun.times(Clock.date, where.latitude, where.longitude) : null
            text: place.invalid ? "No time zone city by that name; try a nearby large city, or latitude, longitude"
                : !where ? "Type a city, or latitude, longitude"
                : sun.polar === "day" ? `${where.name} · the sun doesn't set today`
                : sun.polar === "night" ? `${where.name} · the sun doesn't rise today`
                : `${where.name} · sunset ${Sun.clock(sun.set)}, sunrise ${Sun.clock(sun.rise)}`
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textSmall
            color: place.invalid ? Theme.rose : Theme.muted
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        visible: Settings.nightSchedule !== "manual"
        text: "It fades in and out over five minutes. Turning it on or off by hand lasts until the next change."
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
