#!/usr/bin/env python3
"""Build original boot artwork from Penumbra's wallpaper and palette.
Needs Pillow, rsvg-convert (librsvg) and the Inter font, as the wallpapers do."""
from pathlib import Path
from PIL import Image
import math
import subprocess

root = Path(__file__).resolve().parents[1]
grub, ply, limine = root / 'boot/grub', root / 'boot/plymouth', root / 'boot/limine'
limine.mkdir(exist_ok=True)


def render(svg, path):
    subprocess.run(['rsvg-convert', '-o', str(path)], input=svg.encode(), check=True)


def svg(width, height, body, defs=''):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
            f'viewBox="0 0 {width} {height}"><defs>{defs}</defs>{body}</svg>')


# The wallpaper's sky, rim light and planet shading, reused by every scene below.
RIM = ('<stop stop-color="#2b1547"/><stop offset=".37" stop-color="#7c3cc7"/>'
       '<stop offset=".65" stop-color="#dabaff"/><stop offset=".8" stop-color="#8651c0"/>'
       '<stop offset="1" stop-color="#1d102a"/>')
PLANET = ('<radialGradient id="planet" cx="74%" cy="26%" r="75%"><stop stop-color="#41245c"/>'
          '<stop offset=".3" stop-color="#1b102b"/><stop offset=".75" stop-color="#08080e"/>'
          '<stop offset="1" stop-color="#08070c"/></radialGradient>')
EDGE = '#07070b'


def sky(cx, cy):
    # Fades to EDGE before every border, so a centred image meets the backdrop seamlessly.
    return (f'<radialGradient id="sky" cx="{cx}" cy="{cy}" r=".5" fx="{cx}" fy="{cy}">'
            '<stop stop-color="#1d0f2d"/><stop offset=".45" stop-color="#0f0a17"/>'
            f'<stop offset=".92" stop-color="{EDGE}"/></radialGradient>')


def stars(points):
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#c8a2ef" opacity="{o}"/>' for x, y, r, o in points)


def planet(cx, cy, r, rx, ry, tilt, glow=1.0, ring_width=None, behind='', before=''):
    """Planet with a tilted ring; `behind` is drawn between the far half of the ring and the
    planet, `before` over everything."""
    rw = ring_width or max(2, r / 40)
    back = f'M {-rx} 0 A {rx} {ry} 0 0 1 {rx} 0'
    front = f'M {rx} 0 A {rx} {ry} 0 0 1 {-rx} 0'
    def ring(path):
        return (f'<g transform="translate({cx} {cy}) rotate({tilt})">'
                f'<path d="{path}" fill="none" stroke="#a66ce9" stroke-width="{rw * 3}" filter="url(#ringglow)" opacity="{.5 * glow}"/>'
                f'<path d="{path}" fill="none" stroke="url(#rim)" stroke-width="{rw}" stroke-linecap="round"/>'
                f'<path d="{path}" fill="none" stroke="url(#rim)" stroke-width="{rw / 4}" opacity=".4" transform="scale({1 + 11 / 615} {1 + 11 / 188})"/>'
                '</g>')
    return (ring(back) + behind
            + f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#planet)" stroke="#362047" stroke-width="1"/>'
            # Atmosphere: a thin violet limb, brightest towards the light.
            + f'<circle cx="{cx}" cy="{cy}" r="{r - 0.5}" fill="none" stroke="url(#limb)" stroke-width="{max(1, r / 50)}"/>'
            + ring(front) + before)


def planet_defs(rx, ry, glow_blur):
    return (f'<linearGradient id="rim" gradientUnits="userSpaceOnUse" x1="{-rx}" y1="{ry}" x2="{rx}" y2="{-ry}">{RIM}</linearGradient>'
            '<linearGradient id="limb" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#7c3cc7" stop-opacity="0"/>'
            '<stop offset=".7" stop-color="#9b6ae0" stop-opacity=".18"/><stop offset="1" stop-color="#dabaff" stop-opacity=".4"/></linearGradient>'
            f'{PLANET}<filter id="ringglow" x="-20%" y="-60%" width="140%" height="220%"><feGaussianBlur stdDeviation="{glow_blur}"/></filter>'
            f'<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{glow_blur * 6}"/></filter>')


