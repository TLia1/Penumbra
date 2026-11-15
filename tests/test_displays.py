"""Display discovery and mode trials with an isolated monitor config and compositor."""
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

HELPER = Path(__file__).resolve().parents[1] / 'bin/penumbra-displays'
HEAD = {
    'name': 'eDP-1', 'enabled': True, 'scale': 1.199219, 'transform': 'normal',
    'modes': [
        {'width': w, 'height': h, 'refresh': hz, 'preferred': hz == 144, 'current': current}
        for w, h, hz, current in [(1920, 1080, 144, True), (1920, 1080, 144, False),
                                  (1920, 1080, 60.000999, False), (1280, 720, 60, False)]
    ],
}


class Displays(unittest.TestCase):
    def setUp(self):
        self.api = runpy.run_path(str(HELPER))
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.config = Path(temp.name) / 'monitors.conf'
        self.config.write_text('# Desk\nmonitor_rule=name:^DP-2$,disable:1\n'
                               'monitor_rule=name:^eDP-1$,scale:1.2,width:1920,height:1080,refresh:144,vrr:1 # panel\n')
        mock = patch.dict(self.api['screens'].__globals__, CONFIG=self.config)
        mock.start()
        self.addCleanup(mock.stop)

    def screens(self):
        with patch.dict(self.api['screens'].__globals__, randr=lambda *args: json.dumps([HEAD])):
            return self.api['screens']()

    def test_physical_modes_and_effective_config(self):
        screen, = self.screens()
        self.assertEqual(screen['mode'], '1920x1080@144')
        self.assertEqual(screen['modes'], ['1920x1080@144', '1920x1080@60.001', '1280x720@60'])
        self.assertEqual(screen['scale'], 1.2)
        screen['mode'] = '1920x1080@60.001'
        self.assertIn('--mode', self.api['arguments']([screen]))
        self.api['save']([screen])
        text = self.config.read_text()
        self.assertIn('refresh:60.001', text)
        self.assertIn('vrr:1', text)
        self.assertIn(' # panel\n', text)
        self.assertIn('monitor_rule=name:^DP-2$,disable:1\n', text)

    def test_custom_mode_survives_save_and_reopen(self):
        screen, = self.screens()
        screen['mode'] = '1600x900@120'
        self.assertIn('--custom-mode', self.api['arguments']([screen]))
        self.api['save']([screen])
        reopened, = self.screens()
        self.assertEqual(reopened['mode'], '1920x1080@144')  # Active until Mango applies the file.
        self.assertIn('1600x900@120', reopened['modes'])
        self.assertEqual(reopened['customMode'], '1600x900@120')

    def test_timeout_restores_without_writing(self):
        original = self.screens()
        draft = [dict(original[0], mode='1280x720@60')]
        calls = []

        def randr(*args):
            calls.append(args)
            return json.dumps([HEAD]) if args == ('--json',) else ''

        before = self.config.read_bytes()
        with patch.dict(self.api['trial'].__globals__, randr=randr), \
                patch('select.select', return_value=([], [], [])), patch('builtins.print'):
            self.api['trial'](draft, original)
        self.assertEqual(calls[1][0], '--dryrun')
        self.assertIn('1280x720@60Hz', calls[2])
        self.assertIn('1920x1080@144Hz', calls[-1])
        self.assertEqual(self.config.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
