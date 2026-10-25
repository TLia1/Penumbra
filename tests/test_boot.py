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

    def test_uki_splash_preserves_quoted_arguments(self):
        original = 'quiet  root=UUID=example param="two words"'
        updated = boot.uki_splash_cmdline(original + '\n')
        self.assertEqual(updated, original + ' splash')
        self.assertEqual(boot.uki_splash_cmdline(updated), updated)
        for value in ('quiet nosplash', 'plymouth.enable=0', 'rd.plymouth=0',
                      'quiet -- initarg', 'quiet\nroot=example', '# comment'):
            with self.assertRaises(ValueError):
                boot.uki_splash_cmdline(value)

    def test_ambiguous_hooks_rejected(self):
        for text in ('HOOKS=($MYHOOKS)', 'HOOKS=(base)', 'HOOKS=(base udev)\nHOOKS+=(encrypt)',
                     'HOOKS=(base udev plymouth-encrypt)', 'HOOKS=(base udev systemd)'):
            with self.assertRaises(ValueError):
                boot.plymouth_hooks(text)

    def test_remove_only_stock_uki_splash(self):
        stock = ['-S', 'autodetect', '--splash', '/usr/share/systemd/bootctl/splash-arch.bmp']
        self.assertEqual(boot.without_stock_splash(stock), ['-S', 'autodetect'])
        custom = ['--splash', '/custom/logo.bmp']
        self.assertEqual(boot.without_stock_splash(custom), custom)
        self.assertEqual(len(stock), 4)

    def test_limine_theme_leads_and_is_idempotent(self):
        text = ('timeout: 3\nwallpaper: boot():/old.png\nTERM_PALETTE: 000000\n\n'
                '/Arch Linux\n    protocol: linux\n    cmdline: quiet\n')
        themed = boot.limine_theme(text, 'boot():/limine/penumbra/background.png')
        self.assertTrue(themed.startswith(boot.LIMINE_BEGIN + '\n'))
        self.assertIn('wallpaper: boot():/limine/penumbra/background.png\n', themed)
        # The user's copies stay visible but no longer override the block.
        self.assertIn(boot.LIMINE_OFF + 'wallpaper: boot():/old.png\n', themed)
        self.assertIn(boot.LIMINE_OFF + 'TERM_PALETTE: 000000\n', themed)
        rest = text.replace('wallpaper', boot.LIMINE_OFF + 'wallpaper').replace('TERM_PALETTE', boot.LIMINE_OFF + 'TERM_PALETTE')
        self.assertEqual(themed.split(boot.LIMINE_END + '\n\n', 1)[1], rest)
        self.assertEqual(boot.limine_theme(themed, 'boot():/limine/penumbra/background.png'), themed)
        moved = themed.replace(boot.LIMINE_BEGIN + '\n', '', 1) + boot.LIMINE_BEGIN + '\n'
        with self.assertRaises(ValueError):
            boot.limine_theme(moved, 'boot():/x.png')

    def test_limine_splash_only_touches_linux_entries(self):
        text = ('timeout: 5\n/Arch Linux\n    protocol: linux\n    cmdline: root=UUID=x rw quiet\n'
                '/+Tools\n//Memtest\n    protocol: efi\n    path: boot():/memtest.efi\n'
                '/Other kernel\n    PROTOCOL: Linux\n    kernel_cmdline: root=UUID=y splash\r\n')
        updated = boot.limine_splash(text)
        self.assertIn('    cmdline: root=UUID=x rw quiet splash\n', updated)
        self.assertIn('kernel_cmdline: root=UUID=y splash\r\n', updated)
        self.assertEqual(updated.replace(' splash\n', '\n'), text.replace(' splash\n', '\n'))
        self.assertEqual(boot.limine_splash(updated), updated)
        for bad in ('/A\n protocol: linux\n cmdline: ${ARGS}\n', '/A\n protocol: linux\n cmdline: quiet nosplash\n',
                    '/A\n protocol: linux\n path: boot():/vmlinuz\n'):
            with self.assertRaises(ValueError):
                boot.limine_splash(bad)
        uki = '/Arch\n protocol: efi\n path: boot():/EFI/Linux/arch.efi\n cmdline: quiet\n'
        with self.assertRaises(ValueError):
            boot.limine_splash(uki, uki=True)
        self.assertEqual(boot.limine_splash(uki.replace('quiet', 'quiet splash'), uki=True), uki.replace('quiet', 'quiet splash'))

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
            if value.startswith(('/etc/', '/boot/', '/usr/', '/sys/')) or value in ('/boot', '/etc'):
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
            Path(args[args.index('-U' if '-U' in args else '-g') + 1]).write_text('new image')
        elif args[0] == 'plymouth-set-default-theme':
            self.write('/etc/plymouth/plymouthd.conf', '[Daemon]\nTheme=penumbra\n')

    def fake_subprocess(self, args, **kwargs):
        if args == ['grub-mkconfig']:
            old = (self.root / 'boot/grub/grub.cfg').read_text()
            kwargs['stdout'].write(old.replace(' quiet', ' quiet splash'))
        return subprocess.CompletedProcess(args, 0)

    def test_success_stages_images_and_keeps_backup(self):
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'run', side_effect=self.fake_run), patch.object(boot.subprocess, 'run', side_effect=self.fake_subprocess), patch.object(boot.subprocess, 'check_output', return_value='usr/bin/plymouth\npenumbra.plymouth'):
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

    def grub_path(self, args, **kwargs):
        if args[0] == 'grub-probe':
            return 'ABCD-1234\n'
        return args[1].removeprefix('/boot') + '\n'

    def test_grub_preserves_dynamic_uki_menu_and_is_idempotent(self):
        text = '# Custom UKI discovery\nset timeout=7\nset default=saved\ninsmod bls\nblscfg\n'
        self.write('/boot/grub/grub.cfg', text)
        before = self.snapshot()
        with patch.object(boot, 'run'), patch.object(boot.subprocess, 'run') as generate, patch.object(boot.subprocess, 'check_output', side_effect=self.grub_path):
            boot.apply_grub()
            first = (self.root / 'boot/grub/grub.cfg').read_text()
            self.assertTrue(first.startswith(text))
            self.assertIn('set theme=($penumbra_root)/grub/themes/penumbra/theme.txt', first)
            boot.apply_grub()
            self.assertEqual((self.root / 'boot/grub/grub.cfg').read_text(), first)
            generate.assert_not_called()
        for backup in sorted((self.root / 'backups').iterdir(), key=lambda p: p.stat().st_mtime_ns, reverse=True):
            boot.restore(backup)
        self.assertEqual(self.snapshot(), before)

    def test_grub_success_and_restore(self):
        with patch.object(boot, 'run'), patch.object(boot.subprocess, 'check_output', side_effect=self.grub_path):
            boot.apply_grub()
        self.assertIn('GRUB_THEME=', (self.root / 'etc/default/grub').read_text())
        boot.restore(next((self.root / 'backups').iterdir()))
        self.assertEqual(self.snapshot(), self.original)

    def test_grub_syntax_failure_restores_original(self):
        def fail(*args):
            if args[0] == 'grub-script-check':
                raise subprocess.CalledProcessError(1, args)
        with patch.object(boot, 'run', side_effect=fail), patch.object(boot.subprocess, 'check_output', side_effect=self.grub_path):
            with self.assertRaises(subprocess.CalledProcessError):
                boot.apply_grub()
        self.assertEqual(self.snapshot(), self.original)

    def uki_fixture(self):
        self.write('/etc/kernel/cmdline', 'quiet\n')
        self.write('/etc/mkinitcpio.d/linux.preset', "ALL_kver='/boot/vmlinuz-linux'\nPRESETS=('default')\ndefault_uki='/boot/EFI/Linux/arch-linux.efi'\ndefault_options='--splash /usr/share/systemd/bootctl/splash-arch.bmp'\nfallback_uki='/boot/EFI/Linux/arch-linux-fallback.efi'\n")
        self.write('/usr/share/systemd/bootctl/splash-arch.bmp', 'bitmap')
        self.write('/boot/EFI/Linux/arch-linux.efi', 'old uki')

    def test_uki_preset_accepts_disabled_fallback_and_splash(self):
        self.uki_fixture()
        jobs = boot.preset_jobs(self.root / 'etc/mkinitcpio.d')
        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0][1].name, 'arch-linux.efi')
        self.assertEqual(jobs[0][2], ['--splash', '/usr/share/systemd/bootctl/splash-arch.bmp'])

    def test_uki_preflight_rejects_signature_and_changed_arguments(self):
        self.uki_fixture()
        image = self.root / 'boot/EFI/Linux/arch-linux.efi'
        data = bytearray(512)
        data[:2] = b'MZ'
        data[60:64] = (128).to_bytes(4, 'little')
        data[128:132] = b'PE\0\0'
        data[152:154] = b'\x0b\x02'
        image.write_bytes(data)
        secure = self.root / 'sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c'
        secure.parent.mkdir(parents=True)
        secure.write_bytes(b'\x07\0\0\0\0')
        self.write('/etc/kernel/cmdline', 'quiet splash\n')
        self.write('/usr/lib/kernel/uki.conf', '# Stock commented template\n#SecureBootPrivateKey=example\n')
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'uki_section', return_value=b'quiet splash\0'):
            boot.check_uki(image)
            data[296] = 1
            image.write_bytes(data)
            with self.assertRaisesRegex(ValueError, 'Signed or malformed'):
                boot.check_uki(image)
            data[296] = 0
            image.write_bytes(data)
            self.write('/etc/kernel/cmdline', 'quiet\n')
            with patch.object(boot, 'uki_section', return_value=b'quiet\0'):
                boot.check_uki(image)
            self.write('/etc/kernel/cmdline', 'quiet nosplash\n')
            with patch.object(boot, 'uki_section', return_value=b'quiet nosplash\0'):
                with self.assertRaisesRegex(ValueError, 'explicitly disabled'):
                    boot.check_uki(image)
            self.write('/etc/kernel/cmdline', 'different splash')
            with self.assertRaisesRegex(ValueError, 'must match'):
                boot.check_uki(image)

    def test_uki_success_preserves_grub_and_restores(self):
        self.uki_fixture()
        before = self.snapshot()
        def build(*args):
            if args[0] == 'mkinitcpio':
                self.assertIn('-U', args)
                self.assertNotIn('--splash', args)
                self.assertEqual((self.root / 'etc/kernel/cmdline').read_text(), 'quiet splash\n')
                Path(args[args.index('-U') + 1]).write_text('new uki')
            else:
                self.fake_run(*args)
        def section(image, name):
            return b'quiet splash' if name == '.cmdline' else b'initrd'
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'check_uki'), patch.object(boot, 'uki_section', side_effect=section), patch.object(boot, 'run', side_effect=build), patch.object(boot, 'generate_grub') as generate, patch.object(boot.subprocess, 'check_output', return_value='usr/bin/plymouth\npenumbra.plymouth'):
            boot.apply_plymouth()
            generate.assert_not_called()
        self.assertEqual((self.root / 'boot/EFI/Linux/arch-linux.efi').read_text(), 'new uki')
        self.assertNotIn('--splash', (self.root / 'etc/mkinitcpio.d/linux.preset').read_text())
        self.assertEqual((self.root / 'etc/default/grub').read_bytes(), before['etc/default/grub'])
        boot.restore(next((self.root / 'backups').iterdir()))
        self.assertEqual(self.snapshot(), before)

    def test_uki_commandline_change_rolls_back(self):
        self.uki_fixture()
        before = self.snapshot()
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot, 'check_uki'), patch.object(boot, 'uki_section', side_effect=[b'wrong', b'quiet splash']), patch.object(boot, 'run', side_effect=self.fake_run):
            with self.assertRaisesRegex(ValueError, 'embedded kernel command line'):
                boot.apply_plymouth()
        self.assertEqual(self.snapshot(), before)

    def test_fallback_grub_requires_loader_evidence_and_confirmation(self):
        self.write('/sys/firmware/efi/efivars/LoaderInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f', '')
        info = self.root / 'sys/firmware/efi/efivars/LoaderInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f'
        info.write_bytes(b'\x07\0\0\0' + 'GRUB 2.16\0'.encode('utf-16-le'))
        result = subprocess.CompletedProcess([], 0, stdout='BootCurrent: 0008\nBoot0008* Solid State Disk\n')
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), patch.object(boot.subprocess, 'check_output', return_value=''), patch.object(boot.subprocess, 'run', return_value=result), patch.object(boot, 'run'), patch.object(boot, 'ask', return_value=True) as ask:
            self.assertTrue(boot.grub_detected())
            ask.assert_called_once()
            ask.return_value = False
            self.assertFalse(boot.grub_detected())
            info.write_bytes(b'\x07\0\0\0' + 'systemd-boot\0'.encode('utf-16-le'))
            ask.return_value = True
            self.assertFalse(boot.grub_detected())

    def limine_fixture(self, entries='/Arch Linux\n    protocol: linux\n    path: boot():/vmlinuz-linux\n    cmdline: root=UUID=x rw quiet\n    module_path: boot():/initramfs-linux.img\n'):
        self.write('/boot/limine/limine.conf', 'timeout: 5\n\n' + entries)
        self.write('/boot/limine/limine-bios.sys', 'stage\0Limine 12.9.4 (x86-64, BIOS)\0')
        (self.root / 'boot/grub/grub.cfg').unlink()
        (self.root / 'etc/default/grub').unlink()
        self.original = self.snapshot()
        return self.root / 'boot/limine/limine.conf'

    def limine_patches(self):
        return (patch.object(boot.shutil, 'which', side_effect=lambda c: None if c == 'limine-entry-tool' else '/bin/mock'),
                patch.object(boot, 'boot_volumes', return_value=[self.root / 'boot']),
                patch.object(boot, 'mount_of', return_value=self.root / 'boot'))

    def test_limine_detection_needs_version_single_config_and_confirmation(self):
        config = self.limine_fixture()
        which, volumes, mount = self.limine_patches()
        with which, volumes, mount, patch.object(boot, 'ask', return_value=True) as ask:
            self.assertEqual(boot.limine_detected(), config)
            ask.assert_called_once()
            ask.return_value = False
            self.assertIsNone(boot.limine_detected())
            ask.return_value = True
            self.write('/boot/limine/limine-bios.sys', 'stage\0Limine 11.4.1 (x86-64, BIOS)\0')
            self.assertIsNone(boot.limine_detected())
            self.write('/boot/limine/limine-bios.sys', 'stage\0Limine 12.0.0 (x86-64, BIOS)\0')
            self.write('/boot/limine.conf', 'timeout: 1\n')
            self.assertIsNone(boot.limine_detected())

    def test_limine_theme_success_and_restore(self):
        config = self.limine_fixture()
        which, volumes, mount = self.limine_patches()
        with which, volumes, mount:
            boot.apply_limine(config)
            first = config.read_text()
            self.assertIn('wallpaper: boot():/limine/penumbra/background.png\n', first)
            self.assertTrue((self.root / 'boot/limine/penumbra/background.png').is_file())
            self.assertTrue(first.endswith(self.original['boot/limine/limine.conf'].decode()))
            boot.apply_limine(config)
            self.assertEqual(config.read_text(), first)
        for backup in sorted((self.root / 'backups').iterdir(), key=lambda p: p.stat().st_mtime_ns, reverse=True):
            boot.restore(backup)
        self.assertEqual(self.snapshot(), self.original)
        self.assertFalse((self.root / 'boot/limine/penumbra').exists())

    def test_limine_plymouth_adds_splash_without_grub(self):
        config = self.limine_fixture()
        which, volumes, mount = self.limine_patches()
        with which, volumes, mount, patch.object(boot, 'run', side_effect=self.fake_run), patch.object(boot, 'generate_grub') as generate, patch.object(boot.subprocess, 'check_output', return_value='usr/bin/plymouth\npenumbra.plymouth'):
            boot.apply_plymouth(config)
            generate.assert_not_called()
        self.assertIn('cmdline: root=UUID=x rw quiet splash\n', config.read_text())
        self.assertEqual((self.root / 'boot/initramfs-linux.img').read_text(), 'new image')
        self.assertFalse((self.root / 'etc/default/grub').exists())
        boot.restore(next((self.root / 'backups').iterdir()))
        self.assertEqual(self.snapshot(), self.original)

    def test_limine_entry_tool_needs_its_own_cmdline(self):
        config = self.limine_fixture()
        self.write('/etc/default/limine', 'KERNEL_CMDLINE[default]="quiet"\n')
        before = self.snapshot()
        _, volumes, mount = self.limine_patches()
        with patch.object(boot.shutil, 'which', return_value='/bin/mock'), volumes, mount, patch.object(boot, 'run') as run:
            with self.assertRaisesRegex(ValueError, 'KERNEL_CMDLINE'):
                boot.apply_plymouth(config)
            run.assert_not_called()
        self.assertEqual(self.snapshot(), before)

    def test_combined_uki_and_initramfs_preset_is_rejected(self):
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