# ── GRUB ─────────────────────────────────────────────────────────────────────
Image.open(root / 'assets/wallpaper.png').convert('RGB').resize((1600, 1000)).save(grub / 'background.png')
# GRUB selected-entry nine-slice frame, entirely original artwork.
for name, size in [('c', (8, 8)), ('n', (8, 3)), ('s', (8, 3)), ('e', (3, 8)), ('w', (3, 8)),
                   ('nw', (3, 3)), ('ne', (3, 3)), ('sw', (3, 3)), ('se', (3, 3))]:
    Image.new('RGBA', size, '#352348' if name == 'c' else '#78579b').save(grub / f'select_{name}.png')

# ── Limine ───────────────────────────────────────────────────────────────────
# Shown with `wallpaper_style: centered` on an EDGE backdrop: never stretched, so the planet
# stays round at any aspect ratio. The menu is drawn in the middle; the planet sits to its
# right and stays inside the 1280x800 centre crop of smaller screens.
W, H = 1920, 1080
cx, cy, r = 1300, 560, 150
rx, ry = r * 615 / 370, r * 188 / 370
render(svg(W, H,
           f'<rect width="{W}" height="{H}" fill="url(#sky)"/>'
           f'<ellipse cx="{cx + 12}" cy="{cy + 18}" rx="{r * 1.5}" ry="{r * 1.3}" fill="#6e2cb9" opacity=".11" filter="url(#soft)"/>'
           f'<g transform="translate({cx} {cy}) rotate(-28)" fill="none" stroke="#7e4ab4" stroke-width="1">'
           f'<ellipse rx="{rx * 1.17}" ry="{ry * 1.3}" opacity=".14"/><ellipse rx="{rx * 1.27}" ry="{ry * 1.54}" opacity=".07"/></g>'
           + planet(cx, cy, r, rx, ry, -28, ring_width=2.4)
           + stars([(1640, 300, 2, .55), (560, 820, 1.5, .4), (1500, 860, 1.5, .3), (420, 250, 1.2, .3), (1120, 230, 1.2, .25)]),
           sky(.62, .52) + planet_defs(rx, ry, 9)),
       limine / 'background.png')

# ── Plymouth ─────────────────────────────────────────────────────────────────
# Throbber: the wallpaper's planet in miniature, with a moonlet riding the ring and a ring
# glow that breathes. 30 fps (Plymouth's rate), one orbit every four seconds. The soft halo
# lives in the background: in every frame it would cost the initramfs megabytes.
FW, FH, FRAMES = 320, 200, 120
pr = 60
prx, pry = pr * 2.05, pr * .62
tilt = -28
for path in list(ply.glob('throbber-*.png')) + list(ply.glob('animation-*.png')) + [ply / 'keymap-render.png']:
    path.unlink(missing_ok=True)
for frame in range(FRAMES):
    phase = frame / FRAMES
    breathe = .5 + .5 * math.sin(2 * math.pi * phase)
    def moon(part):
        dots = []
        for i in range(16, -1, -1):
            t = 2 * math.pi * phase - i * .045
            if (math.sin(t) > 0) != (part == 'front'):
                continue
            x, y = prx * math.cos(t), pry * math.sin(t)
            depth = 1 if part == 'front' else .55
            if i == 0:
                dots.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="6" fill="#dac5ff" opacity="{.45 * depth:.2f}" filter="url(#moonglow)"/>'
                            f'<circle cx="{x:.2f}" cy="{y:.2f}" r="2.8" fill="#f6efff" opacity="{depth:.2f}"/>')
            else:
                dots.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{2.2 - i * .08:.2f}" fill="#cdb4fb" opacity="{.42 * (1 - i / 17) * depth:.2f}"/>')
        return f'<g transform="translate({FW / 2} {FH / 2}) rotate({tilt})">{"".join(dots)}</g>'
    body = planet(FW / 2, FH / 2, pr, prx, pry, tilt, glow=.8 + .4 * breathe, ring_width=2,
                  behind=moon('back'), before=moon('front'))
    path = ply / f'throbber-{frame + 1:04}.png'
    render(svg(FW, FH, body, planet_defs(prx, pry, 3)
               + '<filter id="moonglow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="2.5"/></filter>'),
           path)
    # Every frame goes into the initramfs; a 256-colour palette keeps them a third the size,
    # indistinguishable on this artwork. Plymouth expands palette PNGs when it loads them.
    if Image.core.HAVE_LIBIMAGEQUANT:
        Image.open(path).quantize(256, method=Image.Quantize.LIBIMAGEQUANT).save(path, optimize=True)

