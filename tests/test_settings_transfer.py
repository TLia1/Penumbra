"""Portable defaults, opt-ins and preview/apply against different XDG roots."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CLI = Path(__file__).resolve().parents[1] / 'bin/penumbra-settings'


class Transfer(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        home = Path(tmp.name)
        self.file = home / 'backup.json'
        self.shell = home / 'config/penumbra/shell.json'
        self.shell.parent.mkdir(parents=True)
        self.settings = self.shell.with_name('settings.conf')
        self.settings.write_text('terminal=foot\n')
        self.shell.write_text(json.dumps({'clipboardPins': ['secret'], 'weatherPlace': 'Paris',
                                          'nightPlace': 'Berlin', 'reducedMotion': True,
                                          'downloads': {'kind': 'audio', 'audioFolder': '/private'}}))
        self.monitors = home / 'config/mango/monitors.conf'
        self.monitors.parent.mkdir()
        self.monitors.write_text('monitor_rule=name:eDP-1,scale:1.5\n')
        theme = home / 'state/penumbra/theme.json'
        theme.parent.mkdir(parents=True)
        theme.write_text('{"mode":"light"}')
        self.env = {**os.environ, 'HOME': tmp.name, 'XDG_CONFIG_HOME': str(home / 'config'),
                    'XDG_STATE_HOME': str(home / 'state'), 'MANGO_INSTANCE_SIGNATURE': '',
                    'DBUS_SESSION_BUS_ADDRESS': 'unix:path=/nonexistent', 'XDG_RUNTIME_DIR': tmp.name}

    def cli(self, command, *args, check=True):
        return subprocess.run([CLI, command, self.file, *args], env=self.env, capture_output=True,
                              text=True, check=check)

    def test_default_export_and_merge(self):
        self.cli('export')
        files = json.loads(self.file.read_text())['files']
        self.assertEqual(set(files), {'settings.conf', 'theme.json', 'shell.json'})
        self.assertEqual(json.loads(files['shell.json']), {'reducedMotion': True, 'downloads': {'kind': 'audio'}})
        self.assertIn('terminal=foot', files['settings.conf'])
        self.assertEqual(self.file.stat().st_mode & 0o777, 0o600)
        original = '{"clipboardPins":["keep me"],"downloads":{"audioFolder":"/elsewhere"}}'
        self.shell.write_text(original)
        preview = json.loads(self.cli('import', '--json-preview').stdout)
        self.assertIn('reducedMotion', preview['summary'])
        self.assertEqual(self.shell.read_text(), original)
        self.cli('import', '--apply', '--reviewed', preview['token'])
        result = json.loads(self.shell.read_text())
        self.assertEqual(result['clipboardPins'], ['keep me'])
        self.assertEqual(result['downloads'], {'kind': 'audio', 'audioFolder': '/elsewhere'})
        self.assertEqual(self.shell.with_suffix('.json.bak').read_text(), original)
        self.assertIn('No changes', self.cli('import').stdout)

    def test_independent_opt_ins_and_legacy_import(self):
        for flag, expected in [('--clipboard-pins', {'clipboardPins'}), ('--location', {'nightPlace', 'weatherPlace'}),
                               ('--monitors', set())]:
            self.cli('export', flag)
            files = json.loads(self.file.read_text())['files']
            self.assertEqual(set(json.loads(files['shell.json'])) - {'reducedMotion', 'downloads'}, expected)
            self.assertEqual('monitors.conf' in files, flag == '--monitors')
        self.file.write_text(json.dumps({'penumbra': 1, 'files': {'shell.json': self.shell.read_text(),
                                             'monitors.lua': 'obsolete', 'monitors.conf': self.monitors.read_text()}}))
        self.shell.write_text('{}')
        self.monitors.unlink()
        self.cli('import', '--apply')
        self.assertNotIn('clipboardPins', json.loads(self.shell.read_text()))
        self.assertFalse(self.monitors.exists())
        preview = json.loads(self.cli('import', '--clipboard-pins', '--json-preview').stdout)
        self.shell.write_text('{"reducedMotion":false}')
        self.assertNotEqual(self.cli('import', '--clipboard-pins', '--apply', '--reviewed',
                                     preview['token'], check=False).returncode, 0)
        self.cli('import', '--clipboard-pins', '--location', '--monitors', '--apply')
        self.assertTrue(self.monitors.exists())
        self.assertEqual(json.loads(self.shell.read_text())['clipboardPins'], ['secret'])

    def test_validate_all_files_before_apply(self):
        original = self.settings.read_text()
        self.file.write_text(json.dumps({'penumbra': 1, 'files': {'settings.conf': 'terminal=kitty\n',
                                                                   'shell.json': '[]'}}))
        self.assertNotEqual(self.cli('import', '--apply', check=False).returncode, 0)
        self.assertEqual(self.settings.read_text(), original)
