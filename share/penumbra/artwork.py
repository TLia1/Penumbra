"""Deterministic palette variants of Penumbra's original SVG scenes.

Recolor source vectors before rasterization, so stills, lock images and animated
layers agree. No run-time filters, downloads or per-frame texture copies.
"""
import math
import re
import palette

SOURCES = {
    'solar-corona': 'wallpaper-dawn',
    'aurora-borealis': 'wallpaper-eclipse',
    'event-horizon': 'wallpaper-eclipse',
    'nebula-rose': 'wallpaper',
    'starlight': 'wallpaper-dawn',
}


def recolor(source, preset):
    def color(match):
        lightness, chroma, hue = palette.hex_to_oklch(match[0].lower())
        # Compress the original violet/rose range into the chosen accent family.
        offset = (hue - palette.BASE_HUE + 180) % 360 - 180
        hue = (preset['hue'] + offset * .35) % 360
        chroma *= preset['vividness']
        if preset['mode'] == 'light':
            # Pearl sky, lavender planet and darker rings retain the silhouette in daylight.
            lightness = .97 - lightness * .58
            chroma = min(chroma * .65, .09)
        return palette.oklch_to_hex(lightness, chroma, hue)
    return re.sub(r'#[0-9a-fA-F]{6}\b', color, source)

def preset_scene(source, preset):
    svg = recolor(source, preset)
    if preset['wallpaper'] != 'wallpaper-aurora-borealis':
        return svg

    # A folded curtain crossing the whole sky. Each ray rises from the same
    # ribbon edge, with varying height and inclination as the folds turn.
    defs = """<linearGradient id="polar-ray" x1="0" y1="1" x2="0" y2="0">
    <stop stop-color="#83ffe0" stop-opacity=".78"/>
    <stop offset=".14" stop-color="#42e4ba" stop-opacity=".56"/>
    <stop offset=".52" stop-color="#389eaa" stop-opacity=".23"/>
    <stop offset="1" stop-color="#a89ce5" stop-opacity="0"/>
    </linearGradient>"""
    rays = []
    for x in range(-300, 2800, 5):
        fold = math.sin(x / 246 + 1.35 * math.sin(x / 450))
        y = 810 - 240 * fold + 85 * math.sin(x / 110)
        height = 240 + 175 * (1 + fold) + 34 * math.sin(x / 13)
        lean = 90 + 75 * math.sin(x / 240)
        alpha = .32 + .16 * math.sin(x / 8) + .13 * math.cos(x / 25)
        rays.append(f'<path d="M{x} {y:.1f} q{-lean:.1f} {-height * .64:.1f} '
                    f'{-lean * .72:.1f} {-height:.1f} l16 0 Q{x - lean + 12:.1f} '
                    f'{y - height * .64:.1f} {x + 10} {y:.1f} Z" opacity="{alpha:.3f}"/>')
    curtain = '<g id="polar-curtain" fill="url(#polar-ray)">\n' + '\n'.join(rays) + '\n</g>\n'
    return svg.replace('</defs>', defs + '</defs>').replace('<g id="layer-nebula"', curtain + '<g id="layer-nebula"')
