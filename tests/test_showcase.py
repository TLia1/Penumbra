"""Showcase capture owns only its unique windows, including on a failed capture."""
import importlib.machinery
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('showcase', str(ROOT / 'bin/penumbra-showcase'))
spec = importlib.util.spec_from_loader(loader.name, loader)
showcase = importlib.util.module_from_spec(spec)
loader.exec_module(showcase)


class Showcase(unittest.TestCase):
    def capture(self, fail=False):
        calls, created, terminals = [], [], []
        def launch(argv):
            created.append(argv[argv.index('--class') + 1])
            process = Mock()
            process.poll.return_value = None
            terminals.append(process)
            return process
        def run(argv):
            calls.append(argv)
            if argv == ['mmsg', 'get', 'all-monitors']:
                return json.dumps({'monitors': [{'name': 'DP-1', 'active': True, 'active_tags': [2, 3]}]})
            if argv == ['mmsg', 'get', 'all-clients']:
                return json.dumps({'clients': [{'appid': 'personal-editor', 'monitor': 'DP-1', 'tags': [1]}] +
                                   [{'appid': cls, 'monitor': 'DP-1', 'tags': [4]} for cls in created]})
            if argv[0] == 'grim':
                if fail:
                    raise RuntimeError('capture failed')
                Path(argv[-1]).write_bytes(b'PNG')
            return ''
        with tempfile.TemporaryDirectory() as temp, patch.object(showcase, 'run', side_effect=run), \
                patch.object(showcase.shutil, 'which', return_value='/bin/tool'), \
                patch.object(showcase.subprocess, 'Popen', side_effect=launch), patch.object(showcase.time, 'sleep'), \
                patch.object(showcase.sys, 'argv', ['penumbra-showcase', '--output', temp, '--delay', '0']):
            if fail:
                with self.assertRaisesRegex(RuntimeError, 'capture failed'):
                    showcase.main()
            else:
                self.assertEqual(showcase.main(), 0)
                self.assertEqual(len(list(Path(temp).glob('*/desktop.png'))), 1)
        self.assertIn(['mmsg', 'dispatch', 'view,4,0'], calls)
        self.assertEqual(len(terminals), 4)
        for terminal in terminals:
            terminal.terminate.assert_called_once_with()
        self.assertEqual(calls[-2:], [['mmsg', 'dispatch', 'viewcrossmon,2|3,DP-1'],
                                     ['mmsg', 'dispatch', 'focusmon,DP-1']])

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
