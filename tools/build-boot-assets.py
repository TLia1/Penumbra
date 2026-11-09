#!/usr/bin/env python3
"""Build original boot artwork from Penumbra's wallpaper and palette.
Needs Pillow, rsvg-convert (librsvg) and the Inter font, as the wallpapers do."""
from pathlib import Path
from PIL import Image
import math
import subprocess

root = Path(__file__).resolve().parents[1]
grub, ply, limine, refind = root / 'boot/grub', root / 'boot/plymouth', root / 'boot/limine', root / 'boot/refind'
for directory in (grub / 'icons', limine, refind / 'icons'):
    directory.mkdir(parents=True, exist_ok=True)


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


# ── Minimal OS & Utility Glyphs (24x24 viewBox) ──────────────────────────────
def icon_power(color='#f3eaff'):
    return (f'<path d="M12 3.5v7.5" fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round"/>'
            f'<path d="M7.0 5.8a8 8 0 1 0 10.0 0" fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round"/>')


def icon_reboot(color='#f3eaff'):
    return (f'<path d="M18.6 8.4A7.6 7.6 0 1 0 19.6 12" fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round"/>'
            f'<path d="M14.8 4.4h4.4v4.4" fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>')


def icon_firmware(color='#f3eaff'):
    pins = ''.join(
        f'<path d="M{p} 2.6v3.2M{p} 18.2v3.2M2.6 {p}h3.2M18.2 {p}h3.2" stroke="{color}" stroke-width="1.6" stroke-linecap="round"/>'
        for p in (8.5, 12, 15.5)
    )
    return (pins
            + f'<rect x="5.8" y="5.8" width="12.4" height="12.4" rx="2" fill="none" stroke="{color}" stroke-width="1.8"/>'
            + f'<rect x="8.8" y="8.8" width="6.4" height="6.4" rx="1" fill="none" stroke="{color}" stroke-width="1.4" opacity=".85"/>')


def icon_arch(color='#f3eaff'):
    return (f'<path fill="{color}" d="M12 2C11.1 4.2 10.5 5.6 9.5 7.7C10.1 8.4 10.9 9.1 12.1 9.9'
            'C10.8 9.4 9.9 8.8 9.2 8.2C7.9 10.9 5.9 14.9 2.2 21.6C5.3 19.8 7.7 18.7 10.0 18.3'
            'C9.9 17.7 9.8 17.0 9.8 16.3C9.8 14.0 10.9 12.1 12.2 12.1C13.5 12.1 14.6 14.0 14.6 16.3'
            'C14.6 17.0 14.5 17.7 14.4 18.3C16.7 18.7 19.1 19.8 21.8 21.6C21.2 20.5 20.6 19.3 20.0 18.3'
            'C19.1 17.6 18.2 16.8 16.3 15.9C17.6 16.2 18.5 16.7 19.2 17.2C15.6 10.3 15.2 9.4 12 2Z"/>')


def icon_windows(color='#f3eaff'):
    return (f'<rect x="3" y="3" width="8.2" height="8.2" rx="1.1" fill="{color}"/>'
            f'<rect x="12.8" y="3" width="8.2" height="8.2" rx="1.1" fill="{color}"/>'
            f'<rect x="3" y="12.8" width="8.2" height="8.2" rx="1.1" fill="{color}"/>'
            f'<rect x="12.8" y="12.8" width="8.2" height="8.2" rx="1.1" fill="{color}"/>')


def icon_linux(color='#f3eaff'):
    # Minimalist orbital planet glyph for generic Linux / kernel entries.
    return (f'<circle cx="12" cy="12" r="5.6" fill="none" stroke="{color}" stroke-width="2"/>'
            f'<ellipse cx="12" cy="12" rx="10.2" ry="3.4" transform="rotate(-26 12 12)" fill="none" stroke="{color}" stroke-width="1.8"/>')


def icon_recovery(color='#f3eaff'):
    return (f'<path d="M12 3l7.5 3.4v5.2c0 5-3.2 8.8-7.5 10.4C7.7 20.4 4.5 16.6 4.5 11.6V6.4L12 3z" '
            f'fill="none" stroke="{color}" stroke-width="1.9" stroke-linejoin="round"/>'
            f'<path d="M12 8.5v7M8.5 12h7" stroke="{color}" stroke-width="1.9" stroke-linecap="round"/>')


