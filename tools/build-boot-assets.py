#!/usr/bin/env python3
"""Build original boot artwork from Penumbra's existing wallpaper and palette."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

root = Path(__file__).resolve().parents[1]
grub, ply = root / 'boot/grub', root / 'boot/plymouth'
font = '/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf'
if not Path(font).exists():
    font = '/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf'
Image.open(root / 'assets/wallpaper.png').convert('RGB').resize((1600, 1000)).save(grub / 'background.png')
# GRUB selected-entry nine-slice frame, entirely original artwork.
for name, size in [('c', (8, 8)), ('n', (8, 3)), ('s', (8, 3)), ('e', (3, 8)), ('w', (3, 8)),
                   ('nw', (3, 3)), ('ne', (3, 3)), ('sw', (3, 3)), ('se', (3, 3))]:
    Image.new('RGBA', size, '#352348' if name == 'c' else '#78579b').save(grub / f'select_{name}.png')
for frame in range(1, 31):
    im = Image.new('RGBA', (240, 140))
    d = ImageDraw.Draw(im)
    d.ellipse((78, 28, 162, 112), fill='#100d18', outline='#57406c', width=2)
    d.ellipse((24, 45, 216, 95), outline='#78579b', width=2)
    angle = 2 * math.pi * (frame - 1) / 30
    x, y = 120 + 96 * math.cos(angle), 70 + 25 * math.sin(angle)
    d.ellipse((x-4, y-4, x+4, y+4), fill='#dac5ff')
    for prefix in ('throbber', 'animation'):
        im.save(ply / f'{prefix}-{frame:04}.png')
watermark = Image.new('RGBA', (500, 80))
d = ImageDraw.Draw(watermark)
d.text((250, 12), 'N O C T U R N E', font=ImageFont.truetype(font, 24), anchor='mt', fill='#b69af7')
d.text((250, 50), 'A QUIETER ORBIT.', font=ImageFont.truetype(font, 11), anchor='mt', fill='#8f809f')
watermark.save(ply / 'watermark.png')
for name, size in [('entry', (320, 42)), ('bullet', (10, 10)), ('lock', (32, 40)), ('capslock', (24, 24)), ('keyboard', (32, 22)), ('keymap-render', (32, 22))]:
    im = Image.new('RGBA', size)
    d = ImageDraw.Draw(im)
    if name == 'entry':
        d.rounded_rectangle((0, 0, 319, 41), radius=8, fill='#100d18', outline='#b69af7', width=2)
    elif name == 'bullet':
        d.ellipse((2, 2, 8, 8), fill='#dac5ff')
    elif name == 'lock':
        d.arc((8, 2, 24, 24), 180, 360, fill='#b69af7', width=3)
        d.rounded_rectangle((3, 17, 29, 37), radius=4, fill='#b69af7')
    elif name == 'capslock':
        d.polygon([(12, 2), (22, 12), (17, 12), (17, 17), (7, 17), (7, 12), (2, 12)], fill='#b69af7')
        d.rectangle((7, 20, 17, 22), fill='#b69af7')
    else:
        d.rounded_rectangle((0, 0, 31, 21), radius=3, outline='#b69af7')
        for x in range(5, 28, 6):
            for y in (6, 12): d.rectangle((x, y, x+2, y+2), fill='#b69af7')
    im.save(ply / f'{name}.png')
