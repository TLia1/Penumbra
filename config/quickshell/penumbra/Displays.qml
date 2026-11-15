pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Edit MangoWM output rules, with a 15-second trial before keeping changes.
Singleton {
    id: root

    // [{ key, name, label, modes: ["1920x1080@144.00"], mode, x, y, scale, transform, enabled }]
    property var screens: []
    property var draft: []
    readonly property bool changed: JSON.stringify(screens) !== JSON.stringify(draft)
    property int countdown: 0 // seconds left to keep an applied change

    function refresh() {
        if (!list.running)
            list.running = true;
    }
    Process {
        id: list
        command: ["mmsg", "get", "all-monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                let all;
                try {
                    const firstLine = text.split("\n").find(l => l.trim().startsWith("{")) ?? "{}";
                    const raw = JSON.parse(firstLine).monitors ?? [];
                    const trMap = { normal: 0, "90": 1, "180": 2, "270": 3 };
                    all = raw.map(m => {
                        const scale = m.scale > 0 ? m.scale : 1;
                        const tr = trMap[String(m.transform ?? "normal")] ?? 0;
                        const turned = tr % 2 === 1;
                        const w = Math.round((turned ? m.height : m.width) * scale);
                        const h = Math.round((turned ? m.width : m.height) * scale);
                        return {
                            name: m.name,
                            description: m.name,
                            make: "",
                            model: m.name,
                            width: w,
                            height: h,
                            refreshRate: 60,
                            availableModes: [`${w}x${h}@60.00Hz`],
                            x: m.x ?? 0,
                            y: m.y ?? 0,
                            scale,
                            transform: tr,
                            disabled: false
                        };
                    });
                } catch (e) {
                    return;
                }
                const descriptions = all.map(m => m.description);
                root.screens = all.map(m => {
                    // The model's description stays when the cable moves to another port; two of
                    // the same model (or none) fall back to the port.
                    const unique = m.description && descriptions.filter(d => d === m.description).length === 1;
                    const modes = [...new Set((m.availableModes ?? []).map(t => t.replace(/Hz$/, "")))];
                    // A screen that is off may report no mode of its own.
                    let mode = `${m.width}x${m.height}@${Number(m.refreshRate).toFixed(2)}`;
                    if (m.width > 0 && !modes.includes(mode))
                        modes.unshift(mode);
                    else if (m.width <= 0)
                        mode = modes[0] ?? "preferred";
                    return {
                        key: unique ? "desc:" + m.description : m.name,
                        name: m.name,
                        label: [m.make, m.model].filter(t => t && t !== "Unknown").join(" ") || m.name,
                        modes, mode,
                        x: m.x, y: m.y,
                        scale: m.scale > 0 ? Math.round(m.scale * 1000) / 1000 : 1,
                        transform: m.transform % 4,
                        enabled: !m.disabled
                    };
                });
                if (root.countdown === 0)
                    root.draft = JSON.parse(JSON.stringify(root.screens));
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
    // The draft as MangoWM monitor_rule lines.
    function mangoConf(screens) {
        return screens.map(s => {
            if (!s.enabled)
                return `monitor_rule=name:^${s.name}$,disable:1`;
            const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s.mode);
            const modePart = m ? `,width:${m[1]},height:${m[2]},refresh:${m[3]}` : "";
            return `monitor_rule=name:^${s.name}$${modePart},x:${s.x},y:${s.y},scale:${s.scale},rr:${s.transform}`;
        }).join("\n");
    }
    readonly property string mangoHeader: "# Your screens, written by the Penumbra shell's Settings -> Displays. config.conf reads this\n"
        + "# file before settings.conf and user.conf.\n"

    function apply() {
        if (!changed)
            return;
        mangoFile.setText(mangoHeader + mangoConf(draft) + "\n");
        Quickshell.execDetached(["mmsg", "dispatch", "reload_config"]);
        countdown = 15;
        timer.restart();
    }
    function keep() {
        timer.stop();
        countdown = 0;
        refresh();
    }
    function revert() {
        timer.stop();
        countdown = 0;
        mangoFile.setText(mangoHeader + mangoConf(screens) + "\n");
        Quickshell.execDetached(["mmsg", "dispatch", "reload_config"]);
        draft = JSON.parse(JSON.stringify(screens));
        refresh();
    }
    Timer {
        id: timer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0)
                root.revert();
        }
    }
    FileView {
        id: mangoFile
        path: Quickshell.env("HOME") + "/.config/mango/monitors.conf"
        printErrors: false
    }
}
