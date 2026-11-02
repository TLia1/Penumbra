.pragma library

// The launcher's matching, kept apart from Launcher.qml so it can be tested (tests/shell).

// Every term in the name or group; names that start with the first term come first, and
// often-picked characters rise (`picks`: how often this one was picked). Everything matches no
// terms, most picked first.
function charScore(c, terms, picks) {
    const boost = Math.min(40, picks ?? 0);
    if (!terms.length)
        return 1 + boost;
    const name = c.name.toLowerCase(), all = name + " " + c.group.toLowerCase();
    if (!terms.every(t => all.includes(t)))
        return 0;
    const first = terms[0];
    const s = name === terms.join(" ") ? 100 : name.startsWith(first) ? 60 : name.split(/[\s:\-]+/).some(w => w.startsWith(first)) ? 40 : 10;
    return s + boost;
}

// Frecency: each launch adds 1 to an app's score, and the score halves every `halfLife` days, so
// apps used often *lately* rise and old habits fade. A record is { score, at } (at: ms since the
// epoch); a bare number is a launch count from before, taken as that many recent launches.
var halfLife = 14;
function frecency(record, now) {
    if (typeof record === "number")
        return Math.min(record, 15);
    if (!record || !(record.score > 0))
        return 0;
    return record.score * Math.pow(0.5, Math.max(0, now - record.at) / (halfLife * 86400000));
}
function launched(record, now) {
    return { score: frecency(record, now) + 1, at: now };
}
// The boost frecency gives a match: up to 15, rising quickly then slowly, so apps never tie at a cap.
function boost(uses) {
    return 15 * (1 - Math.exp(-(uses ?? 0) / 5));
}

// Name matches first, then initials and scattered letters, then descriptions; often-launched
// apps rise a little (`uses`: the app's frecency). Everything matches an empty query.
function score(entry, q, uses) {
    const lift = boost(uses);
    if (!q)
        return 1 + lift;
    const name = entry.name.toLowerCase();
    let s = 0;
    if (name === q)
        s = 120;
    else if (name.startsWith(q))
        s = 100;
    else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
        s = 85;
    else if (name.includes(q))
        s = 70;
    else if (fuzzy(name, q))
        s = 30 + fuzzy(name, q);
    else if ([entry.genericName, entry.keywords.join(" "), entry.comment, entry.id].join(" ").toLowerCase().includes(q))
        s = 25;
    return s ? s + lift : 0;
}

// A desktop action ("New Private Window" of Firefox) for a query of three letters or more: every
// word in the app's name and the action's together; the action's own name matching scores more.
function actionScore(appName, actionName, q) {
    if (q.length < 3)
        return 0;
    const action = actionName.toLowerCase(), all = appName.toLowerCase() + " " + action;
    if (!q.split(/\s+/).every(t => all.includes(t)))
        return 0;
    return action.includes(q) ? 60 : 45;
}

// Letters of q in order inside name; fewer gaps score higher (1–30), no match is 0.
function fuzzy(name, q) {
    let at = -1, gaps = 0;
    for (const c of q) {
        const next = name.indexOf(c, at + 1);
        if (next < 0)
            return 0;
        gaps += next - at - 1;
        at = next;
    }
    return Math.max(1, 30 - gaps);
}

