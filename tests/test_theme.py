"""The palette engine (share/penumbra/palette.py) and penumbra-theme, which renders it into your files."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / 'palette' / 'templates'
sys.path.insert(0, str(ROOT / 'share' / 'penumbra'))
sys.dont_write_bytecode = True
import palette  # noqa: E402

PALETTES = palette.load(ROOT / 'palette' / 'palette.toml')


class Engine(unittest.TestCase):
    def test_default_hue_gives_the_default_palette(self):
        for mode in palette.MODES:
            with self.subTest(mode=mode):
                self.assertEqual(palette.generate(PALETTES[mode], palette.BASE_HUE, 1.0), PALETTES[mode])

    def test_light_templates_render(self):
        for template in sorted(p for p in TEMPLATES.rglob('*') if p.is_file()):
            with self.subTest(template=template.relative_to(TEMPLATES)):
                text = palette.render(template.read_text(), PALETTES, 'light', template)
                self.assertNotIn('{{', text)

    def test_contrast_everywhere(self):
        """Both modes' defaults, and every accent at every vividness, keep the guarded contrasts."""
        cases = [(mode, None, None) for mode in palette.MODES]
        cases += [(mode, hue, vividness) for mode in palette.MODES for hue in range(0, 360, 10)
                  for vividness in (0, 0.5, 1, 1.3)]
        for mode, hue, vividness in cases:
            colors = PALETTES[mode] if hue is None else palette.generate(PALETTES[mode], hue, vividness)
            for a, b, least in palette.GUARDS:
                with self.subTest(mode=mode, hue=hue, vividness=vividness, pair=(a, b)):
                    self.assertGreaterEqual(palette.contrast(colors[a], colors[b]), least)

    def test_colour_conversion_round_trips(self):
        for value in PALETTES['dark'].values():
            self.assertEqual(palette.oklch_to_hex(*palette.hex_to_oklch(value)), value)


# Stand-ins for the programs penumbra-theme tells about a change: each records how it was called.
STUB = '#!/bin/sh\necho "${0##*/} $*" >> "$HOME/calls"\n'
STUBS = ['gsettings', 'hyprctl', 'dbus-send', 'pkill', 'fish', 'nvim', 'bat']


