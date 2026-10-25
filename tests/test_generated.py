"""The generated colour files and CONFIGURATION.md match their sources."""
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent


class GeneratedFiles(unittest.TestCase):
    def check(self, tool):
        result = subprocess.run([sys.executable, str(ROOT / 'tools' / tool), '--check'],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_palette_files_are_current(self):
        self.check('build-palette.py')

    def test_configuration_md_is_current(self):
        self.check('build-configuration.py')


if __name__ == '__main__':
    unittest.main()
