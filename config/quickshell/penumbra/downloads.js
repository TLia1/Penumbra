.pragma library
// The Downloads panel's logic (DownloadsPanel.qml, and the launcher's download result): which text
// is an address, the choices offered for video and audio, the command that starts a download, and
// how a download's progress reads. bin/penumbra-download checks the same choices.

const videoFormats = [
    { value: "mp4", title: "MP4" },
    { value: "mkv", title: "MKV" },
    { value: "webm", title: "WebM" }
];
const audioFormats = [
    { value: "mp3", title: "MP3" },
    { value: "m4a", title: "M4A" },
    { value: "opus", title: "Opus" },
    { value: "flac", title: "FLAC" },
    { value: "wav", title: "WAV" }
];
const lossless = ["flac", "wav"];
const heights = [2160, 1440, 1080, 720, 480];
const bitrates = [320, 192, 128];

// The address in `text`, or "" when it isn't one. Only http(s) addresses count, unless `loose`
// (the panel's own field), where "youtube.com/watch?v=…" gets https:// in front.
function address(text, loose) {
    const t = String(text ?? "").trim();
    if (!t || /\s/.test(t))
        return "";
    if (/^https?:\/\/[^\/\s.]+\.[^\/\s]+/i.test(t) || /^https?:\/\/localhost[:\/]/i.test(t))
        return t;
    if (loose && /^([a-z0-9-]+\.)+[a-z]{2,}(:\d+)?\/\S*$/i.test(t))
        return "https://" + t;
    return "";
}

// A video in a playlist (YouTube's watch?v=…&list=…): the panel offers the whole playlist.
function inPlaylist(url) {
    return /[?&]list=[^&#]+/.test(url ?? "");
}

function formats(audio) {
    return audio ? audioFormats : videoFormats;
}
function defaultFormat(audio) {
    return audio ? "mp3" : "mp4";
}
// The format chosen before, when it is one this kind offers.
function format(audio, saved) {
    return formats(audio).some(f => f.value === saved) ? saved : defaultFormat(audio);
}

// Video: best, then each height up to the tallest the video has (all of them before it is looked
// up). Audio: best and bitrates, none for lossless formats. A height is the smaller side, as
// yt-dlp counts it, so a portrait 1080×1920 video is 1080p.
function qualities(audio, fmt, available) {
    if (audio)
        return lossless.includes(fmt) ? [] : [{ value: "best", title: "Best" }].concat(bitrates.map(b => ({ value: String(b), title: b + "k" })));
    const tallest = Math.max(0, ...(available ?? []));
    const offered = tallest > 0 ? heights.filter(h => h <= tallest * 1.1) : heights;
    return [{ value: "best", title: "Best" }].concat(offered.map(h => ({ value: String(h), title: h === 2160 ? "4K" : h + "p" })));
}
// The chosen quality when it is offered, else best.
function quality(options, saved) {
    return options.some(q => q.value === saved) ? saved : "best";
}

// penumbra-download's arguments for a download. `choice`: { url, audio, format, quality, folder,
// playlist, title }.
function command(helper, choice) {
    const args = [helper, "start", choice.url, "--format", choice.format, "--quality", choice.quality || "best"];
    if (choice.audio)
        args.push("--audio");
    if (choice.folder)
        args.push("--folder", choice.folder);
    if (choice.playlist)
        args.push("--playlist");
    if (choice.title)
        args.push("--title", choice.title);
    return args;
}

function active(job) {
    return ["starting", "downloading", "processing"].includes(job?.status);
}

function bytes(n) {
    if (!(n > 0))
        return "";
    const units = ["B", "KB", "MB", "GB", "TB"];
    let i = 0;
    while (n >= 1000 && i < units.length - 1) {
        n /= 1000;
        i++;
    }
    return (i === 0 || n >= 100 ? Math.round(n) : n.toFixed(1)) + " " + units[i];
}

// 75 → "1:15", 3725 → "1:02:05".
function clock(seconds) {
    if (!(seconds >= 0))
        return "";
    const s = Math.round(seconds), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
    const ss = String(s % 60).padStart(2, "0");
    return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
}

function home(path, homeDir) {
    if (!path || !homeDir)
        return path ?? "";
    return path === homeDir ? "~" : path.startsWith(homeDir + "/") ? "~" + path.slice(homeDir.length) : path;
}
function expand(path, homeDir) {
    const p = String(path ?? "").trim();
    return p === "~" ? homeDir : p.startsWith("~/") ? homeDir + p.slice(1) : p;
}

// The line under a download's title.
function describe(job, homeDir) {
    const items = job.items > 1 ? `${job.item || 1} of ${job.items} · ` : "";
    switch (job.status) {
    case "starting":
        return "Starting…";
    case "downloading": {
        const parts = [];
        if (job.percent >= 0)
            parts.push(Math.floor(job.percent) + "%" + (job.size > 0 ? " of " + bytes(job.size) : ""));
        else if (job.done > 0)
            parts.push(bytes(job.done));
        if (job.speed > 0)
            parts.push(bytes(job.speed) + "/s");
        if (job.eta > 0)
            parts.push(clock(job.eta) + " left");
        return items + (parts.join(" · ") || "Downloading…");
    }
    case "processing":
        return items + (job.kind === "audio" ? "Converting…" : "Finishing…");
    case "done": {
        const folder = job.file ? job.file.replace(/\/[^\/]*$/, "") : job.folder;
        return (job.items > 1 ? job.items + " files · " : "") + "Saved in " + home(folder, homeDir);
    }
    case "cancelled":
        return "Cancelled";
    default:
        return job.error || "Failed";
    }
}

// What to call a download: its title, else its file's name, else the address.
function title(job) {
    return job.title || (job.file ? job.file.replace(/^.*\//, "") : "") || job.url;
}
