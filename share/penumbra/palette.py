"""PENUMBRA palettes: load palette.toml, render the colour templates, and make a palette for any accent.

Shared by tools/build-palette.py (the repository's generated files) and penumbra-theme (your
installed ones), so a template renders the same way at build time and at run time.

A template names colours as {{name}} (#rrggbb), {{name:hex}} (rrggbb), {{name:rgb}} (r,g,b) or
{{name:sgr}} (r;g;b, for terminal colour codes), from the palette being rendered. {{dark.name}} and
{{light.name}} always take that mode's colour (a file that holds both, such as VS Code's themes), and
{{mode}} is "dark" or "light".
"""
import math
import re
import tomllib

MODES = ('dark', 'light')
# The palette.toml table of each mode.
TABLES = {'dark': 'colors', 'light': 'light'}
TOKEN = re.compile(r'\{\{\s*(?:(dark|light)\.)?([A-Za-z]+)(?::(hex|rgb|sgr))?\s*\}\}')

# The hue of the default accent (OKLCH degrees); a new accent turns every hue key by its distance from it.
BASE_HUE = 297
# Keys that follow the accent's hue: surfaces, selection, the accent itself, text and the tinted
# neutrals. Signal and diff colours keep their own hues.
HUE_KEYS = {
    'shade', 'base', 'surface', 'viewAlt', 'surfaceAlt', 'raised', 'button', 'buttonAlt', 'glassRaised',
    'border', 'hover', 'light', 'mid',
    'textSelection', 'selectionAlt', 'selection',
    'accentDeep', 'accentSoft', 'accent', 'accentBright',
    'white', 'text', 'textSoft', 'subtle', 'muted', 'dim',
    'black', 'silver', 'diffChange', 'diffText',
}
ACCENT_KEYS = {'accentDeep', 'accentSoft', 'accent', 'accentBright', 'selection', 'selectionAlt'}
# The least chroma the accent keeps at vividness 0, so focus rings and selections still read as accent.
ACCENT_FLOOR = 0.02
# Text on a fill, and the contrast it needs: the darkest ink of the palette or white, whichever reads.
INKS = {'onAccent': ('accent', 4.5), 'selectionText': ('selection', 3)}
# (colour, against, least WCAG contrast) every generated palette keeps; the first one's lightness moves.
# The accent moves rather than its ink, which is already as dark or as light as it goes.
GUARDS = [('text', 'base', 7), ('muted', 'surface', 4.5), ('accent', 'surface', 3), ('accent', 'onAccent', 4.5)]


def load(path):
    """{'dark': {name: '#rrggbb'}, 'light': {...}} from palette.toml; both tables have the same keys."""
    data = tomllib.loads(path.read_text())
    palettes = {}
    for mode, table in TABLES.items():
        if table not in data:
            raise ValueError(f'{path}: no [{table}] table')
        for name, value in data[table].items():
            if not re.fullmatch(r'#[0-9a-f]{6}', value):
                raise ValueError(f'{path}: [{table}] {name} should be a lowercase #rrggbb colour, not {value!r}')
        palettes[mode] = data[table]
    missing = set(palettes['dark']) ^ set(palettes['light'])
    if missing:
        raise ValueError(f'{path}: [colors] and [light] should have the same keys; check {", ".join(sorted(missing))}')
    return palettes


def render(text, palettes, mode, where='template'):
    """TEXT with every token filled in from PALETTES[MODE] (see the module's docstring)."""
    def token(match):
        which, name, form = match.groups()
        if name == 'mode' and not which and not form:
            return mode
        colors = palettes[which or mode]
        if name not in colors:
            raise KeyError(f'{where}: unknown colour {name!r}')
        value = colors[name]
        if form == 'hex':
            return value[1:]
        if form in ('rgb', 'sgr'):
            return (',' if form == 'rgb' else ';').join(str(c) for c in rgb255(value))
        return value
    return TOKEN.sub(token, text)


