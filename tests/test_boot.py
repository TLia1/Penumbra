#!/usr/bin/env python3
"""Isolated tests: no root and no host boot writes."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('boot', Path(__file__).resolve().parents[1] / 'tools/install-boot.py')
boot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(boot)


class ConfigTests(unittest.TestCase):
    def test_splash_preserves_arguments_and_is_idempotent(self):
        text = '# comment\nGRUB_CMDLINE_LINUX_DEFAULT="quiet rootflags=subvol=@ cryptdevice=UUID=x:root"\nGRUB_TIMEOUT=5\n'
        updated = boot.splash_defaults(text)
        self.assertIn('quiet rootflags=subvol=@ cryptdevice=UUID=x:root splash', updated)
        self.assertEqual(updated, boot.splash_defaults(updated))
        self.assertTrue(updated.endswith('GRUB_TIMEOUT=5\n'))

    def test_dynamic_or_disabled_cmdline_rejected(self):
        for value in ('"$FLAGS"', '"quiet $(touch /tmp/bad)"', '"plymouth.enable=0"'):
            with self.assertRaises(ValueError):
                boot.splash_defaults('GRUB_CMDLINE_LINUX_DEFAULT=' + value)

    def test_hook_order_and_idempotence(self):
        for init, crypt in [('udev', 'encrypt'), ('systemd', 'sd-encrypt')]:
            text = f'HOOKS=(base {init} autodetect kms keyboard keymap {crypt} filesystems fsck)\n'
            updated = boot.plymouth_hooks(text)
            self.assertIn(f'{init} plymouth autodetect', updated)
            self.assertEqual(updated, boot.plymouth_hooks(updated))
            self.assertIn(f'keyboard keymap {crypt} filesystems fsck', updated)

    def test_ambiguous_hooks_rejected(self):
        for text in ('HOOKS=($MYHOOKS)', 'HOOKS=(base)', 'HOOKS=(base udev)\nHOOKS+=(encrypt)',
                     'HOOKS=(base udev plymouth-encrypt)', 'HOOKS=(base udev systemd)'):
            with self.assertRaises(ValueError):
                boot.plymouth_hooks(text)

    def test_noninteractive_defaults_no(self):
        with patch.object(boot.os, 'isatty', return_value=False), patch('builtins.input') as read:
            self.assertFalse(boot.ask('Apply?'))
            read.assert_not_called()


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        original_path = Path
        def mapped(value):
            value = str(value)
            if value.startswith(('/etc/', '/boot/', '/usr/')) or value in ('/boot', '/etc'):
                return self.root / value.lstrip('/')
            return original_path(value)
        self.mapping = patch.object(boot, 'Path', side_effect=mapped)
        self.mapping.start()
        self.backups = patch.object(boot, 'BACKUPS', self.root / 'backups')
        self.backups.start()
        self.write('/etc/default/grub', 'GRUB_CMDLINE_LINUX_DEFAULT="quiet"\n')
        self.write('/etc/mkinitcpio.conf', 'HOOKS=(base udev autodetect keyboard filesystems fsck)\n')
        self.write('/etc/mkinitcpio.d/linux.preset', "ALL_kver='/boot/vmlinuz-linux'\nPRESETS=('default')\ndefault_image='/boot/initramfs-linux.img'\n")
        self.write('/boot/vmlinuz-linux', 'kernel')
        self.write('/boot/initramfs-linux.img', 'old image')
        self.write('/boot/grub/grub.cfg', "menuentry 'Arch' {\n linux /vmlinuz-linux root=UUID=example quiet\n initrd /initramfs-linux.img\n}\n")
        self.write('/usr/lib/initcpio/install/plymouth', 'hook')
        self.write('/usr/lib/plymouth/two-step.so', 'plugin')
        self.write('/boot/grub/fonts/unicode.pf2', 'font')
        self.original = self.snapshot()

    def tearDown(self):
        self.mapping.stop()
        self.backups.stop()
        self.tmp.cleanup()

    def write(self, name, content):
        path = self.root / name.lstrip('/')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes() for p in self.root.rglob('*') if p.is_file() and 'backups' not in p.parts}

    def fake_run(self, *args):
        if args[0] == 'mkinitcpio':
            Path(args[args.index('-g') + 1]).write_text('new image')
        elif args[0] == 'plymouth-set-default-theme':
            self.write('/etc/plymouth/plymouthd.conf', '[Daemon]\nTheme=nocturne\n')

    def fake_subprocess(self, args, **kwargs):
        if args == ['grub-mkconfig']:
            old = (self.root / 'boot/grub/grub.cfg').read_text()
            kwargs['stdout'].write(old.replace(' quiet', ' quiet splash'))
        return subprocess.CompletedProcess(args, 0)

    def test_success_stages_images_and_keeps_backup(self):
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'run', side_effect=self.fake_run), patch.object(boot.subprocess, 'run', side_effect=self.fake_subprocess), patch.object(boot.subprocess, 'check_output', return_value='usr/bin/plymouth\nnocturne.plymouth'):
            boot.apply_plymouth()
        self.assertEqual((self.root / 'boot/initramfs-linux.img').read_text(), 'new image')
        self.assertIn('splash', (self.root / 'boot/grub/grub.cfg').read_text())
        backup = next((self.root / 'backups').iterdir())
        boot.restore(backup)
        self.assertEqual(self.snapshot(), self.original)

    def test_build_failure_rolls_back_everything(self):
        def fail(*args):
            self.fake_run(*args)
            if args[0] == 'mkinitcpio':
                raise subprocess.CalledProcessError(1, args)
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'run', side_effect=fail):
            with self.assertRaises(subprocess.CalledProcessError):
                boot.apply_plymouth()
        self.assertEqual(self.snapshot(), self.original)

    def test_changed_kernel_command_rejected_and_rolled_back(self):
        def generate(args, **kwargs):
            kwargs['stdout'].write("menuentry 'Arch' {\n linux /WRONG root=UUID=example\n initrd /initramfs-linux.img\n}\n")
        with patch.object(boot, 'run'), patch.object(boot.subprocess, 'run', side_effect=generate):
            with self.assertRaises(ValueError):
                boot.apply_grub()
        self.assertEqual(self.snapshot(), self.original)

    def test_grub_success_and_restore(self):
        def generate(args, **kwargs):
            old = (self.root / 'boot/grub/grub.cfg').read_text()
            kwargs['stdout'].write('set theme=/boot/grub/themes/nocturne/theme.txt\n' + old)
        with patch.object(boot, 'run'), patch.object(boot.subprocess, 'run', side_effect=generate):
            boot.apply_grub()
        self.assertIn('GRUB_THEME=', (self.root / 'etc/default/grub').read_text())
        boot.restore(next((self.root / 'backups').iterdir()))
        self.assertEqual(self.snapshot(), self.original)

    def test_grub_syntax_failure_restores_original(self):
        def fail(*args):
            if args[0] == 'grub-script-check':
                raise subprocess.CalledProcessError(1, args)
        with patch.object(boot, 'run', side_effect=fail), patch.object(boot.subprocess, 'run', side_effect=self.fake_subprocess):
            with self.assertRaises(subprocess.CalledProcessError):
                boot.apply_grub()
        self.assertEqual(self.snapshot(), self.original)

    def test_uki_preset_is_rejected_before_changes(self):
        with (self.root / 'etc/mkinitcpio.d/linux.preset').open('a') as f:
            f.write("default_uki='/efi/EFI/Linux/arch.efi'\n")
        with self.assertRaises(ValueError):
            boot.preset_jobs(self.root / 'etc/mkinitcpio.d')

    def test_dropin_is_rejected_before_changes(self):
        self.write('/etc/mkinitcpio.conf.d/custom.conf', 'HOOKS=(custom)')
        before = self.snapshot()
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'):
            with self.assertRaises(ValueError):
                boot.apply_plymouth()
        self.assertEqual(self.snapshot(), before)


if __name__ == '__main__':
    unittest.main()
