.pragma library

// Browsers often expose only xesam:url for YouTube videos.
function videoId(url) {
    const parts = /^https?:\/\/([^/?#]+)(\/[^?#]*)?(?:\?([^#]*))?/i.exec(String(url ?? ""));
    if (!parts) return "";
    const host = parts[1].toLowerCase(), path = parts[2] ?? "";
    if (host === "youtu.be")
        return /^\/([\w-]{11})\/?$/.exec(path)?.[1] ?? "";
    if (!/^(?:(?:www|m|music)\.)?youtube\.com$/.test(host)) return "";
    if (path === "/watch")
        return /(?:^|&)v=([\w-]{11})(?:&|$)/.exec(parts[3] ?? "")?.[1] ?? "";
    return /^\/(?:shorts|embed|live)\/([\w-]{11})\/?$/.exec(path)?.[1] ?? "";
}