class Command(unittest.TestCase):
    """penumbra-theme in a throwaway home with Penumbra's files installed as install.sh does."""

    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.home)
        share = self.home / '.local/share/penumbra'
        shutil.copytree(ROOT / 'palette', share / 'palette')
        shutil.copy(ROOT / 'share/penumbra/palette.py', share)
        for name in ('penumbra-theme', 'penumbra-corners'):
            (self.home / '.local/bin').mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / 'bin' / name, self.home / '.local/bin')
        # The generated files where install.sh puts them, and one app's: bat's.
        for template in TEMPLATES.rglob('*'):
            rel = template.relative_to(TEMPLATES)
            if template.is_file() and rel.parts[0] in ('config', 'share'):
                where = '.config' if rel.parts[0] == 'config' else '.local/share'
                target = self.home / where / Path(*rel.parts[1:])
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(ROOT / rel, target)
        shutil.copytree(ROOT / 'apps/bat/config', self.home / '.config', dirs_exist_ok=True)
        for version in ('gtk-3.0', 'gtk-4.0'):
            shutil.copy(ROOT / 'config' / version / 'settings.ini', self.home / '.config' / version)
        stubs = self.home / 'stubs'
        stubs.mkdir()
        for name in STUBS:
            (stubs / name).write_text(STUB)
            (stubs / name).chmod(0o755)
        runtime = self.home / 'run'
        runtime.mkdir()
        (runtime / 'nvim.123.0').touch()
        self.env = {'HOME': str(self.home), 'PATH': f'{stubs}:{os.environ["PATH"]}',
                    'XDG_RUNTIME_DIR': str(runtime), 'HYPRLAND_INSTANCE_SIGNATURE': 'test'}

    def theme(self, *args, code=0):
        result = subprocess.run([str(self.home / '.local/bin/penumbra-theme'), *args],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, code, result.stdout + result.stderr)
        return result.stdout

    def files(self):
        return {p: p.read_bytes() for p in self.home.rglob('*')
                if p.is_file() and 'stubs' not in p.parts and '.local' not in p.parts and p.name != 'calls'}

    def calls(self):
        path = self.home / 'calls'
        return path.read_text() if path.exists() else ''

    def palette_json(self):
        return json.loads((self.home / '.local/state/penumbra/palette.json').read_text())

    def test_dark_default_changes_nothing(self):
        before = self.files()
        self.theme('restore')
        self.assertEqual(self.files(), before)
        self.assertEqual(self.palette_json(), {'mode': 'dark', 'duration': 0, 'colors': PALETTES['dark']})
        self.assertIn('gsettings set org.gnome.desktop.interface color-scheme prefer-dark', self.calls())

    def test_light_mode(self):
        self.theme('set', 'mode=light')
        light = PALETTES['light']
        self.assertEqual(json.loads(self.theme('get'))['mode'], 'light')
        self.assertEqual(self.palette_json()['colors'], light)
        self.assertEqual(self.palette_json()['duration'], 420)
        config = self.home / '.config'
        self.assertIn(f'background {light["base"]}', (config / 'kitty/penumbra-colors.conf').read_text())
        self.assertIn("mode = 'light'", (config / 'nvim/lua/penumbra/palette.lua').read_text())
        self.assertIn('mode = "light"', (config / 'hypr/colors.lua').read_text())
        self.assertIn(light['base'], (config / 'bat/themes/Penumbra.tmTheme').read_text())
        for version in ('gtk-3.0', 'gtk-4.0'):
            text = (config / version / 'settings.ini').read_text()
            self.assertIn('gtk-theme-name=Breeze\n', text)
            self.assertIn('gtk-application-prefer-dark-theme=false\n', text)
        # The shell keeps its compiled-in default; it reads palette.json.
        self.assertEqual((config / 'quickshell/penumbra/palette.js').read_bytes(),
                         (ROOT / 'config/quickshell/penumbra/palette.js').read_bytes())
        calls = self.calls()
        for call in ('gsettings set org.gnome.desktop.interface color-scheme prefer-light',
                     'gsettings set org.gnome.desktop.interface gtk-theme Breeze',
                     'hyprctl eval hl.config(', 'dbus-send --session --type=signal /KGlobalSettings',
                     'pkill -USR1', 'fish -c set -U penumbra_theme',
                     f'nvim --server {self.home}/run/nvim.123.0 --remote-expr'):
            self.assertIn(call, calls)
        # bat's cache is rebuilt in the background.
        for _ in range(50):
            if 'bat cache --build' in self.calls():
                break
            time.sleep(0.05)
        self.assertIn('bat cache --build', self.calls())

    def test_custom_accent(self):
        self.theme('set', 'colors=custom', 'hue=190', 'vividness=0.8')
        colors = palette.generate(PALETTES['dark'], 190, 0.8)
        self.assertEqual(self.palette_json()['colors'], colors)
        self.assertIn(f'cursor {colors["accent"]}', (self.home / '.config/kitty/penumbra-colors.conf').read_text())
        self.assertEqual(json.loads(self.theme('get')),
                         {'mode': 'dark', 'colors': 'custom', 'hue': 190.0, 'vividness': 0.8})

    def test_preview_only_touches_the_shell(self):
        before = self.files()
        self.theme('preview', 'mode=light', 'colors=custom', 'hue=30')
        self.assertEqual(self.files(), before)
        self.assertEqual(self.palette_json()['mode'], 'light')
        self.assertEqual(self.palette_json()['duration'], 160)
        self.assertEqual(json.loads(self.theme('get'))['mode'], 'dark')
        self.assertEqual(self.calls(), '')

    def test_bad_values_change_nothing(self):
        for args in (['mode=dim'], ['hue=400'], ['vividness=2'], ['colors=custom', 'shade=red'], ['nonsense']):
            with self.subTest(args=args):
                self.theme('set', *args, code=2 if '=' in args[0] else 1)
        self.assertFalse((self.home / '.local/state/penumbra/theme.json').exists())

    def test_sharp_corners_survive(self):
        state = self.home / '.local/state/penumbra'
        state.mkdir(parents=True)
        (state / 'corners').write_text('sharp\n')
        self.theme('set', 'mode=light')
        fastfetch = (self.home / '.config/fastfetch/config.jsonc').read_text()
        self.assertNotIn('╭', fastfetch)
        self.assertIn('corner-roundness = 0', (self.home / '.config/satty/config.toml').read_text())


if __name__ == '__main__':
    unittest.main()
