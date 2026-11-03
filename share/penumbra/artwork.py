"""Deterministic palette variants of Penumbra's original SVG scenes.

Recolor source vectors before rasterization, so stills, lock images and animated
layers agree. No run-time filters, downloads or per-frame texture copies.
"""
import re
import palette

SOURCES = {
    'penumbra': 'wallpaper-eclipse',
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