# Background: the wallpaper's sky, centred on the planet. Plymouth stretches it to the screen,
# so it holds nothing that would show the distortion.
render(svg(1280, 800, '<rect width="1280" height="800" fill="url(#sky)"/>'
           '<ellipse cx="644" cy="358" rx="150" ry="125" fill="#6e2cb9" opacity=".2" filter="url(#wide)"/>',
           sky(.5, .44).replace('r=".5"', 'r=".62"')
           + '<filter id="wide" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="45"/></filter>'),
       ply / 'background.png')


def wordmark(width, title, subtitle, size, spacing):
    # Letter spacing trails the last glyph too; shift by half of it to centre the word.
    mid = width / 2
    return (f'<path d="M{mid - 22} 2h44" stroke="#ad83e2" stroke-width="2"/>'
            f'<text x="{mid + spacing / 2}" y="{14 + size * 1.6}" text-anchor="middle" font-family="Inter" font-size="{size}" '
            f'letter-spacing="{spacing}" fill="#b8a4cf">{title}</text>'
            f'<text x="{mid + 1.25}" y="{14 + size * 1.6 + 22}" text-anchor="middle" font-family="Inter" font-size="{size * .6:.1f}" '
            f'letter-spacing="2.5" fill="#635570">{subtitle}</text>')


render(svg(360, 72, wordmark(360, 'PENUMBRA', 'A QUIETER ORBIT.', 15, 7)), ply / 'watermark.png')

# Password dialog: a frosted card like the shell's, holding the lock and the field.
render(svg(420, 88, '<rect x=".5" y=".5" width="419" height="87" rx="20" fill="#100d18" fill-opacity=".88" '
           'stroke="#b69af7" stroke-opacity=".22"/><path d="M190 1h40" stroke="#ad83e2" stroke-opacity=".7" stroke-width="2"/>'),
       ply / 'box.png')
render(svg(324, 44, '<rect x="1" y="1" width="322" height="42" rx="13" fill="#1a1424" stroke="#b69af7" '
           'stroke-opacity=".6" stroke-width="1.5"/>'), ply / 'entry.png')
render(svg(18, 18, '<circle cx="9" cy="9" r="4" fill="#dac5ff"/>'), ply / 'bullet.png')
# The field follows the lock directly, so its right-hand gap is part of the image.
render(svg(52, 44, '<path d="M14 19v-5a8 8 0 0 1 16 0v5" fill="none" stroke="#b69af7" stroke-width="3" stroke-linecap="round"/>'
           '<rect x="9" y="18" width="26" height="20" rx="5" fill="#b69af7"/><circle cx="22" cy="27" r="2.6" fill="#100d18"/>'
           '<path d="M22 28.5v4" stroke="#100d18" stroke-width="2" stroke-linecap="round"/>'), ply / 'lock.png')
render(svg(24, 24, '<path d="M12 3l9 9h-5v5H8v-5H3z" fill="none" stroke="#b69af7" stroke-width="2" stroke-linejoin="round"/>'
           '<path d="M8 20.5h8" stroke="#b69af7" stroke-width="2" stroke-linecap="round"/>'), ply / 'capslock.png')
# keymap-render.png must match the layout table compiled into Plymouth; the installer copies
# the packaged one next to this icon.
render(svg(32, 22, '<rect x="1" y="1" width="30" height="20" rx="4" fill="none" stroke="#b69af7" stroke-width="1.5"/>'
           + ''.join(f'<rect x="{x}" y="{y}" width="3" height="3" rx=".8" fill="#b69af7"/>' for x in range(6, 26, 5) for y in (6, 11))
           + '<rect x="9" y="15.5" width="14" height="2.5" rx="1" fill="#b69af7"/>'), ply / 'keyboard.png')
