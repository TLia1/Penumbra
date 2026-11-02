"""The shell's JavaScript logic (tests/shell/*.test.mjs, run with Node), and its OKLCH maths
against palette.py's, so swatches in the shell are the colours penumbra-theme renders."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'share' / 'penumbra'))
import palette  # noqa: E402

NODE = shutil.which('node')


@unittest.skipUnless(NODE, 'needs Node.js')
class ShellLogic(unittest.TestCase):
    def test_suites(self):
        result = subprocess.run([NODE, '--test', str(ROOT / 'tests' / 'shell')],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_oklch_matches_palette_py(self):
        grid = [(L / 10, C / 20, H) for L in range(1, 10) for C in range(0, 8) for H in range(0, 360, 30)]
        script = ("import { load } from './tests/shell/load.mjs';"
                  "const O = load('oklch.js');"
                  "process.stdout.write(JSON.stringify(JSON.parse(process.argv[1]).map(c => O.color(...c))));")
        result = subprocess.run([NODE, '--input-type=module', '-e', script, json.dumps(grid)],
                                capture_output=True, text=True, cwd=ROOT, check=True)
        for color, shell in zip(grid, json.loads(result.stdout)):
            python = palette.oklch_to_hex(*color)
            # Python rounds halves to even, JavaScript up: a channel may differ by one.
            difference = max(abs(a - b) for a, b in zip(palette.rgb255(shell), palette.rgb255(python)))
            self.assertLessEqual(difference, 1, f'{color}: shell {shell}, palette.py {python}')


if __name__ == '__main__':
    unittest.main()
