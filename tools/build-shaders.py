#!/usr/bin/env python3
"""Compile the shell's own shaders (config/quickshell/penumbra/shaders/*.frag) to the .qsb files
Qt loads; they ship compiled. Needs qsb from qt6-shadertools. --check only reports stale ones.
The wallpaper scenes' shaders are built by build-wallpapers.py."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
qsb = shutil.which('qsb') or '/usr/lib/qt6/bin/qsb'
check = '--check' in sys.argv[1:]
stale = []
for shader in sorted((root / 'config/quickshell/penumbra/shaders').glob('*.frag')):
    target = shader.with_name(shader.name + '.qsb')
    with tempfile.TemporaryDirectory() as tmp:
        built = Path(tmp) / target.name
        subprocess.run([qsb, '--qt6', '-o', str(built), str(shader)], check=True)
        if target.exists() and target.read_bytes() == built.read_bytes():
            continue
        stale.append(target.relative_to(root))
        if not check:
            shutil.copyfile(built, target)
for path in stale:
    print(f'{"stale" if check else "built"}: {path}')
sys.exit(1 if check and stale else 0)
