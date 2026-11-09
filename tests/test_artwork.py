"""Coordinated art must survive still/animated/lock-screen paths."""
import json
from pathlib import Path
import re
import struct
import sys
import unittest
try:
    from PIL import Image
except ImportError:
    Image = None

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'share/penumbra'))
sys.dont_write_bytecode = True
import artwork
import palette


def png_size(path):
    if Image is not None:
        with Image.open(path) as image:
            return image.size
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR'
    return struct.unpack('>II', data[16:24])


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
                    self.assertEqual(png_size(ROOT / 'assets' / (name + suffix + '.png')), (2560, 1600))
                meta = scenes[name]
                if not meta['scene']:
                    continue
                def layers(folder):
                    text = (shell / folder / 'layers.js').read_text()
                    return json.loads(re.search(r'var layers = (.*);', text)[1])
                # QML uses the original scene geometry with each variant's textures.
                self.assertEqual(layers(meta['folder']), layers(meta['scene']))
                for layer in layers(meta['folder']):
                    self.assertEqual(png_size(shell / meta['folder'] / (layer['name'] + '.png')),
                                     (layer['width'], layer['height']))

    def test_starlight_is_a_light_scene(self):
        path = ROOT / 'assets/wallpaper-starlight-clean.png'
        if Image is not None:
            with Image.open(path) as image:
                rgb = image.convert('RGB').getpixel((2400, 100))
        else:
            rgb = palette.wallpaper_pixels(path)[6 * 96 + 90]
        sky = '#%02x%02x%02x' % rgb
        self.assertGreater(palette.hex_to_oklch(sky)[0], .8)


if __name__ == '__main__':
    unittest.main()
