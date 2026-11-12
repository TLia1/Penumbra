"""Exercise installer guards and offline setup without mounting or modifying disks."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / 'tools/install-arch.sh'


def bash(script, *, stdin='', env=None, installer=INSTALLER):
    return subprocess.run(['bash', '-c', 'source "$1"; ' + script, '_', str(installer)],
                          input=stdin, text=True, capture_output=True,
                          env=env, timeout=30)


# Only inventories are mocked. Never create block devices or call partitioning tools.
INVENTORY = '''
DISK=/dev/testdisk
lsblk() {
    case $* in
        *MOUNTPOINTS*) printf '%s' "${TEST_MOUNTS:-}" ;;
        *NAME,TYPE*) printf '/dev/testdisk disk\\n/dev/testdisk1 %s\\n' "${TEST_KIND:-part}" ;;
    esac
}
find() { printf '%s' "${TEST_HOLDERS:-}"; }
swapon() { printf '%s\\n' "${TEST_SWAP:-}"; }
losetup() { printf '%s\\n' "${TEST_LOOP:-}"; }
findmnt() { printf '%s' "${TEST_SOURCE:-}"; }
'''


class ArchInstaller(unittest.TestCase):
    def test_help_and_bash_syntax(self):
        for path in (INSTALLER, ROOT / 'install.sh'):
            result = subprocess.run(['bash', '-n', str(path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
        result = subprocess.run(['bash', str(INSTALLER), '--help'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Erases a whole disk', result.stdout)

    def test_partition_paths(self):
        result = bash('for disk in /dev/sda /dev/vda /dev/nvme0n1 /dev/mmcblk0; do partition_path "$disk" 3; done')
        self.assertEqual(result.stdout.splitlines(), ['/dev/sda3', '/dev/vda3', '/dev/nvme0n1p3', '/dev/mmcblk0p3'])

    def test_rejects_non_block_disk(self):
        result = bash('DISK=/dev/null; validate_disk')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('whole disk', result.stderr)

    def test_empty_disk_is_accepted(self):
        result = bash(INVENTORY + 'check_disk_usage')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_disk_in_use_is_rejected(self):
        cases = [
            ('TEST_MOUNTS=/run/archiso/bootmnt', 'mounted/in use'),
            ('TEST_MOUNTS="[SWAP]"', 'mounted/in use'),
            ('TEST_KIND=crypt', 'mapped device'),
            ('TEST_HOLDERS=/sys/class/block/testdisk/holders/dm-0', 'active holders'),
            ('TEST_SWAP=/dev/testdisk1', 'active swap'),
            ('TEST_SWAP=/swapfile; TEST_SOURCE=/dev/testdisk1', 'active swap'),
            ('TEST_LOOP=/images/arch.iso; TEST_SOURCE=/dev/testdisk1', 'loop device'),
        ]
        for setup, message in cases:
            with self.subTest(setup=setup):
                result = bash(INVENTORY + setup + '; check_disk_usage')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(message, result.stderr)

    def test_other_disks_swap_is_allowed(self):
        result = bash(INVENTORY + 'TEST_SWAP=/dev/other1; TEST_SOURCE=/dev/other1; check_disk_usage')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_inventory_failure_does_not_allow_erasure(self):
        for command in ('lsblk', 'swapon', 'losetup', 'find'):
            with self.subTest(command=command):
                result = bash(INVENTORY + command + '() { return 1; }; check_disk_usage')
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Could not inspect', result.stderr)

    def test_confirmation_must_match_exactly(self):
        with tempfile.TemporaryDirectory() as directory:
            env = {**os.environ, 'TEST_TARGET': directory}
            script = '''
TARGET=$TEST_TARGET DISK=/dev/testdisk SWAP_GIB=8
HOSTNAME=pc DESKTOP_USER=lia SUDO_USER_ENABLED=no LOCALE=en_US.UTF-8 TIMEZONE=UTC
validate_disk() { :; }
findmnt() { :; }
lsblk() { :; }
# Even a regression must never invoke the real destructive tools.
wipefs() { echo DESTRUCTIVE_COMMAND; exit 99; }
sfdisk() { echo DESTRUCTIVE_COMMAND; exit 99; }
partition_disk
'''
            for response in ('', 'yes\n', 'ERASE /dev/other\n', 'erase /dev/testdisk\n'):
                with self.subTest(response=response):
                    result = bash(script, stdin=response, env=env)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertNotIn('DESTRUCTIVE_COMMAND', result.stdout)

    def test_boot_entries_use_target_uuid_and_offer_console(self):
        result = bash('refind_config 1234-abcd')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('root=UUID=1234-abcd'), 2)
        self.assertIn('rw quiet splash', result.stdout)
        self.assertIn('rw systemd.unit=multi-user.target', result.stdout)
        self.assertNotIn('archisodevice', result.stdout)
        self.assertNotIn('root=/dev/', result.stdout)

    def test_offline_system_services_are_never_started(self):
        with tempfile.TemporaryDirectory() as directory:
            result = bash('''
OFFLINE=1 BACKUP=$HOME SERVICES=()
systemctl() { printf '%s\\n' "$*" >> "$HOME/calls"; }
enable_services
cat "$HOME/calls"
''', env={**os.environ, 'HOME': directory}, installer=ROOT / 'install.sh')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('enable sddm', result.stdout)
            self.assertNotIn('--now', result.stdout)
            self.assertNotIn('daemon-reload', result.stdout)

    @unittest.skipUnless(shutil.which('systemctl') and Path('/usr/lib/systemd/user/gnome-keyring-daemon.socket').exists(),
                         'needs systemd and the keyring socket for offline integration')
    def test_offline_user_service_enable_without_a_bus(self):
        # Real systemctl, isolated HOME, no D-Bus or XDG paths: detect accidental manager calls.
        with tempfile.TemporaryDirectory() as directory:
            env = {k: v for k, v in os.environ.items()
                   if not k.startswith('XDG_') and k != 'DBUS_SESSION_BUS_ADDRESS'}
            env['HOME'] = directory
            result = bash('OFFLINE=1; BACKUP=$HOME/backup; mkdir -p "$BACKUP"; configure_keyring',
                          env=env, installer=ROOT / 'install.sh')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((Path(directory) / '.config/systemd/user/sockets.target.wants/gnome-keyring-daemon.socket').is_symlink())


if __name__ == '__main__':
    unittest.main()
