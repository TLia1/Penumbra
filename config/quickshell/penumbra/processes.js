.pragma library

// The system monitor's process list: top's last sample, grouped into apps by systemd unit.
// Apps started by the shell, a launcher or an autostart file each run in their own scope or
// service under app.slice, so a unit is one app, all of its processes and nothing else. Processes
// in a unit shared by unrelated programs (the compositor's, a login session's) are grouped by
// executable within it, and interpreters and shells there one process at a time: ending "python3"
// must not end every Python script.

// Units that hold whatever was started from them rather than one app.
function shared(unit) {
    return /^(session-.*\.scope|init\.scope|user@\d+\.service|wayland-wm@.*\.service|.*\.slice)$/.test(unit);
}

// Programs that run something else, so their name says nothing about the app.
var interpreters = ["sh", "bash", "dash", "zsh", "fish", "python", "python3", "perl", "ruby", "node", "lua", "env"];
function interpreter(exe) {
    return interpreters.includes(exe) || /^python3\.\d+$/.test(exe);
}

// The desktop's own pieces: ending one would end the session, its lock screen or this list.
function guarded(unit, exe) {
    return unit.startsWith("penumbra-") || ["Hyprland", "quickshell", "systemd", "hypridle"].includes(exe);
}

// cgroups(text) → { pid: path } from `grep -H '' /proc/[0-9]*/cgroup`, which prints
// "/proc/PID/cgroup:0::/user.slice/…/app-firefox@1.scope" (cgroup v2's line is the "0::" one).
function cgroups(text) {
    const paths = {};
    for (const line of text.split("\n")) {
        const m = line.match(/^\/proc\/(\d+)\/cgroup:0::(.*)$/);
        if (m)
            paths[m[1]] = m[2];
    }
    return paths;
}

// The unit at the end of a cgroup path, and whether it is one of the user's own (so
// `systemctl --user` can signal it).
function unitOf(path) {
    const parts = (path ?? "").split("/").filter(p => p);
    const unit = parts.length ? parts[parts.length - 1] : "";
    return { unit: /\.(scope|service)$/.test(unit) ? unit : "", user: /\/user@\d+\.service\//.test(path ?? "") };
}

// The PID a scope was made by, when its name says so: systemd-run's run-pPID-iN.scope, or
// kitty-PID-N.scope (a terminal's tabs); 0 otherwise. Apps' own scopes (app-…) stand alone.
function parent(unit) {
    const m = unit.match(/^(?:run-p(\d+)-i\d+|(?!app-)[a-z][\w.]*-(\d+)-\d+)\.scope$/);
    return m ? Number(m[1] ?? m[2]) : 0;
}

// The desktop file ID in a unit named the XDG way, app-[LAUNCHER-]ID-RANDOM.scope or
// app-[LAUNCHER-]ID@RANDOM.service, with systemd's \x escapes undone; "" otherwise.
function appId(unit) {
    const m = unit.match(/^app-(.+?)(?:-[0-9a-f]+\.scope|@[^@]*\.service|\.service|\.scope)$/);
    return m ? m[1].replace(/\\x([0-9a-f]{2})/gi, (_, hex) => String.fromCharCode(parseInt(hex, 16))) : "";
}

// The program a command line runs; for an interpreter, its script ("python3 /x/penumbra-cast …"
// is penumbra-cast).
function program(command) {
    const words = command.split(" ").filter(w => w);
    const exe = (words[0] ?? "").split("/").pop().replace(/^-/, "").replace(/:$/, "");
    if (!interpreter(exe))
        return { exe, name: exe };
    const script = words.slice(1).find(w => !w.startsWith("-") && !w.includes("="));
    return { exe, name: script && exe !== "env" ? script.split("/").pop() : exe };
}

// RES is in KiB, but top shortens values too wide for the column (e.g. 10.2g).
function kib(value) {
    const scale = { m: 1024, g: 1048576, t: 1073741824 }[value.slice(-1)];
    return scale ? parseFloat(value) * scale : Number(value);
}

// group(top, cgroupText) → [{ key, units, exe, name, appId, cpu, mem, pids, user, guarded }]:
// one per app. `top` is `top -b -n 2 -c` output (only the last sample counts), the sampling itself
// left out. `units` lists the user units to signal when every process came from one, else is empty
// and the PIDs are signalled.
function group(top, cgroupText) {
    const lines = top.split("\n");
    let start = lines.length;
    for (let i = lines.length - 1; i >= 0; i--) {
        if (/^\s*PID\s+USER/.test(lines[i])) {
            start = i + 1;
            break;
        }
    }
    const paths = cgroups(cgroupText);
    const found = {};
    const keyOf = {}; // pid → key
    const made = {}; // key → the PID that made its scope
    for (const line of lines.slice(start)) {
        // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
        const m = line.match(/^\s*(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+\S+\s+\S\s+([\d.]+)\s+\S+\s+\S+\s+(.+)$/);
        if (!m || m[5].includes("top -b -n 2"))
            continue;
        const pid = m[1], command = m[5];
        let key, unit = "", userUnit = false, exe, name;
        if (command.startsWith("[")) {
            key = "kernel";
            exe = name = "kernel";
        } else {
            ({ exe, name } = program(command));
            if (!exe)
                continue;
            const u = unitOf(paths[pid]);
            if (u.unit && !shared(u.unit)) {
                key = u.unit;
                unit = u.unit;
                userUnit = u.user;
                if (parent(unit))
                    made[key] = parent(unit);
            } else {
                // Shared or unknown: by program within the unit, interpreters one by one.
                key = (interpreter(exe) ? `${name}#${pid}` : exe) + "@" + (u.unit || "?");
            }
        }
        if (!found[key])
            found[key] = { key, units: [], loose: false, exe: "", name: "", appId: appId(unit), cpu: 0, mem: 0, pids: [], user: m[2], guarded: false, lowest: Infinity };
        const g = found[key];
        keyOf[pid] = key;
        g.cpu += Number(m[4]);
        g.mem += kib(m[3]);
        g.pids.push(pid);
        if (g.user !== m[2])
            g.user = "";
        if (userUnit && !g.units.includes(unit))
            g.units.push(unit);
        else if (!userUnit)
            g.loose = true;
        g.guarded = g.guarded || guarded(unit, exe);
        // An app's name is its first program that is not a wrapper, else its first.
        const rank = Number(pid) + (interpreter(exe) ? 1e9 : 0);
        if (rank < g.lowest) {
            g.lowest = rank;
            g.exe = exe;
            g.name = name;
        }
    }
    // A scope an app made for its helpers is part of that app, unless the app is the desktop's
    // (the shell starts every app in a scope of its own: those stay apart).
    for (const key in made) {
        const into = found[keyOf[made[key]]];
        const from = found[key];
        if (!into || into === from || into.guarded || into.key === "kernel")
            continue;
        into.cpu += from.cpu;
        into.mem += from.mem;
        into.pids = into.pids.concat(from.pids);
        into.units = into.units.concat(from.units.filter(u => !into.units.includes(u)));
        into.loose = into.loose || from.loose;
        if (into.user !== from.user)
            into.user = "";
        into.guarded = into.guarded || from.guarded;
        delete found[key];
    }
    return Object.values(found).map(g => {
        if (g.loose)
            g.units = [];
        delete g.loose;
        delete g.lowest;
        return g;
    });
}
