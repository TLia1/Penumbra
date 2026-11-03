"""Showcase capture owns only its unique windows, including on a failed capture."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('showcase', str(ROOT / 'bin/penumbra-showcase'))
spec = importlib.util.spec_from_loader(loader.name, loader)
showcase = importlib.util.module_from_spec(spec)
loader.exec_module(showcase)


class Showcase(unittest.TestCase):
    def capture(self, fail=False):
        calls, created = [], []
        def run(argv):
            calls.append(argv)
            if argv == ['hyprctl', '-j', 'monitors']:
                return json.dumps([{'name': 'DP-1', 'focused': True, 'activeWorkspace': {'id': 2}}])
            if argv == ['hyprctl', '-j', 'clients']:
                return json.dumps([{'class': 'personal-editor', 'address': '0xabc'}] +
                                  [{'class': cls, 'address': '0x' + str(i)} for i, cls in enumerate(created)])
            if argv[:2] == ['hyprctl', 'dispatch']:
                match = re.search(r'penumbra-showcase-[a-f0-9]+-[0-3]', argv[2])
                if 'exec_cmd' in argv[2] and match:
                    created.append(match[0])
                return 'ok'
            if argv[0] == 'grim':
                if fail:
                    raise RuntimeError('capture failed')
                Path(argv[-1]).write_bytes(b'PNG')
            return ''
        with tempfile.TemporaryDirectory() as temp, patch.object(showcase, 'run', side_effect=run), \
                patch.object(showcase.shutil, 'which', return_value='/bin/tool'), \
                patch.object(showcase.time, 'sleep'), \
                patch.object(showcase.sys, 'argv', ['penumbra-showcase', '--output', temp, '--delay', '0']):
            if fail:
                with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                    showcase.main()
            else:
                self.assertEqual(showcase.main(), 0)
                self.assertEqual(len(list(Path(temp).glob('*/desktop.png'))), 1)
        closes = [argv[2] for argv in calls if argv[:2] == ['hyprctl', 'dispatch'] and 'window.close' in argv[2]]
        self.assertEqual(len(closes), 4)
        self.assertFalse(any('0xabc' in expression for expression in closes))
        self.assertEqual(calls[-1], ['hyprctl', 'dispatch', 'hl.dsp.focus({workspace=2})'])

    def test_capture_and_restore(self):
        self.capture()

    def test_capture_failure_still_restores(self):
        self.capture(fail=True)

    def test_dry_run_does_not_connect(self):
        with patch.object(showcase, 'run') as run, patch.object(showcase.sys, 'argv', ['penumbra-showcase', '--dry-run']):
            self.assertEqual(showcase.main(), 0)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
