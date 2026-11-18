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
            if args[:2] == ('get', 'client'):
                return json.dumps(next(c for c in self.clients if c['id'] == int(args[2])))
            self.calls.append(args)
            if len(args) == 3:
                c = next(c for c in self.clients if args[2] == 'client,' + str(c['id']))
                action, *params = args[1].split(',')
                if action == 'tagsilent':
                    c['tags'] = list(map(int, params[0].split('|')))
                if action == 'tagmon':
                    c['monitor'] = params[0]
                if action == 'togglefloating':
                    c['is_floating'] = not c['is_floating']
                if action == 'resizewin':
                    c['width'], c['height'] = map(int, params)
                if action == 'movewin':
                    c['x'] += int(params[0])
                    c['y'] += int(params[1])
                if action == 'exchange_stack_client':
                    j = self.clients.index(c)
                    other = self.clients[j+1]
                    self.clients[j], self.clients[j+1] = other, c
                    for key in ('x', 'y', 'width', 'height'):
                        other[key], c[key] = c[key], other[key]
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
                         [dict(name='Work', places=[['DP-1', 4]], windows=1, project='',
                               apps=[dict(app='other', desktop='other', output='DP-1', tags=[4])])])
        ws.manage('delete', 'Work', None, {})
        self.assertEqual(ws.load(), {})

    def test_project_is_optional_and_only_used_for_supported_new_windows(self):
        folder = self.store.parents[2] / 'Project A'
        folder.mkdir()
        ws.manage('save', 'Work', None, {}, str(folder))
        ws.manage('replace', 'Work', None, {})
        self.assertEqual(ws.load()['Work']['project'], str(folder))
        self.assertEqual(ws.launch_command('kitty.desktop', str(folder)), ['kitty', '--directory', str(folder)])
        self.assertEqual(ws.launch_command('io.github.lia.Files', str(folder))[-1], folder.as_uri())
        self.assertEqual(ws.launch_command('firefox', str(folder)), ['gtk-launch', '--', 'firefox'])
        folder.rmdir()
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            ws.launch_command('kitty', str(folder))
        ws.manage('replace', 'Work', None, {}, '')
        self.assertNotIn('project', ws.load()['Work'])

    def test_editor_reopens_project_without_claiming_an_unrelated_editor(self):
        folder = self.store.parents[2] / 'Project A'
        folder.mkdir()
        self.clients[:] = [client(1, 'code-oss', 'DP-1', [1])]
        ws.manage('save', 'Editor', None, {}, str(folder))
        self.clients[:] = [client(2, 'code-oss', 'DP-1', [1])]
        def start(*args, **kwargs):
            self.clients.append(client(3, 'code-oss', 'DP-1', [1]))
        with patch.object(ws.subprocess, 'Popen', side_effect=start) as launch:
            self.assertTrue(ws.manage('restore', 'Editor', None, {})['complete'])
            self.assertEqual(launch.call_args.args[0][-3:], ['code-oss', '--new-window', str(folder)])
            self.assertTrue(ws.manage('restore', 'Editor', None, {})['complete'])
            launch.assert_called_once()
        self.assertEqual(ws.launch_command('code.desktop', str(folder)), ['code', '--new-window', str(folder)])
        self.assertEqual(ws.launch_command('code-oss', ''), ['gtk-launch', '--', 'code-oss'])

    def test_editor_that_activates_an_existing_project_window(self):
        folder = self.store.parents[2] / 'Project - A'
        folder.mkdir()
        self.clients[:] = [client(7, 'code-oss', 'DP-1', [1], is_focused=True,
                                  title='main.py - Project - A - Code - OSS')]
        window = dict(id=1, pid=101, app='code-oss', desktop='code-oss', output='DP-1', tags=[1])
        with (patch.object(ws.subprocess, 'Popen') as launch, patch.object(ws.time, 'sleep'),
              patch.object(ws.time, 'monotonic', side_effect=[0, 1, 11])):
            launch.return_value.poll.return_value = 0
            self.assertEqual(ws.open_missing_window(window, set(), str(folder))['id'], 7)

    def test_floating_geometry_scales_to_remapped_output_with_negative_origin(self):
        self.monitors[0].update(x=0, y=0, width=2000, height=1000)
        self.monitors[1].update(x=-1000, y=-100, width=1000, height=500)
        self.clients[:] = [client(1, 'kitty', 'DP-1', [1], x=200, y=100, width=800, height=600,
                                  is_floating=True, is_fullscreen=False, is_maximized=False, is_visible=True)]
        profile = ws.capture(None, {})
        self.disabled.add('DP-1')
        self.clients[0].update(x=-300, y=100, width=300, height=200, is_floating=False)
        self.assertTrue(ws.restore(profile)['complete'])
        self.assertEqual(ws.box(self.clients[0]), (-900, -50, 400, 300))
        self.assertTrue(self.clients[0]['is_floating'])
        self.calls.clear()
        self.assertTrue(ws.restore(profile)['complete'])
        self.assertFalse(any(args[1].startswith(('movewin', 'resizewin', 'togglefloating')) for args in self.calls))

    def test_tiled_windows_reopened_in_reverse_order_return_to_their_slots(self):
        self.monitors[0].update(x=0, y=0, width=900, height=600)
        common = dict(y=0, width=300, height=600, is_floating=False, is_fullscreen=False,
                      is_maximized=False, is_visible=True)
        self.clients[:] = [client(i, app, 'DP-1', [1], x=i*300, **common)
                           for i, app in enumerate(('code-oss', 'kitty', 'firefox'))]
        profile = ws.capture(None, {})
        self.clients[:] = [client(i+10, app, 'DP-1', [1], x=i*300, **common)
                           for i, app in enumerate(('firefox', 'kitty', 'code-oss'))]
        self.assertTrue(ws.restore(profile)['complete'])
        self.assertEqual([(c['appid'], c['x']) for c in self.clients],
                         [('code-oss', 0), ('kitty', 300), ('firefox', 600)])
        self.assertFalse(any(c['is_floating'] for c in self.clients))

    def test_dwindle_split_plan_preserves_asymmetric_nested_tiles(self):
        first, splits = ws.dwindle_splits({3: (710, 410, 280, 180), 1: (10, 10, 690, 580),
                                           2: (710, 10, 280, 390)})
        self.assertEqual(first, 1)
        self.assertEqual(splits, [(1, 2, 0, 690), (2, 3, 1, 390)])

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
        self.assertIn(('dispatch', 'tagmon,eDP-1', 'client,1'), self.calls)
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
