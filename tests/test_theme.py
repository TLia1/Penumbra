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

    def test_harmonized_signals_lean_toward_the_accent(self):
        for mode in palette.MODES:
            for hue in range(0, 360, 30):
                plain = palette.generate(PALETTES[mode], hue, 1.0)
                blended = palette.generate(PALETTES[mode], hue, 1.0, harmonize=True)
                for name in palette.HARMONIZED:
                    with self.subTest(mode=mode, hue=hue, name=name):
                        L, C, H = palette.hex_to_oklch(plain[name])
                        L2, _, H2 = palette.hex_to_oklch(blended[name])
                        self.assertAlmostEqual(L, L2, delta=0.01)
                        if C > 0.02:  # a hue that means something
                            self.assertLessEqual(palette.angle(H, H2), palette.HARMONY + 3)  # 8-bit rounding
                            self.assertLessEqual(palette.angle(H2, hue), palette.angle(H, hue) + 3)
                # Everything else is the plain palette.
                self.assertEqual({k: v for k, v in blended.items() if k not in palette.HARMONIZED},
                                 {k: v for k, v in plain.items() if k not in palette.HARMONIZED})
        # A grey accent pulls nothing.
        grey = palette.generate(PALETTES['dark'], 150, 0, harmonize=True)
        self.assertEqual(grey, palette.generate(PALETTES['dark'], 150, 0))

    def test_icon_colours(self):
        self.assertEqual(palette.icon_colors(palette.BASE_HUE, 1.0), {c: c for c in palette.ICON_COLORS})
        teal = palette.icon_colors(190, 1.0)
        for old, new in teal.items():
            self.assertAlmostEqual(palette.hex_to_oklch(old)[0], palette.hex_to_oklch(new)[0], delta=0.01)
        self.assertEqual(len(set(teal.values())), 3)


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


def remove(path):
    """Remove the throwaway home. A fade's Hyprland steps may write there for a moment longer; once
    palette.json is gone they stop."""
    for _ in range(30):
        try:
            shutil.rmtree(path)
            return
        except OSError:
            time.sleep(0.1)
    shutil.rmtree(path)