# ─── Colour spaces ───────────────────────────────────────────────────────────
# OKLab (Björn Ottosson), and OKLCH as its polar form: L lightness 0–1, C chroma, H hue in degrees.

def rgb255(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def from_linear(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_to_oklch(value):
    r, g, b = (to_linear(c / 255) for c in rgb255(value))
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(a, bb), math.degrees(math.atan2(bb, a)) % 360


def oklch_to_linear(L, C, H):
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def oklch_to_hex(L, C, H):
    """The colour as #rrggbb; out of the sRGB gamut, chroma is lowered until it fits (L and H stay)."""
    def fits(c):
        return all(-1e-4 <= x <= 1 + 1e-4 for x in oklch_to_linear(L, c, H))
    if not fits(C):
        low, high = 0.0, C
        for _ in range(12):
            middle = (low + high) / 2
            low, high = (middle, high) if fits(middle) else (low, middle)
        C = low
    return '#' + ''.join(f'{round(from_linear(min(1, max(0, x))) * 255):02x}' for x in oklch_to_linear(L, C, H))


def luminance(value):
    r, g, b = (to_linear(c / 255) for c in rgb255(value))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    """WCAG contrast ratio of two #rrggbb colours, 1 to 21."""
    x, y = sorted((luminance(a), luminance(b)), reverse=True)
    return (x + 0.05) / (y + 0.05)


# ─── Palettes for any accent ─────────────────────────────────────────────────

def generate(base, hue, vividness):
    """BASE (a mode's default palette) moved to the accent HUE (degrees) at VIVIDNESS (chroma scale,
    0 grey to 1.3), keeping every lightness, so contrast stays the default's. Then the inks on
    accent fills are chosen and the guarded pairs checked (GUARDS)."""
    turn = hue - BASE_HUE
    colors = dict(base)
    for name in HUE_KEYS:
        L, C, H = hex_to_oklch(base[name])
        C *= vividness
        if name in ACCENT_KEYS:
            C = max(C, ACCENT_FLOOR)
        colors[name] = oklch_to_hex(L, C, (H + turn) % 360)
    for ink, (fill, least) in INKS.items():
        colors[ink] = choose_ink(base, colors, ink, fill, least, turn, vividness)
    guard(colors)
    return colors


def darkest_ink(base, turn, vividness):
    """The palette's dark ink at the new hue, for text on a light fill: its own onAccent in dark mode,
    its strongest text in light mode."""
    dark = base['onAccent']
    if luminance(dark) > 0.5:
        dark = min((base[k] for k in ('white', 'text', 'shade')), key=luminance)
    L, C, H = hex_to_oklch(dark)
    return oklch_to_hex(L, C * vividness, (H + turn) % 360)


def choose_ink(base, colors, ink, fill, least, turn, vividness):
    """The default palette's kind of ink (dark or white) when it still reads on the new fill, else
    whichever reads better."""
    inks = [darkest_ink(base, turn, vividness), '#ffffff']
    if luminance(base[ink]) > 0.5:
        inks.reverse()
    if contrast(inks[0], colors[fill]) >= least:
        return inks[0]
    return max(inks, key=lambda i: contrast(i, colors[fill]))


def guard(colors):
    """Move each guarded colour's lightness away from the other until the pair has its contrast."""
    for moved, against, least in GUARDS:
        L, C, H = hex_to_oklch(colors[moved])
        step = 0.01 if luminance(colors[moved]) >= luminance(colors[against]) else -0.01
        while contrast(colors[moved], colors[against]) < least and 0 < L < 1:
            L = min(1, max(0, L + step))
            colors[moved] = oklch_to_hex(L, C, H)


def resolve(palettes, mode, colors='default', hue=BASE_HUE, vividness=1.0):
    """The palette for a theme choice: the mode's default, or it moved to an accent."""
    if colors == 'default':
        return dict(palettes[mode])
    return generate(palettes[mode], hue, vividness)
