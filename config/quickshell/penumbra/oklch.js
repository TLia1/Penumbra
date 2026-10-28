.pragma library
// OKLCH (lightness 0–1, chroma, hue in degrees) to #rrggbb and back, as share/penumbra/palette.py
// does it: for swatches of accents the shell isn't showing yet, and for colours typed in.

function linear(L, C, H) {
    const a = C * Math.cos(H * Math.PI / 180), b = C * Math.sin(H * Math.PI / 180);
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}

function gamma(c) {
    c = Math.min(1, Math.max(0, c));
    return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.pow(c, 1 / 2.4) - 0.055;
}

// Out of the sRGB gamut, chroma is lowered until it fits; L and H stay.
function color(L, C, H) {
    const fits = c => linear(L, c, H).every(x => x >= -1e-4 && x <= 1 + 1e-4);
    if (!fits(C)) {
        let low = 0, high = C;
        for (let i = 0; i < 12; i++) {
            const middle = (low + high) / 2;
            if (fits(middle))
                low = middle;
            else
                high = middle;
        }
        C = low;
    }
    return "#" + linear(L, C, H).map(x => Math.round(gamma(x) * 255).toString(16).padStart(2, "0")).join("");
}

function toLinear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

// #rrggbb (or #rgb, the # optional) to [L, C, H], or null when it isn't one.
function fromHex(text) {
    let hex = String(text).trim().replace(/^#/, "");
    if (/^[0-9a-f]{3}$/i.test(hex))
        hex = hex.split("").map(x => x + x).join("");
    if (!/^[0-9a-f]{6}$/i.test(hex))
        return null;
    const [r, g, b] = [0, 2, 4].map(i => toLinear(parseInt(hex.substr(i, 2), 16) / 255));
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    const a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    const bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return [L, Math.hypot(a, bb), (Math.atan2(bb, a) * 180 / Math.PI + 360) % 360];
}
