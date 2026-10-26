"""Every distribution folder gives install.sh what it needs, and every template fills in."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
DISTROS = sorted(p.parent.name for p in (ROOT / 'distro').glob('*/distro.sh'))
SETTINGS = 'settings=([kb_layout]=us [kb_variant]= [kb_options]= [scale]=auto [numlock]=on [shell]=fish)'


def bash(script, distro, *args):
    """Run `script` with install.sh's functions loaded for `distro`; `args` are "$@". HOME is a
    throwaway folder, so nothing can reach your own configuration."""
    with tempfile.TemporaryDirectory() as home:
        return subprocess.run(['bash', '-c', f'source "$0"; DISTRO=$1; shift; load_distro; {script}',
                               str(ROOT / 'install.sh'), distro, *args],
                              capture_output=True, text=True, env={**os.environ, 'HOME': home})


def templates(distro):
    """The text files install.sh fills in for `distro`."""
    files = [p for folder in (ROOT / 'config', ROOT / 'bin', ROOT / 'share', ROOT / 'distro' / distro)
             for p in folder.rglob('*') if p.is_file()]
    return [str(p) for p in files if b'@@' in p.read_bytes() and b'\0' not in p.read_bytes()]


class Distributions(unittest.TestCase):
    def test_arch_is_supported(self):
        self.assertIn('arch', DISTROS)

    def test_distro_sh_defines_everything(self):
        for distro in DISTROS:
            with self.subTest(distro=distro):
                result = bash('(( ${#PACKAGES[@]} ))', distro)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_updates_module(self):
        for distro in DISTROS:
            path = ROOT / 'distro' / distro / 'share/penumbra/updates.py'
            if not path.exists():
                continue
            with self.subTest(distro=distro):
                spec = importlib.util.spec_from_file_location('updates', path)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                for source in module.sources():
                    self.assertTrue(source['name'] and source['command'], source)
                self.assertIsInstance(module.notes(), list)
                self.assertTrue(all(name and command for name, command in module.upgrades()))

    def test_templates_fill_in(self):
        for distro in DISTROS:
            with self.subTest(distro=distro):
                result = bash(f'{SETTINGS}; set_placeholders; for f; do render_template "$f"; done',
                              distro, *templates(distro))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertNotRegex(result.stdout, r'@@[A-Z_]+@@')


if __name__ == '__main__':
    unittest.main()
