.pragma library
// OKLCH (lightness 0–1, chroma, hue in degrees) to #rrggbb, as share/penumbra/palette.py does it:
// for swatches of accents the shell isn't showing yet.

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
