"""Coordinated art must survive still/animated/lock-screen paths."""
import json
from pathlib import Path
import re
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'share/penumbra'))
import artwork
import palette


class Artwork(unittest.TestCase):
    def test_variants_match_sources_and_layer_geometry(self):
        shell = ROOT / 'config/quickshell/penumbra'
        scenes = json.loads((shell / 'wallpapers.js').read_text().split('var scenes = ', 1)[1].rstrip(';\n'))
        for key, preset in palette.PRESETS.items():
            with self.subTest(preset=key):
                name = preset['wallpaper']
                source = artwork.SOURCES[key]
                svg = (ROOT / 'assets' / (name + '.svg')).read_text()
                if key != 'penumbra':
                    self.assertEqual(svg, artwork.recolor((ROOT / 'assets' / (source + '.svg')).read_text(), preset))
                clean = (ROOT / 'assets' / (name + '-clean.svg')).read_text()
                self.assertNotIn('<text', clean)
                self.assertNotIn('id="wordmark"', clean)
                for suffix in ['', '-clean']:
                    with Image.open(ROOT / 'assets' / (name + suffix + '.png')) as image:
                        self.assertEqual(image.size, (2560, 1600))
                meta = scenes[name]
                if not meta['scene']:
                    continue
                def layers(folder):
                    text = (shell / folder / 'layers.js').read_text()
                    return json.loads(re.search(r'var layers = (.*);', text)[1])
                # QML uses the original scene geometry with each variant's textures.
                self.assertEqual(layers(meta['folder']), layers(meta['scene']))
                for layer in layers(meta['folder']):
                    with Image.open(shell / meta['folder'] / (layer['name'] + '.png')) as image:
                        self.assertEqual(image.size, (layer['width'], layer['height']))

    def test_starlight_is_a_light_scene(self):
        with Image.open(ROOT / 'assets/wallpaper-starlight-clean.png') as image:
            sky = '#%02x%02x%02x' % image.convert('RGB').getpixel((2400, 100))
        self.assertGreater(palette.hex_to_oklch(sky)[0], .8)
