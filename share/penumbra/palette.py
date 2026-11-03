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
# Signal and diff colours a harmonized palette turns toward the accent, keeping their meaning: half
# the way, at most HARMONY degrees (as Material You does), and less for a nearly grey accent.
HARMONIZED = {
    'rose', 'green', 'amber', 'blue', 'pink', 'cyan',
    'roseBright', 'greenBright', 'amberBright', 'blueBright', 'cyanBright',
    'diffAdd', 'diffDelete', 'diffAddEmph', 'diffDeleteEmph',
}
HARMONY = 15
# The fixed violets of the Penumbra icon theme's folders (share/icons/Penumbra): light, mid, dark.
ICON_COLORS = ('#7e57c2', '#5d399b', '#2c1e44')


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

def turned(value, turn, vividness, floor=0.0):
    """VALUE with its hue turned by TURN degrees and its chroma scaled by VIVIDNESS (at least FLOOR),
    at the same lightness."""
    L, C, H = hex_to_oklch(value)
    return oklch_to_hex(L, max(C * vividness, floor), (H + turn) % 360)


def generate(base, hue, vividness, harmonize=False):
    """BASE (a mode's default palette) moved to the accent HUE (degrees) at VIVIDNESS (chroma scale,
    0 grey to 1.3), keeping every lightness, so contrast stays the default's. Then the inks on
    accent fills are chosen and the guarded pairs checked (GUARDS). HARMONIZE turns the signal
    colours a little toward the accent too (HARMONIZED)."""
    turn = hue - BASE_HUE
    colors = dict(base)
    for name in HUE_KEYS:
        colors[name] = turned(base[name], turn, vividness, ACCENT_FLOOR if name in ACCENT_KEYS else 0.0)
    if harmonize:
        for name in HARMONIZED:
            colors[name] = harmonized(base[name], hue, vividness)
    for ink, (fill, least) in INKS.items():
        colors[ink] = choose_ink(base, colors, ink, fill, least, turn, vividness)
    guard(colors)
    return colors


def harmonized(value, hue, vividness):
    """VALUE's hue turned half the way toward HUE, at most HARMONY degrees; a grey accent (VIVIDNESS
    under 1) has less pull."""
    L, C, H = hex_to_oklch(value)
    distance = (hue - H + 180) % 360 - 180  # signed, the short way round
    pull = min(abs(distance) / 2, HARMONY) * min(1.0, vividness)
    return oklch_to_hex(L, C, (H + math.copysign(pull, distance)) % 360)


def icon_colors(hue, vividness):
    """{icon violet: its colour for the accent HUE and VIVIDNESS}, turned like the accent family."""
    return {value: turned(value, hue - BASE_HUE, vividness, ACCENT_FLOOR) for value in ICON_COLORS}


def mix(a, b, t):
    """The #rrggbb colour T (0–1) of the way from A to B, in sRGB as the shell's fades go."""
    return '#' + ''.join(f'{round(x + (y - x) * t):02x}' for x, y in zip(rgb255(a), rgb255(b)))


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


# Named palettes tune surfaces as well as accent hue. The opposite mode uses the
# same accent family with that mode's readable surfaces.
PRESETS = {
    'penumbra': dict(title='Penumbra', mode='dark', hue=297, vividness=1,
                     wallpaper='wallpaper-eclipse', base='#0d0a12', surface='#100d18', accent='#b69af7'),
    'solar-corona': dict(title='Solar Corona', mode='dark', hue=65, vividness=.9,
                         wallpaper='wallpaper-solar-corona', base='#16100c', surface='#211811', accent='#f4b976'),
    'aurora-borealis': dict(title='Aurora Borealis', mode='dark', hue=185, vividness=.85,
                            wallpaper='wallpaper-aurora-borealis', base='#09151a', surface='#102128', accent='#7cdbd5'),
    'event-horizon': dict(title='Event Horizon', mode='dark', hue=10, vividness=1.1,
                          wallpaper='wallpaper-event-horizon', base='#040307', surface='#0b080e', accent='#f27996'),
    'nebula-rose': dict(title='Nebula Rose', mode='dark', hue=350, vividness=.65,
                        wallpaper='wallpaper-nebula-rose', base='#14121d', surface='#201c2b', accent='#e5abc2'),
    'starlight': dict(title='Starlight', mode='light', hue=297, vividness=1,
                      wallpaper='wallpaper-starlight', base='#f8f6fb', surface='#efebf5', accent='#754cbd'),
}


