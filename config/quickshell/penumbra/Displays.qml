pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Edit MangoWM output rules, with a 15-second trial before keeping changes.
Singleton {
    id: root

    property var screens: []
    property var draft: []
    readonly property bool changed: JSON.stringify(screens) !== JSON.stringify(draft)
    property int countdown: 0 // seconds left to keep an applied change

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/penumbra-displays"
    readonly property bool busy: trial.running
    property string error: ""
    property string readError: ""

    function refresh() {
        if (!list.running && !busy && !changed)
            list.running = true;
    }
    Process {
        id: list
        command: [root.helper, "list"]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: listError }
        onExited: code => {
            if (root.busy || root.changed) return;
            if (code !== 0) {
                root.readError = listError.text.trim() || "Couldn't read Mango's display modes.";
                return;
            }
            root.readError = "";
            const latest = JSON.parse(output.text);
            if (JSON.stringify(latest) !== JSON.stringify(root.screens)) {
                root.screens = latest;
                root.reset();
            }
        }
    }
    // Screens plugged in or out while nothing is being changed.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.changed && root.countdown === 0)
                root.refresh();
        }
    }

    function update(index, changes) {
        const next = JSON.parse(JSON.stringify(draft));
        Object.assign(next[index], changes);
        draft = next;
    }
    function reset() {
        draft = JSON.parse(JSON.stringify(screens));
    }

    // A mode's pixels, then the size the screen takes in the layout: rotated, divided by its scale.
    function pixels(mode) {
        const m = /^(\d+)x(\d+)/.exec(mode);
        return m ? { width: Number(m[1]), height: Number(m[2]) } : { width: 1920, height: 1080 };
    }
    function logical(s) {
        const p = pixels(s.mode), turned = s.transform % 2 === 1;
        return { width: Math.round((turned ? p.height : p.width) / s.scale), height: Math.round((turned ? p.width : p.height) / s.scale) };
    }
    // Suggest scales yielding whole logical pixels, in 120ths (Wayland's fractional
    // scale), and round enough to read: 1, 1.2, 1.25, 1.33, 1.5…
    function scales(s) {
        const p = pixels(s.mode), found = [];
        for (let k = 120; k <= 360; k++) {
            const whole = Number.isInteger(p.width * 120 / k) && Number.isInteger(p.height * 120 / k);
            if (whole && (k % 6 === 0 || k % 40 === 0))
                found.push(Math.round(k / 120 * 1000) / 1000);
        }
        if (!found.some(v => Math.abs(v - s.scale) < 0.001))
            found.push(s.scale);
        return found.sort((a, b) => a - b);
    }

    // Drop screen `index` near (x, y), in layout pixels: against the nearest edge of another
    // screen, lined up with its side when close, never overlapping. Then the arrangement moves so
    // its top-left corner is 0, 0.
    function place(index, x, y) {
        const me = logical(draft[index]);
        const others = draft.map((s, i) => ({ i, s, size: logical(s) })).filter(o => o.i !== index && o.s.enabled);
        let best = null;
        const overlaps = (cx, cy) => others.some(o => cx < o.s.x + o.size.width && cx + me.width > o.s.x && cy < o.s.y + o.size.height && cy + me.height > o.s.y);
        const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
        const align = (v, starts) => starts.reduce((b, t) => Math.abs(t - v) < Math.abs(b - v) && Math.abs(t - v) < 60 ? t : b, v);
        for (const o of others) {
            const ys = [o.s.y, o.s.y + o.size.height - me.height], xs = [o.s.x, o.s.x + o.size.width - me.width];
            const candidates = [
                { x: o.s.x - me.width, y: align(clamp(y, o.s.y - me.height, o.s.y + o.size.height), ys) },
                { x: o.s.x + o.size.width, y: align(clamp(y, o.s.y - me.height, o.s.y + o.size.height), ys) },
                { x: align(clamp(x, o.s.x - me.width, o.s.x + o.size.width), xs), y: o.s.y - me.height },
                { x: align(clamp(x, o.s.x - me.width, o.s.x + o.size.width), xs), y: o.s.y + o.size.height }
            ];
            for (const c of candidates) {
                const d = Math.hypot(c.x - x, c.y - y);
                if (!overlaps(c.x, c.y) && (!best || d < best.d))
                    best = { x: Math.round(c.x), y: Math.round(c.y), d };
            }
        }
        const next = JSON.parse(JSON.stringify(draft));
        if (best)
            Object.assign(next[index], { x: best.x, y: best.y });
        const shown = next.filter(s => s.enabled);
        const left = Math.min(...shown.map(s => s.x)), top = Math.min(...shown.map(s => s.y));
        for (const s of next) {
            s.x -= left;
            s.y -= top;
        }
        draft = next;
    }
    function apply() {
        if (!changed || busy) return;
        error = "";
        trial.command = [helper, "trial", JSON.stringify(draft), JSON.stringify(screens)];
        trial.running = true;
    }
    function keep() {
        if (countdown > 0) trial.write("keep\n");
    }
    function revert() {
        if (countdown > 0) trial.write("undo\n");
    }
    Process {
        id: trial
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                if (line === "ready") root.countdown = 15;
            }
        }
        stderr: StdioCollector { id: trialError }
        onExited: code => {
            root.countdown = 0;
            if (code !== 0)
                root.error = trialError.text.trim() || "Couldn't apply the display settings.";
            root.reset();
            Qt.callLater(root.refresh);
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.countdown > 0
        onTriggered: root.countdown = Math.max(0, root.countdown - 1)
    }
}
