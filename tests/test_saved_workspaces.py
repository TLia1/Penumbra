"""Saved tasks keep their tag identity across displays and reuse distinct app windows."""
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = SourceFileLoader('workspaces', str(ROOT / 'bin/penumbra-workspaces'))
ws = module_from_spec(spec_from_loader(loader.name, loader))
loader.exec_module(ws)


def monitor(name, active):
    return dict(name=name, active=active, tags=[
        dict(index=i, is_active=i == 1, layout='DW' if i == 1 else 'T', client_count=0)
        for i in range(1, 5)])


def client(n, app, output, tags, **state):
    return dict(id=n, pid=n + 100, appid=app, monitor=output, tags=tags, **state)


class SavedWorkspaces(unittest.TestCase):
    def setUp(self):
        self.monitors = [monitor('DP-1', True), monitor('eDP-1', False)]
        self.clients = [client(1, 'kitty', 'DP-1', [1, 2]), client(2, 'kitty', 'eDP-1', [1]),
                        client(3, 'other', 'DP-1', [4]), client(4, 'pinned', 'DP-1', [1], is_global=True)]
        self.calls = []
        def mango(*args):
            if args == ('get', 'layouts'):
                return json.dumps({'layouts': [dict(symbol='DW', name='dwindle'), dict(symbol='T', name='tile')]})
            self.calls.append(args)
            if len(args) == 3:
                c = next(c for c in self.clients if args[2] == 'client,' + str(c['id']))
                action, *params = args[1].split(',')
                if action in ('tagcrossmon', 'tagsilent'):
                    c['tags'] = list(map(int, params[0].split('|')))
                if action == 'tagcrossmon':
                    c['monitor'] = params[1]
        self.enterContext(patch.object(ws, 'mango', side_effect=mango))
        self.enterContext(patch.object(ws, 'query', side_effect=lambda k: self.monitors if k == 'monitors' else self.clients))
        self.disabled = set()
        def randr(command, **kwargs):
            self.assertEqual(command, ['wlr-randr', '--json'])
            outputs = [dict(name=m['name'], enabled=m['name'] not in self.disabled) for m in self.monitors]
            return ws.subprocess.CompletedProcess(command, 0, json.dumps(outputs))
        self.enterContext(patch.object(ws.subprocess, 'run', side_effect=randr))
        self.enterContext(patch.dict(ws.os.environ, MANGO_INSTANCE_SIGNATURE='test-session'))
        self.store = Path(self.enterContext(tempfile.TemporaryDirectory())) / 'config/penumbra/workspaces.json'
        self.enterContext(patch.object(ws, 'STORE', self.store))

    def test_save_selected_tags_and_manage_named_profiles(self):
        selected = {('DP-1', 1), ('DP-1', 2), ('eDP-1', 1)}
        ws.manage('save', 'Work', selected, {'kitty': 'net.example.Terminal'})
        saved = self.store.read_bytes()
        profile = ws.load()['Work']
        self.assertEqual([(w['id'], w['tags'], w['desktop']) for w in profile['windows']],
                         [(1, [1, 2], 'net.example.Terminal'), (2, [1], 'net.example.Terminal')])
        self.assertEqual([p['layout'] for p in profile['places']], ['dwindle', 'tile', 'dwindle'])
        self.assertEqual(self.store.stat().st_mode & 0o777, 0o600)
        with self.assertRaisesRegex(ValueError, 'already exists'):
            ws.manage('save', 'Work', selected, {})
        with self.assertRaisesRegex(ValueError, 'available tags'):
            ws.manage('replace', 'Work', {('disconnected', 3)}, {})
        self.assertEqual(self.store.read_bytes(), saved)
        ws.manage('replace', 'Work', {('DP-1', 4)}, {})
        self.assertEqual(ws.manage('list', '', None, {})['profiles'],
                         [dict(name='Work', places=[['DP-1', 4]], windows=1)])
        ws.manage('delete', 'Work', None, {})
        self.assertEqual(ws.load(), {})

    def test_reuse_duplicate_apps_before_and_after_restart(self):
        recipe = ws.capture(None, {})
        windows = recipe['windows']
        # Swapped original windows on repeat restore, with an extra unrelated terminal.
        available = [client(5, 'kitty', 'DP-1', [1]), client(2, 'kitty', 'DP-1', [1]),
                     client(1, 'kitty', 'eDP-1', [1])]
        self.assertEqual([c['id'] for c in ws.window_matches(windows, available, True).values()], [1, 2])
        # After logging in again, reserve the exact placement for the later slot.
        available = [client(9, 'kitty', 'eDP-1', [1]), client(11, 'kitty', 'DP-1', [4])]
        assigned = ws.window_matches(windows, available, False)
        self.assertEqual([assigned[i]['id'] for i in range(2)], [11, 9])

    def test_docked_task_falls_back_without_drifting_on_repeat(self):
        profile = ws.capture({('DP-1', 1), ('DP-1', 2), ('eDP-1', 1)}, {})
        self.disabled.add('DP-1')
        enabled = ws.enabled_monitors()
        expected = ws.destinations(profile, enabled)
        self.assertEqual(expected['eDP-1', 1], ('eDP-1', 1))
        self.assertEqual(len(set(expected.values())), 3)
        enabled[0]['tags'][1]['client_count'] = 1
        self.assertEqual(expected, ws.destinations(profile, enabled))
        result = ws.restore(profile)
        self.assertTrue(result['complete'])
        self.assertTrue(result['remapped'])
        self.assertIn(('dispatch', 'tagcrossmon,2|3,eDP-1', 'client,1'), self.calls)
        self.assertEqual(self.calls[-1], ('dispatch', 'focusmon,eDP-1'))

    def test_partial_restore_can_be_retried_without_relaunching_existing_apps(self):
        profile = ws.capture(None, {})
        self.clients.pop(0)
        with patch.object(ws, 'open_missing_window', side_effect=ValueError('No matching window')) as launch:
            result = ws.restore(profile)
            self.assertFalse(result['complete'])
            self.assertIn('Restored 1 of 2', result['message'])
            launch.assert_called_once()
        self.clients.append(client(6, 'kitty', 'DP-1', [1]))
        with patch.object(ws, 'open_missing_window') as launch:
            self.assertTrue(ws.restore(profile)['complete'])
            launch.assert_not_called()

    def test_app_that_reopens_two_windows_only_launches_once(self):
        profile = ws.capture(None, {})
        self.clients.clear()
        def start(*args, **kwargs):
            self.clients.extend([client(10, 'kitty', 'DP-1', [1]), client(11, 'kitty', 'DP-1', [1])])
        with patch.object(ws.subprocess, 'Popen', side_effect=start) as launch:
            self.assertTrue(ws.restore(profile)['complete'])
            launch.assert_called_once()
        self.assertEqual([c['monitor'] for c in self.clients], ['DP-1', 'eDP-1'])


if __name__ == '__main__':
    unittest.main()
