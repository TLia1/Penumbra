.pragma library

// Multiple timestamps per line, fractional seconds and global LRC offsets are common.
function parse(text) {
    const offset = Number(/\[offset:\s*([+-]?\d+)\]/i.exec(text)?.[1] ?? 0) / 1000;
    const lines = [];
    for (const row of text.split(/\r?\n/)) {
        const stamps = [], pattern = /\[(\d+):([0-5]\d)(?:\.(\d{1,3}))?\]/g;
        let match;
        while ((match = pattern.exec(row)) !== null) stamps.push(match);
        const words = row.replace(/\[[^\]]*\]/g, "").trim();
        for (const stamp of stamps)
            lines.push({ time: Math.max(0, Number(stamp[1]) * 60 + Number(stamp[2]) + Number("0." + (stamp[3] || "0")) + offset), text: words });
    }
    return lines.sort((a, b) => a.time - b.time);
}

// A binary search also handles seeking backwards and tracks with long introductions.
function current(lines, seconds) {
    let low = 0, high = lines.length;
    while (low < high) {
        const mid = (low + high) >> 1;
        if (lines[mid].time <= seconds) low = mid + 1;
        else high = mid;
    }
    return low - 1;
}
