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


def pixels(*colours):
    """A picture made of COLOURS ({'#rrggbb': how many pixels}), as wallpaper_pixels gives it."""
    return [palette.rgb255(value) for colours in colours for value, n in colours.items() for _ in range(n)]


class WallpaperAccents(unittest.TestCase):
    def test_peaks_strongest_first(self):
        # Mostly dark, some teal, less orange, and a speck of green too faint to count.
        found = palette.wallpaper_accents(pixels({'#0b0b10': 4000, '#2a9d8f': 900, '#e76f51': 400, '#40c040': 5}))
        self.assertEqual(len(found), 2)
        self.assertLess(palette.angle(found[0]['hue'], palette.hex_to_oklch('#2a9d8f')[2]), 3)
        self.assertLess(palette.angle(found[1]['hue'], palette.hex_to_oklch('#e76f51')[2]), 3)
        for accent in found:
            self.assertTrue(0.35 <= accent['vividness'] <= 1.3)

    def test_at_most_four_and_apart(self):
        hues = [palette.oklch_to_hex(0.7, 0.12, hue) for hue in range(0, 360, 30)]
        found = palette.wallpaper_accents(pixels({value: 100 + i for i, value in enumerate(hues)}))
        self.assertEqual(len(found), 4)
        for i, a in enumerate(found):
            for b in found[i + 1:]:
                self.assertGreaterEqual(palette.angle(a['hue'], b['hue']), 30)

    def test_grey_gives_one_neutral_accent(self):
        for picture in (pixels({'#808080': 3000, '#202020': 1000}), pixels({'#000000': 100}), []):
            self.assertEqual(palette.wallpaper_accents(picture),
                             [{'hue': palette.BASE_HUE, 'vividness': palette.NEUTRAL_VIVIDNESS}])
        # A little colour in a grey picture gives the neutral accent its hue.
        found = palette.wallpaper_accents(pixels({'#808080': 3000, '#2a9d8f': 30}))
        self.assertEqual(len(found), 1)
        self.assertLess(palette.angle(found[0]['hue'], palette.hex_to_oklch('#2a9d8f')[2]), 3)

    @unittest.skipUnless(shutil.which('ffmpeg'), 'needs ffmpeg')
    def test_built_in_wallpapers(self):
        """Penumbra's wallpapers have hand-picked accents; the first is the picture's own hue."""
        shipped = json.loads((ROOT / 'share/penumbra/wallpaper-colors.json').read_text())
        self.assertEqual(set(shipped), {'wallpaper', 'wallpaper-dawn', 'wallpaper-eclipse'})
        for name, accents in shipped.items():
            with self.subTest(name=name):
                picture = palette.wallpaper_pixels(ROOT / 'assets' / f'{name}-clean.png')
                found = palette.wallpaper_accents(picture)
                self.assertEqual(palette.wallpaper_accents(picture), found)
                self.assertLess(palette.angle(found[0]['hue'], accents[0]['hue']), 10)
                self.assertTrue(1 <= len(accents) <= 4)
                for accent in accents:
                    self.assertEqual(set(accent), {'hue', 'vividness'})


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
        shutil.copy(ROOT / 'share/penumbra/wallpaper-colors.json', share)
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
                         {'mode': 'dark', 'colors': 'custom', 'hue': 190.0, 'vividness': 0.8, 'pick': 0,
                          'candidates': json.loads((ROOT / 'share/penumbra/wallpaper-colors.json').read_text())['wallpaper']})

    def wallpaper(self, name):
        state = self.home / '.local/state/penumbra'
        state.mkdir(parents=True, exist_ok=True)
        (state / 'wallpaper').write_text(name + '\n')

    def test_wallpaper_colours(self):
        shipped = json.loads((ROOT / 'share/penumbra/wallpaper-colors.json').read_text())['wallpaper-dawn']
        self.wallpaper('wallpaper-dawn')
        self.assertEqual(json.loads(self.theme('get'))['candidates'], shipped)
        self.theme('set', 'colors=wallpaper', 'pick=1')
        self.assertEqual(self.palette_json()['colors'], palette.generate(PALETTES['dark'], shipped[1]['hue'], shipped[1]['vividness']))
        # A pick past the last accent takes the last.
        self.theme('set', 'pick=3')
        self.assertEqual(self.palette_json()['colors'], palette.generate(PALETTES['dark'], shipped[-1]['hue'], shipped[-1]['vividness']))
        # A wallpaper that can't be read gives the default colours.
        self.wallpaper('/nowhere/gone.png')
        self.theme('restore')
        self.assertEqual(self.palette_json()['colors'], PALETTES['dark'])

    @unittest.skipUnless(shutil.which('ffmpeg'), 'needs ffmpeg')
    def test_new_wallpaper(self):
        """penumbra-wallpaper's hook: the theme takes the new wallpaper's strongest accent as it grows in."""
        image = self.home / 'Pictures' / 'sea.png'
        image.parent.mkdir()
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=0x2a9d8f:s=64x40', '-frames:v', '1',
                        str(image)], check=True)
        self.theme('set', 'colors=wallpaper', 'pick=1')
        self.wallpaper(str(image))
        found = json.loads(self.theme('wallpaper', str(image)))
        self.assertEqual(len(found), 1)
        self.assertLess(palette.angle(found[0]['hue'], palette.hex_to_oklch('#2a9d8f')[2]), 3)
        self.assertEqual(self.palette_json(), {'mode': 'dark', 'duration': 1400,
                                               'colors': palette.generate(PALETTES['dark'], found[0]['hue'], found[0]['vividness'])})
        self.assertEqual(json.loads(self.theme('get'))['pick'], 0)
        self.assertIn(f'cursor {self.palette_json()["colors"]["accent"]}',
                      (self.home / '.config/kitty/penumbra-colors.conf').read_text())
        # Found once, then read from the cache.
        cached = list((self.home / '.cache/penumbra/theme').glob('*.json'))
        self.assertEqual(len(cached), 1)
        self.assertEqual(json.loads(cached[0].read_text())['accents'], found)
        # A wallpaper that isn't the current one is only looked at.
        before = self.palette_json()
        self.assertEqual(json.loads(self.theme('wallpaper', 'wallpaper-eclipse')),
                         json.loads((ROOT / 'share/penumbra/wallpaper-colors.json').read_text())['wallpaper-eclipse'])
        self.assertEqual(self.palette_json(), before)

    def test_preview_only_touches_the_shell(self):
        before = self.files()
        self.theme('preview', 'mode=light', 'colors=custom', 'hue=30')
        self.assertEqual(self.files(), before)
        self.assertEqual(self.palette_json()['mode'], 'light')
        self.assertEqual(self.palette_json()['duration'], 160)
        self.assertEqual(json.loads(self.theme('get'))['mode'], 'dark')
        self.assertEqual(self.calls(), '')

    def test_bad_values_change_nothing(self):
        for args in (['mode=dim'], ['hue=400'], ['vividness=2'], ['colors=sunset'], ['pick=4'], ['pick=1.5'],
                     ['colors=custom', 'shade=red'], ['nonsense']):
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
