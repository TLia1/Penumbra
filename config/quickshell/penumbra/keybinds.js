.pragma library

// Format the shortcuts from the compositor configuration.
function shortcut(bind) {
    const parts = [];
    for (const [mask, name] of [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"],
                              [2, "Caps Lock"], [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]]) {
        if ((bind.modmask || 0) & mask) parts.push(name);
    }
    const names = {
        Return: "Enter", space: "Space", comma: ",", semicolon: ";", Caps_Lock: "Caps Lock",
        Escape: "Esc", Page_Up: "Page Up", Page_Down: "Page Down", equal: "=", minus: "-",
        left: "←", right: "→", up: "↑", down: "↓",
        "mouse:272": "Left mouse", "mouse:273": "Right mouse", "mouse:274": "Middle mouse",
        mouse_down: "Scroll down", mouse_up: "Scroll up",
        XF86AudioRaiseVolume: "Volume up", XF86AudioLowerVolume: "Volume down",
        XF86AudioMute: "Audio mute", XF86AudioMicMute: "Microphone mute",
        XF86MonBrightnessUp: "Brightness up", XF86MonBrightnessDown: "Brightness down",
        XF86AudioPlay: "Media play", XF86AudioPause: "Media pause",
        XF86AudioNext: "Next track", XF86AudioPrev: "Previous track"
    };
    const code = Number(bind.keycode) || (String(bind.key || "").startsWith("code:") ? Number(bind.key.slice(5)) : 0);
    let key = names[bind.key] || bind.key || "Any key";
    if (code >= 10 && code <= 19) key = "Number row " + (code === 19 ? "0" : code - 9);
    else if (code === 49) key = "Key left of 1";
    else if (code) key = "Keycode " + code;
    parts.push(key);
    return parts.join(" + ");
}

function entries(data) {
    if (!Array.isArray(data)) throw new Error("Expected a list of bindings");
    return data.filter(b => b && b.enabled !== false).map(b => {
        const keys = shortcut(b);
        const action = b.description || [b.dispatcher, b.arg].filter(Boolean).join(" ") || "Custom binding (no description)";
        const details = [b.submap ? "Submap: " + b.submap : "", b.release ? "On release" : "",
            b.repeat || b.repeating ? "Repeats while held" : "", b.locked ? "Also while locked" : "",
            b.mouse ? "Drag" : "", b.longPress || b.long_press ? "Long press" : "",
            b.ignore_mods ? "Any modifiers" : ""].filter(Boolean).join(" · ");
        return { keys, action, details };
    });
}

function filter(entries, query) {
    const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    return entries.filter(b => words.every(w => (b.keys + " " + b.action + " " + b.details).toLowerCase().includes(w)));
}

// Parse MangoWM config.conf / user.conf bind lines into objects compatible with entries().
function parseMangoConfig(text) {
    if (typeof text !== "string")
        throw new Error("Expected MangoWM config text");
    const vars = {};
    const expand = s => s.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, k) => vars[k] ?? `\${${k}}`);
    const modBits = { super: 64, super_l: 64, super_r: 64, ctrl: 4, ctrl_l: 4, ctrl_r: 4, alt: 8, alt_l: 8, alt_r: 8, shift: 1, shift_l: 1, shift_r: 1, hyper: 32 };
    const mouseMap = { btn_left: "mouse:272", btn_right: "mouse:273", btn_middle: "mouse:274" };
    const axisMap = { down: "mouse_down", up: "mouse_up" };
    let submap = "";
    const list = [];

    for (const rawLine of text.split("\n")) {
        const trimmed = rawLine.trim();
        if (!trimmed || trimmed.startsWith("#"))
            continue;
        const commentIdx = trimmed.indexOf("#");
        const body = (commentIdx >= 0 ? trimmed.slice(0, commentIdx) : trimmed).trim();
        const description = commentIdx >= 0 ? trimmed.slice(commentIdx + 1).trim() : "";
        const eq = body.indexOf("=");
        if (eq < 0)
            continue;
        const keyword = body.slice(0, eq).trim();
        const value = expand(body.slice(eq + 1).trim());
        if (keyword === "var") {
            const comma = value.indexOf(",");
            if (comma > 0)
                vars[value.slice(0, comma).trim()] = value.slice(comma + 1).trim();
            continue;
        }
        if (keyword === "key_mode") {
            submap = value === "default" || value === "common" ? "" : value;
            continue;
        }
        if (!/^(bind[slrpc]*|mousebind|axisbind|gesturebind)$/.test(keyword))
            continue;
        const parts = value.split(",").map(p => p.trim());
        if (parts.length < 3)
            continue;
        let modmask = 0;
        for (const token of parts[0].toLowerCase().split("+").map(t => t.trim())) {
            if (modBits[token])
                modmask |= modBits[token];
        }
        if (keyword === "gesturebind") {
            if (parts.length < 4)
                continue;
            const dir = parts[1], fingers = parts[2], dispatcher = parts[3];
            const arg = parts.slice(4).filter((a, i) => !(i > 0 && a === "0") && a !== "").join(" ");
            list.push({
                modmask,
                key: `${fingers}-finger swipe ${dir}`,
                keycode: 0,
                dispatcher,
                arg,
                description,
                submap
            });
            continue;
        }
        const rawKey = parts[1];
        const key = keyword === "mousebind" ? (mouseMap[rawKey.toLowerCase()] ?? rawKey)
            : keyword === "axisbind" ? (axisMap[rawKey.toLowerCase()] ?? rawKey) : rawKey;
        const keycode = rawKey.startsWith("code:") ? Number(rawKey.slice(5)) : 0;
        const dispatcher = parts[2];
        const arg = parts.slice(3).filter((a, i) => !(i > 0 && a === "0") && a !== "").join(" ");
        const flags = keyword.startsWith("bind") ? keyword.slice(4) : "";
        list.push({
            modmask,
            key,
            keycode,
            dispatcher,
            arg,
            description,
            submap,
            release: flags.includes("r"),
            locked: flags.includes("l"),
            mouse: keyword === "mousebind"
        });
    }
    return list;
}
