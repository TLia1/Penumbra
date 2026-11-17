import contextlib
import io
import json
import os
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

STATUS = Path(__file__).resolve().parents[1] / 'bin/penumbra-updates'


class Sources(unittest.TestCase):
    def test_failures_and_last_success_across_checks(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, XDG_CACHE_HOME=tmp):
            module = Path(tmp) / 'updates.py'
            module.write_text('def sources(): return [{"name": n, "command": [n]} for n in ("Arch", "Flatpak")]\n'
                              'def notes(): return []\n')
            def status(results):
                fn = runpy.run_path(str(STATUS))['status']
                with patch.dict(fn.__globals__, DISTRO=module, check=lambda cmd, *_: results[cmd[0]]), \
                        patch('shutil.which', return_value=None), contextlib.redirect_stdout(io.StringIO()) as out:
                    fn()
                return json.loads(out.getvalue())

            initial = status({'Arch': None, 'Flatpak': None})
            self.assertTrue(initial['incomplete'])
            self.assertIn('Couldn’t check Arch', initial['headline'])
            self.assertIsNone(initial['sources'][0]['lastSuccess'])
            clear = status({'Arch': [], 'Flatpak': []})
            self.assertFalse(clear['incomplete'])
            self.assertEqual(clear['headline'], '0 updates')
            partial = status({'Arch': ['one', 'two'], 'Flatpak': None})
            self.assertEqual(partial['headline'], '2 updates · Flatpak unavailable')
            self.assertEqual(partial['sources'][1]['status'], 'unavailable')
            self.assertTrue(clear['sources'][1]['lastSuccess'])
            self.assertEqual(partial['sources'][1]['lastSuccess'], clear['sources'][1]['lastSuccess'])