def icon_terminal(color='#f3eaff'):
    return (f'<rect x="3" y="4.5" width="18" height="15" rx="2.5" fill="none" stroke="{color}" stroke-width="1.9"/>'
            f'<path d="M7 9.5l3.2 2.8L7 15.1M12.2 15.1h4.5" fill="none" stroke="{color}" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>')


def render_icon(glyph_body, size, path, pad=0.18):
    inner = size * (1 - 2 * pad)
    offset = size * pad
    scale = inner / 24.0
    body = f'<g transform="translate({offset:.2f} {offset:.2f}) scale({scale:.4f})">{glyph_body}</g>'
    render(svg(size, size, body), path)


def corner_controls(x, y_start, step=72, scale=1.45, color='#e4dced', opacity=0.78):
    """Vertical trio of minimal Power, Reboot and UEFI Firmware icons in the bottom-left corner."""
    items = [icon_power(color), icon_reboot(color), icon_firmware(color)]
    return ''.join(
        f'<g transform="translate({x} {y_start + i * step}) scale({scale})" opacity="{opacity}">{glyph}</g>'
        for i, glyph in enumerate(items)
    )


def orbital_scene(width, height, cx, cy, r, with_corner_icons=True):
    rx, ry = r * 615 / 370, r * 188 / 370
    sx, sy = cx / width, cy / height
    star_list = [
        (int(width * .85), int(height * .28), 2, .55),
        (int(width * .29), int(height * .76), 1.5, .4),
        (int(width * .78), int(height * .80), 1.5, .3),
        (int(width * .22), int(height * .23), 1.2, .3),
        (int(width * .58), int(height * .21), 1.2, .25),
    ]
    controls = corner_controls(64, height - 248, step=72, scale=1.42) if with_corner_icons else ''
    return svg(
        width, height,
        f'<rect width="{width}" height="{height}" fill="url(#sky)"/>'
        f'<ellipse cx="{cx + 12}" cy="{cy + 18}" rx="{r * 1.5}" ry="{r * 1.3}" fill="#6e2cb9" opacity=".12" filter="url(#soft)"/>'
        f'<g transform="translate({cx} {cy}) rotate(-28)" fill="none" stroke="#7e4ab4" stroke-width="1">'
        f'<ellipse rx="{rx * 1.17}" ry="{ry * 1.3}" opacity=".14"/><ellipse rx="{rx * 1.27}" ry="{ry * 1.54}" opacity=".07"/></g>'
        + planet(cx, cy, r, rx, ry, -28, ring_width=2.4)
        + stars(star_list)
        + controls,
        sky(f'{sx:.2f}', f'{sy:.2f}') + planet_defs(rx, ry, 9),
    )


def selection_card_svg(size, radius, inset, bar_inset, bar_height):
    """Frosted translucent rounded card with a glowing violet bottom underline."""
    w = size - 2 * inset
    bar_y = size - inset - bar_height / 2 - 1
    defs = ('<filter id="barglow" x="-20%" y="-200%" width="140%" height="500%">'
            '<feGaussianBlur stdDeviation="2.5"/></filter>')
    body = (f'<rect x="{inset}" y="{inset}" width="{w}" height="{w}" rx="{radius}" '
            'fill="#140f22" fill-opacity=".68" stroke="#b69af7" stroke-opacity=".16" stroke-width="1"/>'
            f'<line x1="{bar_inset}" y1="{bar_y}" x2="{size - bar_inset}" y2="{bar_y}" '
            f'stroke="#a66ce9" stroke-width="{bar_height * 1.8:.1f}" stroke-linecap="round" opacity=".55" filter="url(#barglow)"/>'
            f'<line x1="{bar_inset}" y1="{bar_y}" x2="{size - bar_inset}" y2="{bar_y}" '
            f'stroke="#b69af7" stroke-width="{bar_height}" stroke-linecap="round"/>')
    return svg(size, size, body, defs)


# ── GRUB ─────────────────────────────────────────────────────────────────────
# Clean orbital background with the minimal bottom-left Power / Reboot / Firmware icons.
render(orbital_scene(1920, 1080, 1180, 520, 175, with_corner_icons=True), grub / 'background.png')

