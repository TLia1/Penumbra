.pragma library

// Format Hyprland's active bindings, including user.lua overrides and submaps.
function shortcut(bind) {
    const parts = [];
    for (const [mask, name] of [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"],
                              [2, "Caps Lock"], [16, "Mod2"], [32, "Mod3"], [128, "Mod5"]]) {
        if ((bind.modmask || 0) & mask) parts.push(name);
    }
    const names = {
        Return: "Enter", space: "Space", comma: ",", semicolon: ";", Caps_Lock: "Caps Lock",
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
        // Lua callbacks cannot be recovered as commands from Hyprland's IPC.
        const action = b.description || (b.dispatcher === "__lua" ? "Custom Lua binding (no description)"
            : [b.dispatcher, b.arg].filter(Boolean).join(" ")) || "Custom binding (no description)";
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