def preset_palette(palettes, mode, name):
    preset = PRESETS[name]
    if name == 'penumbra':
        return dict(palettes[mode])
    colors = generate(palettes[mode], preset['hue'], preset['vividness'], True)
    if mode == preset['mode']:
        # Move the entire surface ladder by the new surface lightness, then set
        # the art-directed base, surface and accent exactly.
        delta = hex_to_oklch(preset['surface'])[0] - hex_to_oklch(colors['surface'])[0]
        for key in ('shade', 'viewAlt', 'surfaceAlt', 'raised', 'button', 'buttonAlt', 'glassRaised'):
            L, C, H = hex_to_oklch(colors[key])
            colors[key] = oklch_to_hex(max(0, min(1, L + delta)), C, H)
        colors.update({key: preset[key] for key in ('base', 'surface', 'accent')})
    for ink, (fill, least) in INKS.items():
        colors[ink] = choose_ink(palettes[mode], colors, ink, fill, least,
                                preset['hue'] - BASE_HUE, preset['vividness'])
    guard(colors)
    return colors


def resolve(palettes, mode, colors='default', hue=BASE_HUE, vividness=1.0, harmonize=False):
    """The palette for a theme choice: the mode's default, or it moved to an accent."""
    if colors == 'default':
        return dict(palettes[mode])
    return generate(palettes[mode], hue, vividness, harmonize)


# ─── Accents from a wallpaper ────────────────────────────────────────────────

# The default accent's chroma; a wallpaper colour this vivid is vividness 1.
BASE_CHROMA = 0.134
WALLPAPER_VIVIDNESS = (0.35, 1.3)
# A wallpaper with less colour than this (share of its pixels) gives one nearly grey accent.
NEUTRAL_SHARE = 0.03
NEUTRAL_VIVIDNESS = 0.15
MOVING = ('gif', 'mp4', 'webm', 'mkv', 'mov', 'm4v')


def wallpaper_pixels(path):
    """PATH (an image, GIF or video) as a small list of (r, g, b), through ffmpeg. A GIF or video
    gives its most typical frame among the first hundred, rather than the first, which is often
    black or a title."""
    import subprocess
    scale = 'scale=96:64:flags=area'
    moving = str(path).rpartition('.')[2].lower() in MOVING
    data = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', str(path),
                           '-vf', f'thumbnail=100,{scale}' if moving else scale, '-frames:v', '1',
                           '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'],
                          capture_output=True, check=True, timeout=60).stdout
    return [tuple(data[i:i + 3]) for i in range(0, len(data) - 2, 3)]


def wallpaper_accents(pixels, count=4):
    """Up to COUNT accents found in PIXELS, the strongest first, as {'hue', 'vividness'}: the peaks
    of a hue histogram of the coloured pixels, weighted by chroma, at least 40° apart. Too little
    colour gives one nearly grey accent, at the wallpaper's hue if it has one."""
    def oklch(rgb):
        return hex_to_oklch('#%02x%02x%02x' % rgb)

    times = {}
    for rgb in pixels:
        times[rgb] = times.get(rgb, 0) + 1
    colored = []  # (chroma, hue, pixels) of each colour that counts
    for rgb, n in times.items():
        L, C, H = oklch(rgb)
        if 0.12 <= L <= 0.97 and C >= 0.03:
            colored.append((C, H, n))
    if sum(n for _, _, n in colored) < NEUTRAL_SHARE * max(1, len(pixels)):
        hue = circular_mean([(H, C * n) for C, H, n in colored]) if colored else BASE_HUE
        return [{'hue': round(hue) % 360, 'vividness': NEUTRAL_VIVIDNESS}]

    bins = [0.0] * 36
    for C, H, n in colored:
        bins[int(H // 10) % 36] += C * n
    smooth = [(bins[i - 1] + 2 * bins[i] + bins[(i + 1) % 36]) / 4 for i in range(36)]
    peaks = sorted((i for i in range(36) if smooth[i] > 0 and smooth[i] >= smooth[i - 1]
                    and smooth[i] >= smooth[(i + 1) % 36]), key=lambda i: -smooth[i])
    accents = []
    for i in peaks:
        # Faint peaks are the edges of strong ones, or specks.
        if smooth[i] < 0.1 * smooth[peaks[0]] or len(accents) == count:
            break
        centre = i * 10 + 5
        if any(angle(centre, a['centre']) < 40 for a in accents):
            continue
        near = [(C, H, n) for C, H, n in colored if angle(H, centre) <= 20]
        chromas = sorted(c for C, _, n in near for c in [C] * n)
        vividness = chromas[int(0.9 * (len(chromas) - 1))] / BASE_CHROMA
        accents.append({'centre': centre, 'hue': round(circular_mean([(H, C * n) for C, H, n in near])) % 360,
                        'vividness': round(min(max(vividness, WALLPAPER_VIVIDNESS[0]), WALLPAPER_VIVIDNESS[1]), 2)})
    return [{'hue': a['hue'], 'vividness': a['vividness']} for a in accents]


def angle(a, b):
    """The distance between two hues, 0 to 180 degrees."""
    return abs((a - b + 180) % 360 - 180)


def circular_mean(weighted):
    """The mean of [(hue, weight)], around the circle."""
    x = sum(w * math.cos(math.radians(h)) for h, w in weighted)
    y = sum(w * math.sin(math.radians(h)) for h, w in weighted)
    return math.degrees(math.atan2(y, x)) % 360
