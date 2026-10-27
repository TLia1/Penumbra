pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "sun.js" as Sun

// Night light: hyprsunset warms the screen. It is turned on by hand, or by a schedule (fixed
// times, or sunset to sunrise where you are), and fades between warm and neutral rather than
// jumping. The choices are in Settings (shell.json); a toggle by hand lasts until the schedule
// next turns it on or off.
Singleton {
    id: root

    readonly property bool available: Ui.hasNightLight
    property bool on: false
    readonly property int temperature: Settings.nightTemperature
    readonly property int neutral: 6500
    readonly property string schedule: Settings.nightSchedule // manual, times or sun

    function toggle() {
        on = !on;
        fade(0);
    }

    // ── Where you are, for sunset and sunrise ───────────────────────
    // zone1970.tab lists a city with coordinates for every time zone, so a typed city is found
    // without a network lookup; with nothing typed, this computer's time zone stands in.
    property var cities: [] // [{ name: "New York", zone: "America/New_York", latitude, longitude }]
    property string timeZone: ""
    FileView {
        path: "/usr/share/zoneinfo/zone1970.tab"
        printErrors: false
        onLoaded: {
            const found = [];
            for (const line of text().split("\n")) {
                const fields = line.split("\t");
                if (line.startsWith("#") || fields.length < 3)
                    continue;
                const at = Sun.coordinates(fields[1]);
                if (at)
                    found.push(Object.assign({ name: fields[2].replace(/^.*\//, "").replace(/_/g, " "), zone: fields[2] }, at));
            }
            root.cities = found;
        }
    }
    Process {
        running: true
        command: ["readlink", "/etc/localtime"]
        stdout: StdioCollector {
            onStreamFinished: root.timeZone = text.trim().replace(/^.*zoneinfo\//, "")
        }
    }
    // A typed place → { name, latitude, longitude }, or null when it means nothing.
    function locate(text) {
        const typed = text.trim();
        if (typed === "")
            return cities.find(c => c.zone === timeZone) ?? null;
        const m = /^(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)$/.exec(typed);
        if (m) {
            const latitude = Number(m[1]), longitude = Number(m[2]);
            return Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180 ? { name: `${latitude}, ${longitude}`, latitude, longitude } : null;
        }
        const name = typed.toLowerCase();
        return cities.find(c => c.name.toLowerCase() === name) ?? cities.find(c => c.name.toLowerCase().startsWith(name)) ?? null;
    }
    readonly property var place: locate(Settings.nightPlace)

    // ── The schedule ────────────────────────────────────────────────
    // Today's on and off times in minutes after midnight, or null (manual, or no sunset today).
    readonly property var window: {
        if (schedule === "times") {
            const from = Sun.minutes(Settings.nightFrom), to = Sun.minutes(Settings.nightTo);
            return from >= 0 && to >= 0 && from !== to ? { from, to } : null;
        }
        if (schedule === "sun" && place) {
            const t = Sun.times(Clock.date, place.latitude, place.longitude);
            if (t.polar)
                return { polar: t.polar };
            return { from: t.set, to: t.rise };
        }
        return null;
    }
    readonly property bool scheduledOn: {
        if (!window)
            return false;
        if (window.polar)
            return window.polar === "night";
        return Sun.between(Clock.date.getHours() * 60 + Clock.date.getMinutes(), window.from, window.to);
    }
    // The next change the schedule makes, for the status line: "On until 07:12".
    readonly property string status: {
        if (!available)
            return "Needs hyprsunset";
        const state = on ? `On · ${temperature} K` : "Off";
        if (!window || window.polar)
            return state;
        return `${on ? "On" : "Off"} until ${Sun.clock(on ? window.to : window.from)}`;
    }
    // The schedule turning on or off (each minute is checked), or a change to its settings, wins
    // over a toggle by hand.
    property bool lastScheduled: false
    function followSchedule(slowly, changed) {
        if (schedule === "manual")
            return;
        const wanted = scheduledOn;
        if (!changed && wanted === lastScheduled)
            return;
        lastScheduled = wanted;
        if (on !== wanted) {
            on = wanted;
            fade(slowly ? 5 * 60 * 1000 : 0);
        }
    }
    Connections {
        target: Clock
        function onDateChanged() { root.followSchedule(true, false); }
    }
    Connections {
        target: Settings
        function onNightScheduleChanged() { root.followSchedule(false, true); }
        function onNightFromChanged() { root.followSchedule(false, true); }
        function onNightToChanged() { root.followSchedule(false, true); }
    }
    // A typed place, or the list of cities once it has loaded.
    onPlaceChanged: if (schedule === "sun") followSchedule(false, true)
    // Settings load just after the shell starts.
    Timer {
        interval: 1500
        running: true
        onTriggered: root.followSchedule(false, true)
    }
    // The slider moves in many small steps; send hyprsunset only where it stops.
    onTemperatureChanged: if (on) settle.restart()
    Timer {
        id: settle
        interval: 300
        onTriggered: if (root.on) root.fade(0)
    }

    // ── Applying it ─────────────────────────────────────────────────
    // hyprsunset runs while the screen is warm or fading, and takes each step over its IPC
    // (`hyprctl hyprsunset temperature N`); it leaves the colours alone when it stops.
    property int applied: neutral
    property int fadeFrom: neutral
    property int fadeTo: neutral
    property real fadeStart: 0
    property int fadeLength: 0
    readonly property bool fading: fader.running
    function fade(ms) {
        fadeFrom = applied;
        fadeTo = on ? temperature : neutral;
        fadeStart = Date.now();
        fadeLength = ms;
        // A change by hand is one step (Hyprland eases colour changes itself); a scheduled fade is
        // steps of 100 K at least ten seconds apart, since every step is a new colour transform
        // for the whole screen.
        fader.interval = ms > 0 ? Math.max(10000, ms / Math.max(1, Math.abs(fadeTo - fadeFrom) / 100)) : 100;
        fader.restart();
    }
    Timer {
        id: fader
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.available) {
                stop();
                return;
            }
            if (step.running)
                return;
            const t = root.fadeLength > 0 ? Math.min(1, (Date.now() - root.fadeStart) / root.fadeLength) : 1;
            const eased = t * t * (3 - 2 * t);
            const value = Math.round((root.fadeFrom + (root.fadeTo - root.fadeFrom) * eased) / 10) * 10;
            if (value !== root.applied && value < root.neutral && sunset.running) {
                step.value = value;
                step.command = ["hyprctl", "hyprsunset", "temperature", String(value)];
                step.running = true;
            } else if (value >= root.neutral) {
                root.applied = root.neutral;
            }
            if (t >= 1 && root.applied === root.fadeTo)
                stop();
        }
    }
    Process {
        id: sunset
        running: root.available && (root.on || root.applied < root.neutral || root.fading)
        command: ["hyprsunset", "--identity"]
    }
    Process {
        id: step
        property int value
        // hyprsunset takes a moment to listen after starting; a failed step is tried again.
        onExited: code => { if (code === 0) root.applied = value; }
    }
}
