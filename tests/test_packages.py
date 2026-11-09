"""Inventory parsing and safe action routing; never change installed software."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('packages', str(ROOT / 'bin/penumbra-packages'))
spec = importlib.util.spec_from_loader(loader.name, loader)
p = importlib.util.module_from_spec(spec)
loader.exec_module(p)


class Packages(unittest.TestCase):
    def test_pacman_foreign_and_multiline_details(self):
        info = ('Name            : native\nVersion         : 1.2\nDescription     : First line\n'
                '                  second line\nDepends On      : libc>=2  virtual-lib  libvirt.so=1-64\nRequired By     : local-build\n                  another\nOptional Deps   : extra: useful feature\n                  local-build: another feature [installed]\nOptional For    : None\nInstalled Size  : 20 MiB\nInstall Reason  : Explicitly installed\n\n'
                'Name            : local-build\nVersion         : 2.0\nDescription     : Local\nProvides        : virtual-lib=2.0  libvirt.so=1-64\nInstalled Size  : 512 KiB\nInstall Reason  : Installed as a dependency for another package\n')
        with patch.object(p, 'query', side_effect=['local-build\n', info]):
            records = p.pacman_records()
        self.assertEqual([r['source'] for r in records], ['pacman', 'aur'])
        self.assertEqual(records[0]['description'], 'First line second line')
        self.assertEqual(records[0]['dependencies'], 'libc>=2 · virtual-lib · libvirt.so=1-64')
        self.assertEqual(records[0]['required_by'], 'local-build · another')
        self.assertEqual(records[0]['optional_dependencies'], 'extra: useful feature\nlocal-build: another feature [installed]')
        self.assertEqual(records[0]['optional_for'], 'None')
        self.assertNotIn('Depends On:', records[0]['details'])
        self.assertEqual(records[1]['dependencies'], 'Unavailable')
        self.assertTrue(records[0]['explicit'])
        self.assertFalse(records[1]['explicit'])
        self.assertEqual(records[0]['size_bytes'], 20 * 1024 * 1024)
        self.assertEqual(records[1]['size_bytes'], 512 * 1024)
        # Virtual and soname dependencies resolve to the providing package and deduplicate by key.
        self.assertEqual(records[0]['dependency_links'], [
            {'name': 'libc', 'label': 'libc>=2', 'token': 'libc>=2', 'key': '', 'installed': False},
            {'name': 'local-build', 'label': 'local-build (virtual-lib)', 'token': 'virtual-lib', 'key': 'aur:local-build', 'installed': True},
        ])
        self.assertEqual(records[0]['required_by_links'][0]['key'], 'aur:local-build')
        self.assertEqual(records[0]['optional_dependency_links'], [
            {'name': 'extra', 'label': 'extra', 'token': 'extra', 'key': '', 'installed': False, 'description': 'useful feature'},
            {'name': 'local-build', 'label': 'local-build', 'token': 'local-build', 'key': 'aur:local-build', 'installed': True, 'description': 'another feature'},
        ])

    def test_flatpak_scope_branch_and_kind_are_preserved(self):
        with patch.object(p, 'query', side_effect=[
                'org.example.App/x86_64/stable\tExample\t1\tflathub\tuser\t1 MB\torg.example.Runtime/x86_64/1\n'
                'org.example.App/x86_64/beta\tExample\t2\tflathub\twork\t2 MB\torg.example.Runtime/x86_64/2\n',
                'org.example.Runtime/x86_64/1\tRuntime\t\tflathub\tsystem\t3 MB\n']):
            records = p.flatpak_records()
        self.assertEqual(len({r['key'] for r in records}), 3)
        self.assertEqual(records[0]['dependencies'], 'org.example.Runtime/x86_64/1 (system)')
        self.assertEqual(records[0]['dependency_links'][0]['key'], records[2]['key'])
        self.assertIn('app/org.example.App/x86_64/stable (user)', records[2]['required_by'])
        self.assertEqual(records[2]['required_by_links'][0]['key'], records[0]['key'])
        self.assertNotIn('beta', records[2]['required_by'])
        self.assertIn('installation not resolved', records[1]['dependencies'])
        self.assertFalse(records[1]['dependency_links'][0]['installed'])
        self.assertEqual(p.action_command(records[1], 'remove'),
                         ['flatpak', 'uninstall', '--installation=work', '--', 'app/org.example.App/x86_64/beta'])
        self.assertEqual(p.action_command(records[2], 'update')[-1], 'runtime/org.example.Runtime/x86_64/1')

    def test_flatpak_prefers_same_installation_runtime(self):
        with patch.object(p, 'query', side_effect=[
                'org.App/x86_64/stable\tApp\t1\tremote\tuser\t1 MB\torg.Runtime/x86_64/1\n',
                'org.Runtime/x86_64/1\tRuntime\t1\tremote\tuser\t1 MB\t\n'
                'org.Runtime/x86_64/1\tRuntime\t1\tremote\tsystem\t1 MB\t\n']):
            records = p.flatpak_records()
        self.assertIn('(user)', records[0]['dependencies'])
        self.assertIn('app/org.App', records[1]['required_by'])
        self.assertNotIn('app/org.App', records[2]['required_by'])

    def test_partial_inventory_survives_backend_failure(self):
        with patch.object(p.shutil, 'which', return_value='/bin/tool'), \
             patch.object(p, 'pacman_records', side_effect=RuntimeError('database unavailable')), \
             patch.object(p, 'flatpak_records', return_value=[{'name': 'App', 'key': 'one'}]), \
             patch.object(p, 'appimage_records', return_value=([], [])):
            data = p.inventory()
        self.assertEqual(len(data['packages']), 1)
        self.assertIn('database unavailable', data['errors'][0])

    def test_appimage_discovery_deduplicates_and_keeps_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            file = root / 'An app;$(touch nope).AppImage'
            file.write_bytes(b'example')
            link = root / 'Shortcut.AppImage'
            link.symlink_to(file)
            (root / 'ignored.txt').touch()
            with patch.object(p, 'appimage_roots', return_value=[root, root]):
                records, errors = p.appimage_records()
            self.assertFalse(errors)
            self.assertEqual(len(records), 2)
            record = next(r for r in records if r['name'] == link.name)
            self.assertEqual(p.action_command(record, 'remove'), ['gio', 'trash', '--', str(link)])
            self.assertTrue(file.exists())
            self.assertIn('Unavailable', record['dependencies'])
            self.assertIn('not tracked', record['required_by'])

    def test_upgrade_is_full_system_and_removal_is_not_recursive(self):
        record = {'source': 'pacman', 'target': 'example'}
        with patch.object(p.shutil, 'which', return_value=None):
            self.assertEqual(p.action_command(record, 'update'), ['sudo', 'pacman', '-Syu'])
            self.assertEqual(p.action_command(record, 'remove'), ['sudo', 'pacman', '-R', '--', 'example'])
            with self.assertRaisesRegex(RuntimeError, 'paru or yay'):
                p.action_command({**record, 'source': 'aur'}, 'update')
        with patch.object(p.shutil, 'which', return_value='/usr/bin/paru'):
            self.assertEqual(p.action_command(record, 'update'), ['/usr/bin/paru', '-Syu'])

    def test_missing_package_never_runs_action(self):
        with patch.object(p, 'inventory', return_value={'packages': [], 'errors': []}), \
             patch.object(p.subprocess, 'call') as call:
            with self.assertRaisesRegex(RuntimeError, 'no longer available'):
                p.manage('pacman:gone', 'remove')
            call.assert_not_called()

    def test_appimage_removal_can_be_cancelled(self):
        record = dict(key='appimage:/tmp/a.AppImage', source='appimage', target='/tmp/a.AppImage',
                      name='a', details='test')
        with patch.object(p, 'inventory', return_value={'packages': [record], 'errors': []}), \
             patch('builtins.input', return_value='n'), patch.object(p.subprocess, 'call') as call:
            self.assertEqual(p.manage(record['key'], 'remove'), 0)
            call.assert_not_called()

    @unittest.skipUnless(shutil.which('quickshell'), 'needs Quickshell')
    def test_qml_dependency_and_reverse_navigation(self):
        with tempfile.TemporaryDirectory(prefix='penumbra-pkg-qml-') as temp:
            stage = Path(temp)
            shutil.copytree(ROOT / 'config/quickshell/penumbra', stage, dirs_exist_ok=True)
            (stage / 'Ui.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property string bin: "/bin/false "
    property string controlPage: "packages"
    function spawn(cmd) {}
    function terminal(cmd, opts) { return cmd; }
}
''')
            sample = [
                {
                    'key': 'pacman:app', 'source': 'pacman', 'target': 'app', 'name': 'app',
                    'version': '1.0', 'size': '10 MiB', 'size_bytes': 10485760,
                    'description': 'Top level app', 'explicit': True, 'reason': 'Explicitly installed',
                    'dependencies': 'libfoo', 'required_by': 'None', 'details': 'Name: app',
                    'dependency_links': [{'name': 'libfoo', 'label': 'libfoo', 'key': 'aur:libfoo', 'installed': True}],
                    'required_by_links': [], 'optional_dependency_links': [], 'optional_for_links': []
                },
                {
                    'key': 'aur:libfoo', 'source': 'aur', 'target': 'libfoo', 'name': 'libfoo',
                    'version': '2.0', 'size': '1 MiB', 'size_bytes': 1048576,
                    'description': 'Helper library', 'explicit': False, 'reason': 'Installed as dependency',
                    'dependencies': 'None', 'required_by': 'app', 'details': 'Name: libfoo',
                    'dependency_links': [],
                    'required_by_links': [{'name': 'app', 'label': 'app', 'key': 'pacman:app', 'installed': True}],
                    'optional_dependency_links': [], 'optional_for_links': []
                }
            ]
            harness = f'''import QtQuick
import Quickshell
ShellRoot {{
    FloatingWindow {{
        visible: true
        width: 440; height: 700
        PackagesPage {{
            id: page
            width: 404
        }}
        Timer {{
            interval: 150; running: true
            onTriggered: {{
                page.packages = {json.dumps(sample)};
                page.source = "pacman";
                page.roleFilter = "explicit";
                page.selected = "pacman:app";
                // Jump from explicit pacman app to AUR dependency libfoo: filters should relax to reveal it.
                page.jumpTo("aur:libfoo", page.byKey["pacman:app"]);
                if (page.selected !== "aur:libfoo" || page.source !== "all" || page.roleFilter !== "all" || page.history.length !== 1) {{
                    console.error("Failed forward jump:", page.selected, page.source, page.roleFilter, page.history.length);
                    Qt.exit(1);
                    return;
                }}
                // Jump via required_by from libfoo back to app, then goBack twice.
                page.jumpTo("pacman:app", page.byKey["aur:libfoo"]);
                if (page.selected !== "pacman:app" || page.history.length !== 2) {{
                    console.error("Failed reverse-dep jump:", page.selected, page.history.length);
                    Qt.exit(1);
                    return;
                }}
                page.goBack();
                if (page.selected !== "aur:libfoo" || page.history.length !== 1) {{
                    console.error("Failed first goBack:", page.selected, page.history.length);
                    Qt.exit(1);
                    return;
                }}
                page.goBack();
                if (page.selected !== "pacman:app" || page.source !== "pacman" || page.roleFilter !== "explicit" || page.history.length !== 0) {{
                    console.error("Failed second goBack:", page.selected, page.source, page.roleFilter, page.history.length);
                    Qt.exit(1);
                    return;
                }}
                Qt.exit(0);
            }}
        }}
    }}
}}
'''
            (stage / 'shell.qml').write_text(harness)
            (stage / 'runtime').mkdir(mode=0o700)
            env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp, 'XDG_CACHE_HOME': temp,
                   'XDG_RUNTIME_DIR': str(stage / 'runtime'), 'QT_QPA_PLATFORM': 'offscreen',
                   'QT_QUICK_BACKEND': 'software'}
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
