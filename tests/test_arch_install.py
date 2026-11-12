"""Exercise installer guards and offline setup without mounting or modifying disks."""
import os
from pathlib import Path
import re
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
    def test_graphics_detects_hybrid_gpus_but_ignores_nvidia_audio(self):
        with tempfile.TemporaryDirectory() as directory:
            devices = Path(directory)
            for slot, vendor, pci_class, driver in [
                ('00:02.0', '0x8086', '0x030000', 'xe'),
                ('01:00.0', '0x10de', '0x030200', 'nouveau'),
                ('01:00.1', '0x10de', '0x040300', 'snd_hda_intel'),
                ('02:00.0', '0x1002', '0x030000', 'amdgpu'),
            ]:
                path = devices / slot
                path.mkdir()
                (path / 'vendor').write_text(vendor)
                (path / 'class').write_text(pci_class)
                (path / 'driver').symlink_to('/fake/drivers/' + driver)
            result = bash('detect_graphics "$TEST_DEVICES"; echo "$GPU_INTEL $GPU_AMD $GPU_NVIDIA"; echo "$GPU_EARLY_MODULES"',
                          env={**os.environ, 'TEST_DEVICES': directory})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), ['1 1 1', ' xe amdgpu'])
            shutil.rmtree(devices / '01:00.0')
            result = bash('detect_graphics "$TEST_DEVICES"; echo "$GPU_NVIDIA"',
                          env={**os.environ, 'TEST_DEVICES': directory})
            self.assertEqual(result.stdout.strip(), '0')

    def test_graphics_package_selection(self):
        cases = [
            ('1 0 0 none', {'vulkan-intel', 'lib32-vulkan-intel'}, {'nvidia-utils', 'vulkan-radeon'}),
            ('0 1 0 none', {'vulkan-radeon', 'lib32-vulkan-radeon'}, {'nvidia-utils', 'vulkan-intel'}),
            ('1 0 1 open', {'nvidia-open-dkms', 'linux-headers', 'lib32-nvidia-utils', 'nvidia-prime',
                            'vulkan-intel', 'lib32-vulkan-intel', 'egl-wayland'}, {'vulkan-nouveau'}),
            ('0 0 1 nouveau', {'vulkan-nouveau', 'lib32-vulkan-nouveau'}, {'nvidia-utils', 'nvidia-open-dkms'}),
            ('0 0 0 none', {'mesa', 'lib32-mesa'}, {'nvidia-utils', 'vulkan-intel', 'vulkan-radeon'}),
        ]
        for values, included, excluded in cases:
            with self.subTest(values=values):
                result = bash('read -r GPU_INTEL GPU_AMD GPU_NVIDIA GPU_NVIDIA_DRIVER <<< "' + values +
                              '"; graphics_packages; printf "%s\\n" "${GPU_PACKAGES[@]}"')
                self.assertEqual(result.returncode, 0, result.stderr)
                packages = set(result.stdout.splitlines())
                self.assertTrue(included <= packages)
                self.assertFalse(excluded & packages)

    def test_nvidia_choice_requires_confirmation_or_can_cancel(self):
        setup = '''
detect_graphics() { GPU_INTEL=1 GPU_AMD=0 GPU_NVIDIA=1 GPU_NVIDIA_DRIVER=none; }
lspci() { echo 'NVIDIA test GPU'; }
select_graphics
echo "SELECTED=$GPU_NVIDIA_DRIVER"
'''
        for answer, selected in [('1\ny\n', 'open'), ('1\nn\n2\n', 'nouveau')]:
            result = bash(setup, stdin=answer)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('SELECTED=' + selected, result.stdout)
        for answer in ('', 'q\n'):
            result = bash(setup, stdin=answer)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('SELECTED=', result.stdout)

    def test_nvidia_early_modules_survive_base_config_and_keep_igpu_first(self):
        result = bash('''
GPU_EARLY_MODULES=' xe amdgpu' GPU_NVIDIA_DRIVER=open
config=$(graphics_initramfs_config)
MODULES=()
eval "$config"
printf '%s\\n' "${MODULES[@]}"
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['xe', 'amdgpu', 'nvidia', 'nvidia_modeset', 'nvidia_uvm', 'nvidia_drm'])
        result = bash("GPU_EARLY_MODULES='' GPU_NVIDIA_DRIVER=nouveau; graphics_initramfs_config")
        self.assertNotIn('nvidia', result.stdout)

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

    def test_manual_entry_icons_resolve_from_esp_root_for_both_loaders(self):
        for efi_dir in ('/EFI/refind', '/EFI/BOOT'):
            with self.subTest(efi_dir=efi_dir), tempfile.TemporaryDirectory() as directory:
                esp = Path(directory)
                loader_dir = esp / efi_dir.lstrip('/')
                result = bash('''
copy_boot_tree "$TEST_THEME" "$TEST_LOADER/themes/penumbra"
refind_config 1234-abcd "$TEST_EFI_DIR"
''', env={**os.environ, 'TEST_THEME': str(ROOT / 'boot/refind'),
          'TEST_LOADER': str(loader_dir), 'TEST_EFI_DIR': efi_dir})
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(result.stdout.isascii(), 'Use firmware-safe menu labels')
                icons = re.findall(r'^\s+icon (.+)$', result.stdout, re.M)
                self.assertEqual(len(icons), 2)
                for icon in icons:
                    # rEFInd resolves manual icons from the volume, not the config directory.
                    self.assertTrue(icon.startswith(efi_dir + '/'))
                    self.assertEqual((esp / icon.lstrip('/')).read_bytes(),
                                     (ROOT / 'boot/refind/icons/os_arch.png').read_bytes())
                include = re.search(r'^include (.+)$', result.stdout, re.M).group(1)
                self.assertTrue((loader_dir / include).is_file())

    def test_boot_tree_copy_is_metadata_free_and_retryable(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source'
            source.mkdir()
            (source / 'icons').mkdir()
            (source / 'icons/os_arch.png').write_bytes(b'icon')
            (source / 'theme.conf').write_text('theme')
            destination = root / 'esp/themes/penumbra'
            destination.mkdir(parents=True)
            (destination / 'theme.conf').write_text('incomplete')
            result = bash('''
cp() {
    # Model the ownership/mode restriction that the ext4-only tests missed.
    [[ " $* " == *" --no-preserve=ownership,mode "* ]] || return 1
    [[ " $* " != *" -a "* && " $* " != *" --preserve"* ]] || return 1
    command cp "$@"
}
copy_boot_tree "$TEST_SOURCE" "$TEST_DEST"
copy_boot_tree "$TEST_SOURCE" "$TEST_DEST"
''', env={**os.environ, 'TEST_SOURCE': str(source), 'TEST_DEST': str(destination)})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((destination / 'theme.conf').read_text(), 'theme')
            self.assertEqual((destination / 'icons/os_arch.png').read_bytes(), b'icon')
            self.assertFalse((destination / 'source').exists())

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
