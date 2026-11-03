import QtQuick
import QtQuick.Layouts
import "oklch.js" as Oklch

// Look: dark, light or auto, the accent colours (Penumbra's, your own or the wallpaper's) and the corner
// style, for the shell and the apps at once.
// Look and penumbra-theme apply a change; the shell fades to it.
ColumnLayout {
    id: root

    spacing: 12

    component Section: Overline {
        Layout.fillWidth: true
        Layout.topMargin: 2
    }

    // A choice drawn as a card: its picture above, its name below, the current one outlined.
    component Choice: Rectangle {
        id: choice
        property bool current
        property string title
        default property alias picture: holder.data
        signal picked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1 // equal shares
        implicitHeight: 118
        radius: Theme.radius
        color: current ? Theme.alpha(Theme.accent, 0.12) : choiceArea.containsMouse ? Theme.hover : Theme.raised
        border.width: current ? 2 : 1
        border.color: current ? Theme.accent : Theme.line
        Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.fast } }

        Item {
            id: holder
            anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
            width: 116
            height: 62
        }
        RowLayout {
            anchors { bottom: parent.bottom; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
            spacing: 6
            Rectangle {
                visible: choice.current
                implicitWidth: 6
                implicitHeight: 6
                radius: Theme.corner(3)
                color: Theme.accent
            }
            Label {
                text: choice.title
                font.weight: choice.current ? Font.DemiBold : Font.Normal
                color: choice.current ? Theme.text : Theme.textSoft
            }
        }
        MouseArea {
            id: choiceArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!choice.current) choice.picked()
        }
    }

    // A line standing in for text in the previews.
    component Line: Rectangle {
        implicitHeight: 4
        radius: Theme.corner(height / 2)
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Look"
        status: Look.error || "Mode, colours and corners"
        showSwitch: false
        onBack: Ui.controlPage = "settings"
    }

    // A little desktop in the colours on screen: a bar, a window and a panel. They fade with the
    // shell, so it shows each change as it happens.
    Rectangle {
        id: desktop
        Layout.fillWidth: true
        implicitHeight: 150
        radius: Theme.radius
        color: Theme.base
        border.color: Theme.line
        clip: true

        // A faint wash of the accent, where a wallpaper would be.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Theme.alpha(Theme.accentDeep, Theme.light ? 0.16 : 0.32) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        // The bar: workspaces, the clock, the status capsule.
        Rectangle {
            id: bar
            x: 10
            y: 10
            width: parent.width - 20
            height: 18
            radius: Theme.corner(9)
            color: Theme.glassStrong
            border.color: Theme.line
            Row {
                anchors { left: parent.left; leftMargin: 7; verticalCenter: parent.verticalCenter }
                spacing: 4
                Line { width: 14; height: 6; color: Theme.accent }
                Line { width: 6; height: 6; color: Theme.dim }
                Line { width: 6; height: 6; color: Theme.dim }
            }
            Line { anchors.centerIn: parent; width: 28; color: Theme.textSoft }
            Row {
                anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                spacing: 4
                Line { width: 6; height: 6; color: Theme.muted }
                Line { width: 6; height: 6; color: Theme.muted }
                Line { width: 18; height: 6; color: Theme.textSoft }
            }
        }

        // A window: a title, some text, a primary and a plain button.
        Rectangle {
            x: 10
            y: bar.y + bar.height + 8
            width: parent.width - panel.width - 28
            height: parent.height - y - 10
            radius: Theme.corner(10)
            color: Theme.surface
            border.color: Theme.lineStrong
            Column {
                anchors { left: parent.left; top: parent.top; margins: 11 }
                spacing: 6
                Line { width: 64; height: 6; color: Theme.text }
                Line { width: 120; color: Theme.textSoft }
                Line { width: 96; color: Theme.muted }
                Line { width: 108; color: Theme.dim }
            }
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: 11 }
                spacing: 6
                Rectangle {
                    width: 46
                    height: 16
                    radius: Theme.corner(8)
                    color: Theme.accent
                    Line { anchors.centerIn: parent; width: 24; color: Theme.accentInk }
                }
                Rectangle {
                    width: 40
                    height: 16
                    radius: Theme.corner(8)
                    color: Theme.raised
                    border.color: Theme.line
                    Line { anchors.centerIn: parent; width: 20; color: Theme.textSoft }
                }
            }
        }

        // A panel: two tiles (one on), a slider.
        Rectangle {
            id: panel
            anchors { right: parent.right; rightMargin: 10 }
            y: bar.y + bar.height + 8
            width: 128
            height: parent.height - y - 10
            radius: Theme.corner(12)
            color: Theme.glassStrong
            border.color: Theme.line
            Row {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 9 }
                spacing: 6
                Repeater {
                    model: [true, false]
                    delegate: Rectangle {
                        required property bool modelData
                        width: (parent.width - 6) / 2
                        height: 34
                        radius: Theme.corner(8)
                        color: modelData ? Theme.alpha(Theme.accent, 0.22) : Theme.raised
                        border.color: modelData ? Theme.alpha(Theme.accentBright, 0.55) : Theme.line
                        Line { x: 7; y: 8; width: 8; height: 8; color: modelData ? Theme.accentBright : Theme.muted }
                        Line { x: 7; y: 22; width: 30; color: modelData ? Theme.text : Theme.textSoft }
                    }
                }
            }
            Line {
                id: track
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 16 }
                color: Theme.overlayStrong
                Line { width: parent.width * 0.6; color: Theme.accent }
                Rectangle {
                    x: parent.width * 0.6 - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: Theme.corner(5)
                    color: Theme.white
                    border.color: Theme.accent
                }
            }
        }
    }

    Section { text: "Curated palettes" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: Look.presets
            delegate: Choice {
                required property var modelData
                title: modelData.title
                current: Look.choice.preset === modelData.id
                onPicked: Look.set({ preset: modelData.id })
                Rectangle {
                    anchors.fill: parent
                    color: modelData.base
                    radius: Theme.radiusSmall
                    Image {
                        anchors.fill: parent
                        source: Ui.fileUrl(Ui.wallpapers + modelData.wallpaper + "-clean.png")
                        fillMode: Image.PreserveAspectCrop
                    }
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                        width: 50; height: 28
                        radius: Theme.radiusSmall
                        color: modelData.surface
                        border.color: modelData.accent
                        Label { anchors.centerIn: parent; text: "Aa"; color: modelData.accent; font.pixelSize: 16 }
                    }
                }
            }
        }
    }
    Label {
        Layout.fillWidth: true
        text: "A complete palette and matching wallpaper scene. Custom colours below clear the preset."
        wrapMode: Text.Wrap
        color: Theme.dim
        font.pixelSize: Theme.textSmall
    }

    Section { text: "Desktop composition" }
    Label {
        Layout.fillWidth: true
        text: "Signature: floating capsules, numbered workspaces and a clear desktop. Palette and text size stay yours."
        wrapMode: Text.Wrap
        color: Theme.textSoft
        font.pixelSize: Theme.textSmall
    }
    PillButton { text: "Apply signature layout"; onClicked: Settings.signatureComposition() }

    Section { text: "Bar style" }
    Segmented {
        Layout.fillWidth: true
        current: Settings.barStyle
        options: [{ value: "floating", title: "Capsules" }, { value: "island", title: "Island" }, { value: "framed", title: "Framed" }]
        onChosen: value => Settings.barStyle = value
    }
    Section { text: "Workspaces" }
    Segmented {
        Layout.fillWidth: true
        current: Settings.workspaceStyle
        options: [{ value: "pills", title: "Numbers" }, { value: "icons", title: "Numbers + icons" }, { value: "dots", title: "Dots" }]
        onChosen: value => Settings.workspaceStyle = value
    }
    Section { text: "Volume and brightness" }
    Segmented {
        Layout.fillWidth: true
        current: Settings.osdPosition
        options: [{ value: "bottom", title: "Bottom" }, { value: "top", title: "Top island" }]
        onChosen: value => Settings.osdPosition = value
    }
    Section { text: "Glass frost" }
    SliderRow {
        Layout.fillWidth: true
        glyph: "󰂓"
        from: -0.15; to: 0.28; stepSize: 0.01
        value: Settings.glassFrost
        label: Math.round((value + 0.15) / 0.43 * 100) + "%"
        onMoved: value => Settings.glassFrost = value
    }

    Section { text: "Mode" }
    Segmented {
        Layout.fillWidth: true
        current: Look.choice.mode
        options: [
            { value: "dark", title: "Dark", glyph: "󰖔" },
            { value: "light", title: "Light", glyph: "󰖙" },
            { value: "auto", title: "Auto", glyph: "󰔎" }
        ]
        // Auto starts from the time of day, so the screen changes now if it should.
        onChosen: value => Look.set(value === "auto" ? { mode: value, auto: Look.daylight } : { mode: value })
    }
    Label {
        Layout.fillWidth: true
        visible: Look.choice.mode === "auto"
        text: Look.autoStatus
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }

    Section { text: "Colours" }
    // Each card shows its accent family in the current mode.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { name: "default", title: "Default" },
                { name: "custom", title: "Custom" },
                { name: "wallpaper", title: "Wallpaper" }
            ]
            delegate: Choice {
                id: colours
                required property var modelData
                readonly property var swatches: Look.swatches(Look.mode, modelData.name, custom.hue, custom.vividness)
                current: Look.choice.colors === modelData.name
                title: modelData.title
                onPicked: Look.set({ colors: modelData.name })
                Row {
                    anchors.centerIn: parent
                    spacing: -10
                    Repeater {
                        model: colours.swatches
                        delegate: Rectangle {
                            required property color modelData
                            width: 34
                            height: 34
                            radius: Theme.corner(17)
                            color: modelData
                            border.width: 2
                            border.color: Theme.surface
                            Behavior on color { enabled: !Theme.fading; ColorAnimation { duration: Theme.slow } }
                        }
                    }
                }
            }
        }
    }

    // The custom accent: presets, the hue and vividness, an exact colour. A slider shows its colour in
    // the shell while it moves; the choice is saved and given to the apps once it rests.
    ColumnLayout {
        id: custom
        Layout.fillWidth: true
        visible: Look.choice.colors === "custom"
        spacing: 10

        // As the controls have them: while a slider moves, ahead of Look.choice.
        readonly property real hue: hueSlider.value
        readonly property real vividness: vividSlider.value
        // The accent a hue and vividness give in the current mode.
        function accentAt(hue, vividness) { return Look.swatches(Look.mode, "custom", hue, vividness)[1]; }
        readonly property color accent: accentAt(hue, vividness)

        readonly property var presets: [
            { hue: 297, vividness: 1 },    // violet
            { hue: 272, vividness: 1 },    // indigo
            { hue: 250, vividness: 1 },    // blue
            { hue: 192, vividness: 0.9 },  // teal
            { hue: 148, vividness: 0.85 }, // green
            { hue: 75, vividness: 1 },     // amber
            { hue: 12, vividness: 1 },     // rose
            { hue: null, vividness: 0 }    // mono, at the current hue
        ]
        function isCurrent(preset) {
            const turn = Math.abs(((hue - preset.hue) % 360 + 540) % 360 - 180);
            return Math.abs(vividness - preset.vividness) < 0.005 && (preset.hue === null || turn < 0.5);
        }

        // A slider moved: show it now, apply it once both sliders rest (released, or no key pressed for a moment).
        function moved() {
            Look.preview({ hue: Math.round(hue), vividness: vividness.toFixed(2) });
            settle.restart();
        }
        Timer {
            id: settle
            interval: 400
            onTriggered: {
                if (hueSlider.pressed || vividSlider.pressed)
                    return; // the release starts it again
                const changes = { hue: Math.round(custom.hue), vividness: Number(custom.vividness.toFixed(2)) };
                if (changes.hue !== Math.round(Look.choice.hue) || changes.vividness !== Number(Look.choice.vividness.toFixed(2)))
                    Look.set(changes);
            }
        }

        // An exact colour's hue and vividness; the lightness stays the mode's, so text still reads on it.
        function useHex(text) {
            const lch = Oklch.fromHex(text);
            if (!lch)
                return false;
            const chroma = Look.accents[Look.mode === "light" ? "light" : "dark"][1][1];
            Look.set({
                // A grey has no hue of its own; it keeps the current one.
                hue: lch[1] < 0.01 ? Math.round(Look.choice.hue) : Math.round(lch[2]) % 360,
                vividness: Number(Math.min(1.3, lch[1] / chroma).toFixed(2))
            });
            return true;
        }

        // Round chips spread from edge to edge.
        Item {
            Layout.fillWidth: true
            implicitHeight: 34
            Row {
                spacing: (parent.width - custom.presets.length * 34) / (custom.presets.length - 1)
                Repeater {
                    model: custom.presets
                    delegate: Swatch {
                        required property var modelData
                        readonly property real hue: modelData.hue ?? Math.round(custom.hue)
                        width: 34
                        height: 34
                        color: custom.accentAt(hue, modelData.vividness)
                        selected: custom.isCurrent(modelData)
                        onPicked: Look.set({ hue: hue, vividness: modelData.vividness })
                    }
                }
            }
        }

        // Each slider with its name before it and its value after; then the exact colour.
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 10
            rowSpacing: 4

            Label {
                Layout.preferredWidth: 64
                text: "Hue"
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
            ColorSlider {
                id: hueSlider
                Layout.fillWidth: true
                from: 0
                to: 360
                stepSize: 1
                value: Look.choice.hue
                // The rainbow stays readable even when the accent is nearly grey.
                colorAt: hue => custom.accentAt(hue, Math.max(custom.vividness, 0.5))
                onMoved: custom.moved()
                onPressedChanged: if (!pressed) settle.restart()
            }
            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(custom.hue) + "°"
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }

            Label {
                text: "Vividness"
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
            ColorSlider {
                id: vividSlider
                Layout.fillWidth: true
                from: 0
                to: 1.3
                stepSize: 0.01
                value: Look.choice.vividness
                colorAt: vividness => custom.accentAt(custom.hue, vividness)
                onMoved: custom.moved()
                onPressedChanged: if (!pressed) settle.restart()
            }
            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Math.round(custom.vividness * 100) + " %"
                font.pixelSize: Theme.textSmall
                color: Theme.muted
            }

            Label {
                text: "Colour"
                font.pixelSize: Theme.textSmall
                color: Theme.textSoft
            }
            Field {
                id: hexField
                Layout.fillWidth: true
                Layout.columnSpan: 2
                placeholderText: "#rrggbb"
                font.family: Theme.mono
                invalid: text !== "" && !Oklch.fromHex(text)
                // Shows the accent unless you are typing one; Enter or leaving the box uses it.
                function reset() { text = custom.accent.toString(); }
                Component.onCompleted: reset()
                onAccepted: {
                    if (invalid)
                        return;
                    apply();
                    reset();
                    focus = false;
                }
                onActiveFocusChanged: if (!activeFocus && !apply()) reset()
                // Uses the colour typed, if it is one and new; true if it did.
                function apply() { return text.toLowerCase() !== custom.accent.toString() && custom.useHex(text); }
                Connections {
                    target: custom
                    function onAccentChanged() { if (!hexField.activeFocus) hexField.reset(); }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: "A colour you type gives its hue and vividness; the lightness stays the mode's, so text keeps reading on it"
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textSmall
            color: Theme.dim
        }
    }

    // The wallpaper's accents, the strongest first. penumbra-wallpaper hands a new wallpaper to
    // penumbra-theme, which finds its own and fades the shell to the strongest as it grows in.
    ColumnLayout {
        Layout.fillWidth: true
        visible: Look.choice.colors === "wallpaper"
        spacing: 10

        Row {
            visible: Look.candidates.length > 0
            spacing: 8
            Repeater {
                model: Look.candidates
                delegate: Swatch {
                    required property var modelData
                    required property int index
                    width: 34
                    height: 34
                    color: Look.swatches(Look.mode, "custom", modelData.hue, modelData.vividness)[1]
                    selected: index === Math.min(Look.choice.pick ?? 0, Look.candidates.length - 1)
                    onPicked: Look.set({ pick: index })
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: Look.candidates.length
                ? "Found in " + Ui.wallpaperTitle(Ui.wallpaper) + (Look.candidates.length > 1 ? ", the strongest first" : "")
                    + "; a new wallpaper brings its own colours as it grows in"
                : "No colours could be read from this wallpaper, so the default ones show"
            wrapMode: Text.Wrap
            font.pixelSize: Theme.textSmall
            color: Theme.dim
        }
    }

    // Custom and wallpaper accents can pull the signal colours (red, green, amber…) a little toward
    // themselves, so they sit together; they keep their meaning.
    SwitchRow {
        visible: Look.choice.colors !== "default"
        glyph: "󰢵"
        title: "Blend signal colours"
        subtitle: "Red, green, amber and blue lean a little toward the accent"
        checked: Look.choice.harmonize === true
        onToggled: Look.set({ harmonize: !(Look.choice.harmonize === true) })
    }

    Section { text: "Desktop depth" }
    SwitchRow {
        title: "Depth clock"
        subtitle: "Time behind Dawn, Eclipse or a custom foreground mask"
        glyph: "󰥔"
        checked: Settings.desktopClock
        onToggled: Settings.desktopClock = !Settings.desktopClock
    }
    SwitchRow {
        title: "Audio aura"
        subtitle: "Dawn’s ring and Eclipse’s horizon aurora react to music"
        glyph: "󰝚"
        checked: Settings.desktopAura
        onToggled: Settings.desktopAura = !Settings.desktopAura
    }
    Label {
        Layout.fillWidth: true
        text: "Choose Dawn or Eclipse in Wallpaper. The aura rests when wallpaper motion is paused."
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
    Section { text: "Calendar weather" }
    SwitchRow {
        title: "Show weather"
        subtitle: "Open-Meteo · " + (Weather.place?.name ?? "Choose a weather location")
        glyph: "󰖐"
        checked: Settings.weatherEnabled
        onToggled: Settings.weatherEnabled = !Settings.weatherEnabled
    }
    SwitchRow {
        visible: Settings.weatherEnabled
        title: "Weather beside the clock"
        subtitle: "Temperature and sky conditions in the bar"
        glyph: "󰖐"
        checked: Settings.weatherInBar
        onToggled: Settings.weatherInBar = !Settings.weatherInBar
    }
    PillButton { text: "Choose location"; onClicked: Ui.controlPage = "weather" }
    Section { text: "Floating dock" }
    Segmented {
        Layout.fillWidth: true
        current: Settings.dockMode
        options: [{ value: "off", title: "Off" }, { value: "auto", title: "Auto-hide" }, { value: "empty", title: "Empty workspace" }]
        onChosen: value => Settings.dockMode = value
    }
    Label {
        Layout.fillWidth: true
        text: "Hover the bottom edge to reveal. Right-click an app to pin or unpin; middle-click to open another window."
        wrapMode: Text.Wrap
        color: Theme.dim
        font.pixelSize: Theme.textSmall
    }
    Section { text: "Screen frame" }
    SwitchRow {
        title: "Join the bar to a screen frame"
        subtitle: "A thin bezel with curved inner corners around each display"
        glyph: "󰍹"
        checked: Settings.screenFrame
        onToggled: Settings.screenFrame = !Settings.screenFrame
    }

    Section { text: "Corners" }
    // Each card draws a little bar and window in its own style.
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: [
                { name: "rounded", title: "Rounded", round: true },
                { name: "sharp", title: "Sharp", round: false }
            ]
            delegate: Choice {
                id: corners
                required property var modelData
                readonly property color ink: current ? Theme.accent : Theme.lineStrong
                function r(px) { return modelData.round ? px : 0; }
                current: Theme.corners === modelData.name
                title: modelData.title
                onPicked: Ui.run(Ui.bin + "penumbra-corners " + modelData.name)
                Rectangle {
                    width: parent.width
                    height: 10
                    radius: corners.r(5)
                    color: Theme.glass
                    border.color: corners.ink
                    Rectangle { x: 4; y: 3; width: 14; height: 4; radius: corners.r(2); color: corners.ink }
                }
                Rectangle {
                    y: 16
                    width: parent.width
                    height: parent.height - y
                    radius: corners.r(9)
                    color: Theme.surface
                    border.color: corners.ink
                    Rectangle { x: 9; y: 10; width: 44; height: 5; radius: corners.r(2.5); color: corners.ink }
                    Rectangle { x: 9; y: 21; width: 70; height: 4; radius: corners.r(2); color: Theme.line }
                    Rectangle { x: 9; y: 30; width: 56; height: 4; radius: corners.r(2); color: Theme.line }
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        text: "The shell, windows, launcher and lock screen follow at once; open apps pick up some changes when they restart"
        wrapMode: Text.Wrap
        font.pixelSize: Theme.textSmall
        color: Theme.dim
    }
}