class Command(unittest.TestCase):
    """penumbra-theme in a throwaway home with Penumbra's files installed as install.sh does."""

    def setUp(self):
        self.home = Path(tempfile.mkdtemp())
        self.addCleanup(remove, self.home)
        share = self.home / '.local/share/penumbra'
        shutil.copytree(ROOT / 'palette', share / 'palette')
        shutil.copy(ROOT / 'share/penumbra/palette.py', share)
        shutil.copy(ROOT / 'share/penumbra/wallpaper-colors.json', share)
        for name in ('penumbra-theme', 'penumbra-corners'):
            (self.home / '.local/bin').mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / 'bin' / name, self.home / '.local/bin')
        # The generated files where install.sh puts them, plus optional app themes.
        for template in TEMPLATES.rglob('*'):
            rel = template.relative_to(TEMPLATES)
            if template.is_file() and rel.parts[0] in ('config', 'share'):
                where = '.config' if rel.parts[0] == 'config' else '.local/share'
                target = self.home / where / Path(*rel.parts[1:])
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(ROOT / rel, target)
        shutil.copytree(ROOT / 'apps/bat/config', self.home / '.config', dirs_exist_ok=True)
        shutil.copytree(ROOT / 'apps/cava/config', self.home / '.config', dirs_exist_ok=True)
        shutil.copytree(ROOT / 'apps/lia-files/config', self.home / '.config', dirs_exist_ok=True)
        for version in ('gtk-3.0', 'gtk-4.0'):
            shutil.copy(ROOT / 'config' / version / 'settings.ini', self.home / '.config' / version)
        # The icon theme, as shipped and as installed, and VS Code's copy of the theme extension.
        shutil.copytree(ROOT / 'share/icons/Penumbra', share / 'icons/Penumbra')
        shutil.copytree(ROOT / 'share/icons/Penumbra', self.home / '.local/share/icons/Penumbra')
        self.vscode = self.home / '.vscode/extensions/penumbra.penumbra-theme-1.2.0'
        shutil.copytree(ROOT / 'apps/vscode/vsix/extension', self.vscode)
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

    def wait_for(self, check):
        """Wait up to 3 s for CHECK() to hold, for what penumbra-theme finishes in the background."""
        for _ in range(60):
            if check():
                return
            time.sleep(0.05)
        self.fail(f'gave up waiting; calls:\n{self.calls()}')

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
        self.assertIn(f"gradient_color_1 = '{light['accentDeep']}'", (config / 'cava/themes/penumbra').read_text())
        self.assertIn(f"gradient_color_4 = '{light['pink']}'", (config / 'cava/themes/penumbra').read_text())
        for version in ('gtk-3.0', 'gtk-4.0'):
            text = (config / version / 'settings.ini').read_text()
            self.assertIn('gtk-theme-name=Breeze\n', text)
            self.assertIn('gtk-application-prefer-dark-theme=false\n', text)
        # The shell keeps its compiled-in default; it reads palette.json.
        self.assertEqual((config / 'quickshell/penumbra/palette.js').read_bytes(),
                         (ROOT / 'config/quickshell/penumbra/palette.js').read_bytes())
        calls = self.calls()
        self.assertIn(f'pkill -USR2 -u {os.getuid()} -x cava', calls)
        for call in ('gsettings set org.gnome.desktop.interface color-scheme prefer-light',
                     'gsettings set org.gnome.desktop.interface gtk-theme Breeze',
                     'hyprctl eval hl.config(', 'dbus-send --session --type=signal /KGlobalSettings',
                     'pkill -USR1', 'fish -c set -U penumbra_theme',
                     f'nvim --server {self.home}/run/nvim.123.0 --remote-expr'):
            self.assertIn(call, calls)
        # bat's cache is rebuilt in the background.
        self.wait_for(lambda: 'bat cache --build' in self.calls())

    def test_custom_accent(self):
        self.theme('set', 'colors=custom', 'hue=190', 'vividness=0.8')
        colors = palette.generate(PALETTES['dark'], 190, 0.8)
        self.assertEqual(self.palette_json()['colors'], colors)
        self.assertIn(f'cursor {colors["accent"]}', (self.home / '.config/kitty/penumbra-colors.conf').read_text())
        self.assertEqual(json.loads(self.theme('get')),
                         {'mode': 'dark', 'colors': 'custom', 'hue': 190.0, 'vividness': 0.8, 'pick': 0,
                          'harmonize': False, 'auto': 'dark',
                          'candidates': json.loads((ROOT / 'share/penumbra/wallpaper-colors.json').read_text())['wallpaper']})

    def test_harmonize(self):
        self.theme('set', 'colors=custom', 'hue=190', 'harmonize=true')
        self.assertEqual(self.palette_json()['colors'], palette.generate(PALETTES['dark'], 190, 1.0, harmonize=True))
        self.assertIs(json.loads(self.theme('get'))['harmonize'], True)
        # Penumbra's own colours are never blended.
        self.theme('set', 'colors=default')
        self.assertEqual(self.palette_json()['colors'], PALETTES['dark'])

    def test_auto_mode(self):
        """mode=auto shows what auto= says; the shell sets that at sunrise and sunset."""
        self.theme('set', 'mode=auto', 'auto=light')
        self.assertEqual(self.palette_json()['mode'], 'light')
        self.assertIn("mode = 'light'", (self.home / '.config/nvim/lua/penumbra/palette.lua').read_text())
        self.theme('set', 'auto=dark', '--duration', '2000')
        self.assertEqual(self.palette_json(), {'mode': 'dark', 'duration': 2000, 'colors': PALETTES['dark']})
        self.assertEqual(json.loads(self.theme('get'))['mode'], 'auto')
        # auto= alone doesn't change a fixed mode.
        self.theme('set', 'mode=light')
        self.theme('set', 'auto=dark')
        self.assertEqual(self.palette_json()['mode'], 'light')

    def test_hyprland_borders_step(self):
        """Hyprland's borders step from the colours on screen to the new ones, after penumbra-theme returns."""
        self.theme('restore')
        before = self.calls().count('hyprctl eval hl.config({general')
        self.theme('set', 'colors=custom', 'hue=190')
        accent = palette.generate(PALETTES['dark'], 190, 1.0)['accent'][1:]
        self.wait_for(lambda: f'rgba({accent}ee)' in self.calls())
        steps = self.calls().count('hyprctl eval hl.config({general') - before
        self.assertTrue(2 <= steps <= 8, steps)
        # Without a fade, one step.
        before = self.calls().count('hyprctl eval hl.config({general')
        self.theme('set', 'colors=default', '--duration', '0')
        self.assertEqual(self.calls().count('hyprctl eval hl.config({general') - before, 1)

    def test_icons_follow_the_accent(self):
        live = self.home / '.local/share/icons/Penumbra'
        shipped = sorted(ROOT.joinpath('share/icons/Penumbra').rglob('*.svg'))
        self.theme('set', 'colors=custom', 'hue=190')
        teal = palette.icon_colors(190, 1.0)
        icons = ''.join(path.read_text() for path in live.rglob('*.svg'))
        for old, new in teal.items():
            self.assertNotIn(old, icons)
            self.assertIn(new, icons)
        self.assertIn('dbus-send --session --type=signal /KIconLoader', self.calls())
        # The shipped copy stays, and Penumbra's colours bring every icon back.
        self.theme('set', 'colors=default')
        for icon in shipped:
            rel = icon.relative_to(ROOT / 'share/icons/Penumbra')
            self.assertEqual((live / rel).read_bytes(), icon.read_bytes())
            self.assertEqual((self.home / '.local/share/penumbra/icons/Penumbra' / rel).read_bytes(), icon.read_bytes())

    def test_vscode_themes_follow(self):
        self.theme('set', 'colors=custom', 'hue=190')
        dark = palette.generate(PALETTES['dark'], 190, 1.0)
        light = palette.generate(PALETTES['light'], 190, 1.0)
        themes = self.vscode / 'themes'
        self.assertIn(dark['accent'], (themes / 'penumbra-color-theme.json').read_text())
        self.assertIn(light['accent'], (themes / 'penumbra-light-color-theme.json').read_text())
        # Open windows reload a theme only when it asks to be watched.
        manifest = json.loads((self.vscode / 'package.json').read_text())
        self.assertTrue(all(theme['_watch'] for theme in manifest['contributes']['themes']))

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
        for args in (['mode=dim'], ['auto=auto'], ['harmonize=maybe'], ['hue=400'], ['vividness=2'], ['colors=sunset'], ['pick=4'], ['pick=1.5'],
                     ['colors=custom', 'shade=red'], ['nonsense']):
            with self.subTest(args=args):
                self.theme('set', *args, code=2 if '=' in args[0] else 1)
        self.assertFalse((self.home / '.local/state/penumbra/theme.json').exists())

    def test_lia_files_follows_palette_and_flatpak(self):
        native = self.home / '.config/lia-files/penumbra.css'
        sandbox = self.home / '.var/app/io.github.lia.Files'
        flat_css = sandbox / 'config/lia-files/penumbra.css'
        flat_css.parent.mkdir(parents=True)
        flat_css.write_text(native.read_text())
        schemes = sandbox / 'data/gtksourceview-5/styles'
        schemes.mkdir(parents=True)
        for name in ('penumbra.xml', 'penumbra-light.xml'):
            shutil.copy(ROOT / 'share/gtksourceview-5/styles' / name, schemes / name)
        self.theme('set', 'mode=light', 'colors=custom', 'hue=190')
        colors = self.palette_json()['colors']
        self.assertIn('--accent-color: ' + colors['accent'], native.read_text())
        self.assertIn('--window-bg-color: ' + colors['surface'], native.read_text())
        self.assertEqual(native.read_text(), flat_css.read_text())
        self.assertIn(colors['base'], (schemes / 'penumbra-light.xml').read_text())

    def test_lia_files_corners_restore_and_round_trip(self):
        config = self.home / '.config/lia-files'
        result = subprocess.run([str(ROOT / 'bin/penumbra-corners'), 'sharp'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--lia-radius: 0px', (config / 'corners.css').read_text())
        self.assertIn('window.lia-window.csd', (config / 'corners.css').read_text())
        self.theme('set', 'mode=light')
        self.assertIn('--lia-radius: 0px', (config / 'corners.css').read_text())
        result = subprocess.run([str(ROOT / 'bin/penumbra-corners'), 'rounded'],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('--lia-radius:', (config / 'corners.css').read_text())

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