// Arithmetic and Math functions only; anything else is not a sum.
var mathNames = {
    pi: "Math.PI", e: "Math.E", sqrt: "Math.sqrt", cbrt: "Math.cbrt", abs: "Math.abs", round: "Math.round",
    floor: "Math.floor", ceil: "Math.ceil", sin: "Math.sin", cos: "Math.cos", tan: "Math.tan",
    asin: "Math.asin", acos: "Math.acos", atan: "Math.atan", ln: "Math.log", log: "Math.log10",
    exp: "Math.exp", min: "Math.min", max: "Math.max", pow: "Math.pow"
};
// The value of a sum ("2+2", "=12", "sqrt(2)", "3,5*2"), or null when the text is not one.
function calculate(text) {
    const forced = text.startsWith("=");
    let expr = text.replace(/^=/, "").trim().toLowerCase();
    if (!expr || !/^[\d\s+\-*/%^().,a-z]+$/.test(expr) || !/\d|pi/.test(expr))
        return null;
    // A sum needs an operator or a function; a bare number is a search.
    if (!forced && !/[+\-*/%^]|[a-z]+\s*\(/.test(expr.replace(/^-/, "")))
        return null;
    // A comma is a decimal point (3,5), unless it separates a function's arguments.
    if (!/[a-z]\s*\(/.test(expr))
        expr = expr.replace(/(\d),(\d)/g, "$1.$2");
    let unknown = false;
    expr = expr.replace(/\^/g, "**")
        .replace(/[a-z]+/g, word => mathNames[word] ?? (unknown = true, word));
    if (unknown)
        return null;
    try {
        const value = Function(`"use strict"; return (${expr});`)();
        return typeof value === "number" && isFinite(value) ? Number(value.toPrecision(12)) : null;
    } catch (e) {
        return null;
    }
}

// Unit conversion: "10 km in mi", "5kg to lb", "70 f in c", "2 GiB in MB". Each unit is a factor to
// its kind's base unit (temperatures convert through kelvin). Returns { value, unit } or null.
var units = {
    length: { mm: 0.001, cm: 0.01, m: 1, km: 1000, in: 0.0254, inch: 0.0254, inches: 0.0254, ft: 0.3048, feet: 0.3048, foot: 0.3048, yd: 0.9144, mi: 1609.344, mile: 1609.344, miles: 1609.344, nmi: 1852 },
    mass: { mg: 1e-6, g: 0.001, kg: 1, t: 1000, oz: 0.028349523125, lb: 0.45359237, lbs: 0.45359237, st: 6.35029318 },
    volume: { ml: 0.001, cl: 0.01, dl: 0.1, l: 1, tsp: 0.00492892159375, tbsp: 0.01478676478125, floz: 0.0295735295625, cup: 0.2365882365, pt: 0.473176473, qt: 0.946352946, gal: 3.785411784 },
    data: { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824, tib: 1099511627776 },
    time: { ms: 0.001, s: 1, sec: 1, min: 60, h: 3600, hr: 3600, hours: 3600, d: 86400, days: 86400, wk: 604800, week: 604800, weeks: 604800, yr: 31557600, year: 31557600, years: 31557600 },
    speed: { "m/s": 1, "km/h": 1 / 3.6, kmh: 1 / 3.6, kph: 1 / 3.6, mph: 0.44704, kn: 0.514444, knots: 0.514444 },
    area: { m2: 1, km2: 1e6, ha: 1e4, acre: 4046.8564224, acres: 4046.8564224, ft2: 0.09290304, sqft: 0.09290304 }
};
var temperatures = { c: "c", "°c": "c", celsius: "c", f: "f", "°f": "f", fahrenheit: "f", k: "k", kelvin: "k" };
function convert(text) {
    const m = /^\s*(-?\d+(?:[.,]\d+)?)\s*([a-z°/0-9]+)\s+(?:in|to|as|->)\s+([a-z°/0-9]+)\s*$/i.exec(text);
    if (!m)
        return null;
    const amount = Number(m[1].replace(",", ".")), from = m[2].toLowerCase(), to = m[3].toLowerCase();
    if (temperatures[from] && temperatures[to]) {
        const toK = { c: v => v + 273.15, f: v => (v - 32) * 5 / 9 + 273.15, k: v => v }[temperatures[from]];
        const fromK = { c: v => v - 273.15, f: v => (v - 273.15) * 9 / 5 + 32, k: v => v }[temperatures[to]];
        return { value: Number(fromK(toK(amount)).toPrecision(6)), unit: { c: "°C", f: "°F", k: "K" }[temperatures[to]] };
    }
    for (const kind in units) {
        const table = units[kind];
        // Data units are case-sensitive in spirit (b is a byte here), but people type them any way.
        if (from in table && to in table)
            return { value: Number((amount * table[from] / table[to]).toPrecision(6)), unit: m[3] };
    }
    return null;
}
// A currency conversion, "100 usd in eur" or "20€ to $": { amount, from, to } in ISO codes, or null.
var currencySigns = { "$": "USD", "€": "EUR", "£": "GBP", "¥": "JPY", "₹": "INR", "₩": "KRW", "₽": "RUB", "₺": "TRY", "₿": "" };
function currency(text) {
    const m = /^\s*([$€£¥₹₩₺])?\s*(\d+(?:[.,]\d+)?)\s*([a-z]{3}|[$€£¥₹₩₺])?\s+(?:in|to)\s+([a-z]{3}|[$€£¥₹₩₺])\s*$/i.exec(text);
    if (!m || (!m[1] && !m[3]) || (m[1] && m[3]))
        return null;
    const code = t => currencySigns[t] ?? t.toUpperCase();
    const from = code(m[1] || m[3]), to = code(m[4]);
    if (!from || !to || from === to)
        return null;
    return { amount: Number(m[2].replace(",", ".")), from, to };
}
