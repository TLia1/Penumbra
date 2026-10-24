#!/usr/bin/env python3
"""Render the desktop wallpaper and a wordmark-free variant for the lock screen and greeter."""
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
assets = root / 'assets'
source = (assets / 'wallpaper.svg').read_text()
# The wordmark (rule + two text lines) blurs into a smudge on hyprlock and crowds the SDDM card.
clean = re.sub(r'<path d="M150 1330h56"[^>]*/>\n|<text [^>]*>[^<]*</text>\n', '', source)
assert clean.count('<text') == 0 and clean != source, 'wordmark not found in wallpaper.svg'
(assets / 'wallpaper-clean.svg').write_text(clean)
for name in ('wallpaper', 'wallpaper-clean'):
    subprocess.run(['rsvg-convert', str(assets / f'{name}.svg'), '-o', str(assets / f'{name}.png')], check=True)
shutil.copyfile(assets / 'wallpaper-clean.png', root / 'system/usr/share/sddm/themes/nocturne/wallpaper.png')
