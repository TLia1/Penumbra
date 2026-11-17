"""Run the install in a disposable home, with package and session operations isolated."""
import os
from pathlib import Path
import pwd
import re
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallPlan(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.home = Path(tmp.name)
        self.bin = self.home / 'tools'
        self.bin.mkdir()
        for cmd in ('awk bash cat chmod cmp cp cut date dirname env find git grep gio head ln mkdir mktemp mv '
                    'python3 readlink rm sed sort tr').split():
            (self.bin / cmd).symlink_to(shutil.which(cmd))
        self.stub('systemctl', 'exit 0')
        self.stub('xdg-mime', 'if [ "$1" = default ]; then echo "$2" > "$HOME/mime"; else cat "$HOME/mime"; fi')
        self.stub('dbus-run-session', 'shift; exec "$@"')
        self.stub('runuser', 'shift 3; exec "$@"')
        self.stub('record-folder', 'echo "$1" > "$HOME/opened"')
        self.env = dict(HOME=tmp.name, PATH=str(self.bin), USER='desktop', XDG_DATA_DIRS=str(self.home / 'system/share'),
                        DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent')
        self.identity = {}
        if os.getuid() == 0:
            user = pwd.getpwnam('nobody')
            self.identity = dict(user=user.pw_uid, group=user.pw_gid, extra_groups=[])
            os.chown(self.home, user.pw_uid, user.pw_gid)
            self.bin.chmod(0o755)

    def stub(self, name, code):
        path = self.bin / name
        path.write_text('#!/bin/sh\n' + code + '\n')
        path.chmod(0o755)

    def run_in_home(self, *cmd, check=True):
        result = subprocess.run(cmd, text=True, env=self.env, capture_output=True, timeout=90, **self.identity)
        if check:
            self.assertEqual(result.returncode, 0, result.stdout[-3000:] + result.stderr)
        return result

    def prepare_entry(self, app):
        self.run_in_home('bash', '-c', '''
            mkdir -p "$XDG_DATA_DIRS/applications"
            printf '[Desktop Entry]\\nType=Application\\nName=Files\\nExec=record-folder %%f\\n' > "$XDG_DATA_DIRS/applications/$1.desktop"
        ''', '_', app)

    def open_from_installed_binding(self, app, config):
        mango = (config / 'mango/settings.conf').read_text()
        self.assertIn('var=file_manager,' + app, mango)
        binding = next(s for s in (config / 'mango/keybinds.conf').read_text().splitlines() if s.startswith('bind=SUPER,E,'))
        action = binding.split(',', 3)[3].split(' #')[0]
        self.run_in_home('bash', '-c', 'file_manager=$1; ' + action, '_', app)
        for _ in range(100):
            if (self.home / 'opened').exists():
                break
            time.sleep(.02)
        self.assertEqual((self.home / 'opened').read_text().strip(), str(self.home))
        self.assertEqual((self.home / 'mime').read_text().strip(), app + '.desktop')

    def test_existing_system_failure_repeat_and_undo(self):
        config = self.home / 'custom-config'
        self.env.update(XDG_CONFIG_HOME=str(config))
        self.run_in_home('bash', '-c', '''
            mkdir -p "$XDG_CONFIG_HOME/penumbra" "$HOME/.local/state/penumbra"
            echo terminal=foot > "$XDG_CONFIG_HOME/penumbra/settings.conf"
            echo '{"mode":"light"}' > "$HOME/.local/state/penumbra/theme.json"
            echo sharp > "$HOME/.local/state/penumbra/corners"
        ''')
        settings = config / 'penumbra/settings.conf'
        install = [ROOT / 'install.sh', '--offline', '--distro', 'arch', '--yes', '--terminal', 'kitty']
        self.stub('sudo', 'exit 7')
        preview = self.run_in_home(*install, '--plan').stdout
        self.assertIn('Package to install: dolphin', preview)
        self.assertIn('Update ' + str(settings), preview)
        self.assertFalse((self.home / '.local/state/penumbra/backups').exists())
        self.assertEqual(self.run_in_home(*install, check=False).returncode, 7)
        self.assertEqual(settings.read_text(), 'terminal=foot\n')
        # Sudo and pacman are isolated. Require the real package-selection code to request Dolphin.
        self.stub('sudo', '''exec bash -c 'source "$1"; shift; settings=(); while (( $# )); do
            if [[ $1 == --file-manager ]]; then settings[file_manager]=$2; fi; shift
        done
        PACKAGES=(kitty); SKIP_PACKAGES=0
        pkg_install() {
            [[ " $* " == *" dolphin "* ]] || exit 9
            mkdir -p "$XDG_DATA_DIRS/applications"
            printf "[Desktop Entry]\\nType=Application\\nName=Dolphin\\nExec=record-folder %%f\\n" > "$XDG_DATA_DIRS/applications/org.kde.dolphin.desktop"
        }
        install_packages' _ "$@"''')
        self.run_in_home(*install)
        self.open_from_installed_binding('org.kde.dolphin', config)
        self.assertIn('corner-roundness = 0', (config / 'satty/config.toml').read_text())
        self.assertIn('gtk-theme-name=Breeze\n', (config / 'gtk-4.0/settings.ini').read_text())
        journal = sorted((self.home / '.local/state/penumbra/backups').glob('*/completed.txt'))[-1]
        self.assertIn('Update\t' + str(settings), journal.read_text())
        before = settings.stat().st_mtime_ns
        repeat = self.run_in_home(*install, '--user-only', '--plan').stdout
        self.assertIn('No managed file changes.', repeat)
        self.assertEqual(re.findall(r'^(?:Create|Update|Edit|Remove) .*$', repeat, re.M), [])
        self.run_in_home(*install, '--user-only')
        self.assertEqual(settings.stat().st_mtime_ns, before)
        self.run_in_home(ROOT / 'install.sh', '--user-only', '--uninstall', '--yes')
        self.assertEqual(settings.read_text(), 'terminal=foot\n')

    def test_archiso_user_phase_opens_lia_files(self):
        self.prepare_entry('io.github.lia.Files')
        self.run_in_home('bash', '-c', 'source "$1/tools/install-arch.sh"; DESKTOP_USER=desktop; LAYOUT=us; '
                         'configure_desktop_user "$1" "$HOME"', '_', ROOT)
        self.open_from_installed_binding('io.github.lia.Files', self.home / '.config')
