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

// Name matches first, then initials and scattered letters, then descriptions; often-launched
// apps rise a little (`uses`: how often this one was launched). Everything matches an empty query.
function score(entry, q, uses) {
    const boost = Math.min(15, uses ?? 0);
    if (!q)
        return 1 + boost;
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
    return s ? s + boost : 0;
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
