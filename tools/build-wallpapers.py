#!/usr/bin/env python3
"""Render each wallpaper and a wordmark-free variant for the lock screen and greeter."""
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
assets = root / 'assets'
for name in ('wallpaper', 'wallpaper-dawn'):
    source = (assets / f'{name}.svg').read_text()
    # The wordmark blurs into a smudge on hyprlock and crowds the SDDM card.
    clean = re.sub(r'<g id="wordmark">.*?</g>\n', '', source, flags=re.S)
    assert clean.count('<text') == 0 and clean != source, f'wordmark group not found in {name}.svg'
    (assets / f'{name}-clean.svg').write_text(clean)
    for variant in (name, f'{name}-clean'):
        subprocess.run(['rsvg-convert', str(assets / f'{variant}.svg'), '-o', str(assets / f'{variant}.png')], check=True)
shutil.copyfile(assets / 'wallpaper-clean.png', root / 'system/usr/share/sddm/themes/nocturne/wallpaper.png')