# Frosted rounded nine-slice selection box with glowing bottom underline.
card_path = grub / '_select_card.png'
render(selection_card_svg(size=64, radius=10, inset=1, bar_inset=10, bar_height=2.5), card_path)
card = Image.open(card_path).convert('RGBA')
card_path.unlink()
slices = {
    'nw': (0, 0, 12, 12),
    'n': (12, 0, 52, 12),
    'ne': (52, 0, 64, 12),
    'w': (0, 12, 12, 52),
    'c': (12, 12, 52, 52),
    'e': (52, 12, 64, 52),
    'sw': (0, 52, 12, 64),
    's': (12, 52, 52, 64),
    'se': (52, 52, 64, 64),
}
for name, box in slices.items():
    card.crop(box).save(grub / f'select_{name}.png')

# GRUB menu entry icons matched by `--class` (48x48 crisp white/lavender glyphs).
GRUB_ICONS = {
    'arch': icon_arch(),
    'archlinux': icon_arch(),
    'cachyos': icon_arch(),
    'endeavouros': icon_arch(),
    'manjaro': icon_arch(),
    'windows': icon_windows(),
    'windows11': icon_windows(),
    'windows10': icon_windows(),
    'gnu-linux': icon_linux(),
    'linux': icon_linux(),
    'os': icon_linux(),
    'ubuntu': icon_linux(),
    'debian': icon_linux(),
    'fedora': icon_linux(),
    'nixos': icon_linux(),
    'recovery': icon_recovery(),
    'memtest': icon_terminal(),
    'shutdown': icon_power(),
    'halt': icon_power(),
    'poweroff': icon_power(),
    'restart': icon_reboot(),
    'reboot': icon_reboot(),
    'uefi': icon_firmware(),
    'efi': icon_firmware(),
    'fwsetup': icon_firmware(),
}
for name, glyph in GRUB_ICONS.items():
    render_icon(glyph, 48, grub / 'icons' / f'{name}.png', pad=0.14)

# ── Limine ───────────────────────────────────────────────────────────────────
# Shown with `wallpaper_style: centered` on an EDGE backdrop: never stretched, so the planet
# stays round at any aspect ratio. Includes the minimal bottom-left utility icon strip.
render(orbital_scene(1920, 1080, 1300, 540, 155, with_corner_icons=True), limine / 'background.png')

# ── rEFInd ───────────────────────────────────────────────────────────────────
# Horizontal centered OS icon layout matching the reference screenshot:
# - 128x128 crisp white OS badges
# - 144x144 frosted rounded selection card with glowing violet underline
# - 48x48 minimal Shutdown, Reboot and UEFI Firmware icons
render(orbital_scene(1920, 1080, 960, 480, 180, with_corner_icons=False), refind / 'background.png')
render(selection_card_svg(size=144, radius=16, inset=4, bar_inset=22, bar_height=3.0), refind / 'selection_big.png')
render(selection_card_svg(size=64, radius=12, inset=4, bar_inset=14, bar_height=2.2), refind / 'selection_small.png')

REFIND_OS_ICONS = {
    'os_arch': icon_arch(),
    'os_cachyos': icon_arch(),
    'os_endeavouros': icon_arch(),
    'os_manjaro': icon_arch(),
    'os_win': icon_windows(),
    'os_win8': icon_windows(),
    'os_windows': icon_windows(),
    'os_linux': icon_linux(),
    'os_unknown': icon_linux(),
    'os_ubuntu': icon_linux(),
    'os_debian': icon_linux(),
    'os_fedora': icon_linux(),
    'os_nixos': icon_linux(),
}
for name, glyph in REFIND_OS_ICONS.items():
    render_icon(glyph, 128, refind / 'icons' / f'{name}.png', pad=0.20)

REFIND_TOOL_ICONS = {
    'func_shutdown': icon_power('#e4dced'),
    'func_reset': icon_reboot('#e4dced'),
    'func_firmware': icon_firmware('#e4dced'),
    'func_exit': icon_power('#e4dced'),
    'func_shell': icon_terminal('#e4dced'),
    'func_about': icon_linux('#e4dced'),
    'func_hidden': icon_recovery('#e4dced'),
    'tool_shell': icon_terminal('#e4dced'),
    'tool_memtest': icon_recovery('#e4dced'),
    'tool_fwupdate': icon_firmware('#e4dced'),
}
for name, glyph in REFIND_TOOL_ICONS.items():
    render_icon(glyph, 48, refind / 'icons' / f'{name}.png', pad=0.16)

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
