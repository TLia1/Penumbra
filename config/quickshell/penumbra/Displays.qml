pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Screens for Settings → Displays: what Hyprland has, a draft you change, and applying it. A draft
// is tried at once through `hyprctl eval`; unless you keep it within 15 seconds it is undone, in
// case the screen went dark. Only a kept draft is written to ~/.config/penumbra/monitors.lua
// (which hyprland.lua reads before user.lua), so a shell that dies during the trial leaves the
// file as it was and the next reload or login brings the old layout back.
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
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let all;
                try {
                    all = JSON.parse(text);
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
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitorremoved", "monitoraddedv2", "monitorremovedv2"].includes(event.name) && !root.changed)
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
    // Scales Hyprland takes for a mode: whole logical pixels, in 120ths (Wayland's fractional
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

    // The draft as Lua: one hl.monitor rule per screen.
    function lua(screens) {
        const quote = t => '"' + t.replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
        return screens.map(s => s.enabled
            ? `hl.monitor({ output = ${quote(s.key)}, mode = ${quote(s.mode)}, position = "${s.x}x${s.y}", scale = ${s.scale}, transform = ${s.transform} })`
            : `hl.monitor({ output = ${quote(s.key)}, disabled = true })`).join("\n");
    }
    readonly property string header: "-- Your screens, written by the Penumbra shell's Settings → Displays. hyprland.lua reads this\n"
        + "-- file before user.lua; change it there, or here by hand.\n"

    function apply() {
        if (!changed)
            return;
        evaluate(lua(draft));
        countdown = 15;
        timer.restart();
    }
    function keep() {
        timer.stop();
        countdown = 0;
        file.setText(header + lua(draft) + "\n");
        refresh();
    }
    function revert() {
        timer.stop();
        countdown = 0;
        // The file was never touched; only the screens need putting back.
        evaluate(lua(screens));
        draft = JSON.parse(JSON.stringify(screens));
        refresh();
    }
    function evaluate(text) {
        Quickshell.execDetached(["hyprctl", "eval", text]);
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
        id: file
        path: Quickshell.env("HOME") + "/.config/penumbra/monitors.lua"
        printErrors: false
    }
}
