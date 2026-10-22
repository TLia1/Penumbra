#!/usr/bin/env python3
"""Opt-in boot themes. Never installs GRUB or writes boot sectors/EFI entries."""
import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BACKUPS = Path('/var/lib/nocturne/boot-backups')


def run(*args):
    subprocess.run(args, check=True)


def ask(question):
    # No implicit yes, including when run without a terminal or at EOF.
    if not os.isatty(0):
        print(f'{question} [y/N] — skipped (noninteractive)')
        return False
    try:
        return input(f'{question} [y/N] ').strip().lower() in ('y', 'yes')
    except EOFError:
        return False


def literal(value):
    if any(c in value for c in '$`\\\n;<>|&'):
        raise ValueError('Dynamic shell configuration requires manual setup.')
    words = shlex.split(value, comments=True)
    if len(words) != 1:
        raise ValueError('Expected one literal shell value.')
    return words[0]


def splash_defaults(text):
    matches = list(re.finditer(r'^GRUB_CMDLINE_LINUX_DEFAULT=(.*)$', text, re.M))
    if len(matches) > 1:
        raise ValueError('Multiple kernel command-line assignments require manual setup.')
    value = literal(matches[0][1]) if matches else ''
    words = value.split()
    if any(w in ('plymouth.enable=0', 'rd.plymouth=0', 'nosplash') for w in words):
        raise ValueError('Plymouth is explicitly disabled in the kernel command line.')
    if 'splash' not in words:
        words.append('splash')
    replacement = 'GRUB_CMDLINE_LINUX_DEFAULT=' + shlex.quote(' '.join(words))
    if matches:
        return text[:matches[0].start()] + replacement + text[matches[0].end():]
    return text + '\n' + replacement + '\n'


def plymouth_hooks(text):
    matches = list(re.finditer(r'^HOOKS=\(([^)]*)\)', text, re.M))
    if len(matches) != 1 or len(re.findall(r'^\s*HOOKS[+]?=', text, re.M)) != 1:
        raise ValueError('Expected one plain HOOKS array; custom configuration needs manual setup.')
    hooks = shlex.split(matches[0][1], comments=True)
    if any(not re.fullmatch(r'[\w-]+', h) for h in hooks):
        raise ValueError('Dynamic HOOKS array is unsupported.')
    if 'plymouth-encrypt' in hooks or 'sd-plymouth' in hooks:
        raise ValueError('Legacy Plymouth hooks require manual migration.')
    anchors = [h for h in ('udev', 'systemd') if h in hooks]
    if len(anchors) != 1:
        raise ValueError('Expected either udev or systemd in HOOKS.')
    hooks = [h for h in hooks if h != 'plymouth']
    hooks.insert(hooks.index(anchors[0]) + 1, 'plymouth')
    # Preserve keyboard, encryption, root filesystem and all other hooks.
    return text[:matches[0].start()] + 'HOOKS=(' + ' '.join(hooks) + ')' + text[matches[0].end():]


def preset_jobs(directory):
    """Accept conventional Arch presets only, without executing shell input."""
    jobs = []
    for path in sorted(directory.glob('*.preset')):
        values = {}
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            match = re.fullmatch(r'(\w+)=(.*)', line)
            if not match or match[1] in values:
                raise ValueError(f'Custom preset requires manual setup: {path}')
            key, value = match.groups()
            if key == 'PRESETS':
                if not re.fullmatch(r'\([\w\s\'"-]+\)', value):
                    raise ValueError(f'Unsupported PRESETS array: {path}')
                values[key] = shlex.split(value[1:-1])
            else:
                values[key] = literal(value)
        presets = values.get('PRESETS', [])
        if not presets or not all(re.fullmatch(r'\w+', p) for p in presets):
            raise ValueError(f'No supported presets: {path}')
        allowed = {'PRESETS', 'ALL_kver', 'ALL_config'}
        for p in presets:
            allowed.update({p + '_image', p + '_kver', p + '_config', p + '_options'})
        if set(values) - allowed:
            raise ValueError(f'UKI/custom preset keys require manual setup: {path}')
        for p in presets:
            config = values.get(p + '_config', values.get('ALL_config', '/etc/mkinitcpio.conf'))
            image = Path(values.get(p + '_image', ''))
            kernel = Path(values.get(p + '_kver', values.get('ALL_kver', '')))
            options = shlex.split(values.get(p + '_options', ''))
            if config != '/etc/mkinitcpio.conf' or options not in ([], ['-S', 'autodetect']):
                raise ValueError(f'Custom config/options require manual setup: {path}')
            if image.parent != Path('/boot') or not image.name.startswith('initramfs-') or image.suffix != '.img':
                raise ValueError(f'Nonstandard initramfs destination: {path}')
            if kernel.parent != Path('/boot') or not kernel.name.startswith('vmlinuz-') or not kernel.is_file():
                raise ValueError(f'Unsupported kernel location: {path}')
            if image.is_symlink() or not image.is_file():
                raise ValueError(f'Existing regular initramfs required: {image}')
            jobs.append((kernel, image, options))
    if not jobs or len({j[1] for j in jobs}) != len(jobs):
        raise ValueError('Missing presets or duplicate initramfs destinations.')
    return jobs


def grub_detected():
    required = ('grub-mkconfig', 'grub-script-check', 'grub-probe', 'findmnt')
    if not all(shutil.which(c) for c in required):
        return False
    mounts = subprocess.check_output(['findmnt', '--fstab', '--noheadings', '--output', 'TARGET'], text=True).splitlines()
    for mount in mounts:
        if mount in ('/boot', '/boot/grub') and not os.path.ismount(mount):
            print(f'Required boot filesystem is not mounted: {mount}')
            return False
    if not Path('/etc/default/grub').is_file() or not Path('/boot/grub/grub.cfg').is_file():
        return False
    if Path('/boot/grub/grub.cfg').is_symlink() or Path('/etc/default/grub').is_symlink():
        return False
    if Path('/sys/firmware/efi').exists():
        if not shutil.which('efibootmgr'):
            print('Cannot verify the active EFI boot entry without efibootmgr.')
            return False
        result = subprocess.run(['efibootmgr', '-v'], text=True, capture_output=True)
        current = re.search(r'^BootCurrent: ([0-9A-Fa-f]{4})$', result.stdout, re.M)
        if result.returncode or not current:
            return False
        entry = re.search(r'^Boot' + current[1] + r'\*?\s+(.+)$', result.stdout, re.M)
        if not entry or not re.search(r'grub[^\\/\s]*\.efi', entry[1], re.I):
            print('Active EFI entry is not clearly GRUB (shim/custom chains need manual setup).')
            return False
    else:
        if not Path('/boot/grub/i386-pc/core.img').is_file():
            return False
        if not ask('Legacy BIOS GRUB files found; confirm this machine actually boots with GRUB'):
            return False
    run('grub-script-check', '/boot/grub/grub.cfg')
    run('grub-probe', '--target=fs', '/boot/grub')
    return True


class Transaction:
    def __init__(self, name):
        BACKUPS.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.directory = Path(tempfile.mkdtemp(prefix=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-') + name + '-', dir=BACKUPS))
        self.paths = []
        self.temporary = []
        print(f'Boot backup: {self.directory}', flush=True)

    def save(self, path):
        path = Path(path)
        if str(path) in self.paths:
            return
        destination = self.directory / 'files' / str(path).lstrip('/')
        destination.parent.mkdir(parents=True, exist_ok=True)
        if path.is_symlink():
            raise ValueError(f'Refusing to replace symlink: {path}')
        if path.is_dir():
            shutil.copytree(path, destination, symlinks=True)
        elif path.exists():
            shutil.copy2(path, destination)
        self.paths.append(str(path))
        (self.directory / 'manifest.json').write_text(json.dumps(self.paths, indent=2))

    def stage(self, destination):
        fd, name = tempfile.mkstemp(prefix='.nocturne-', dir=Path(destination).parent)
        os.close(fd)
        self.temporary.append(Path(name))
        return Path(name)

    def __enter__(self):
        return self

    def __exit__(self, typ, value, trace):
        if typ is not None:
            print('Boot theme failed; restoring previous files.', flush=True)
            restore(self.directory)
        for path in self.temporary:
            path.unlink(missing_ok=True)
        return False


def restore(directory):
    for name in reversed(json.loads((directory / 'manifest.json').read_text())):
        dest = Path(name)
        source = directory / 'files' / name.lstrip('/')
        if dest.is_dir() and not dest.is_symlink():
            shutil.rmtree(dest)
        elif dest.exists() or dest.is_symlink():
            dest.unlink()
        if source.is_dir():
            shutil.copytree(source, dest, symlinks=True)
        elif source.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
    print(f'Restored files from {directory}. Installed packages were retained.')


def deploy(tx, source, dest):
    tx.save(dest)
    shutil.copytree(source, dest, dirs_exist_ok=True)


def generate_grub(tx):
    destination = Path('/boot/grub/grub.cfg')
    tx.save(destination)
    staged = tx.stage(destination)
    # stdout mode avoids grub-mkconfig writing the active configuration itself.
    with staged.open('w') as output:
        subprocess.run(['grub-mkconfig'], stdout=output, check=True)
    run('grub-script-check', str(staged))
    text = staged.read_text()
    if not re.search(r'^\s*menuentry\s', text, re.M) or not re.search(r'^\s*linux(?:efi)?\s', text, re.M):
        raise ValueError('Generated GRUB config has no Linux boot entry.')
    # Theming must not alter the generated kernel/initrd boot commands.
    pattern = r'^\s*(?:linux(?:efi)?|initrd(?:efi)?)\s+.*$'
    old = re.findall(pattern, destination.read_text(), re.M)
    new = re.findall(pattern, text, re.M)
    normalize = lambda lines: [' '.join(w for w in line.split() if w != 'splash') for line in lines]
    if normalize(old) != normalize(new):
        raise ValueError('Generated kernel/initrd commands changed beyond splash; review manually.')
    os.chmod(staged, destination.stat().st_mode & 0o777)
    os.replace(staged, destination)


def apply_grub():
    if not Path('/boot/grub/fonts/unicode.pf2').is_file():
        raise ValueError('GRUB Unicode font missing; graphical theme skipped.')
    if re.search(r'^\s*GRUB_TERMINAL=', Path('/etc/default/grub').read_text(), re.M):
        raise ValueError('GRUB_TERMINAL overrides graphical output; review this custom terminal setting manually.')
    with Transaction('grub') as tx:
        defaults = Path('/etc/default/grub')
        tx.save(defaults)
        deploy(tx, ROOT / 'boot/grub', Path('/boot/grub/themes/nocturne'))
        # Last shell assignments win; preserve all original lines and boot arguments.
        text = defaults.read_text()
        text = re.sub(r'\n# BEGIN NOCTURNE GRUB\n.*?# END NOCTURNE GRUB\n', '', text, flags=re.S)
        text += '\n# BEGIN NOCTURNE GRUB\nGRUB_THEME="/boot/grub/themes/nocturne/theme.txt"\nGRUB_TERMINAL_OUTPUT="gfxterm"\n# END NOCTURNE GRUB\n'
        defaults.write_text(text)
        generate_grub(tx)
        if 'themes/nocturne/theme.txt' not in Path('/boot/grub/grub.cfg').read_text():
            raise ValueError('Generated GRUB configuration did not activate the theme.')
    print('Nocturne GRUB theme applied. Boot installation and timeout were preserved.')


def apply_plymouth():
    if not shutil.which('mkinitcpio') or not Path('/usr/lib/initcpio/install/plymouth').is_file():
        raise ValueError('Supported mkinitcpio Plymouth hook is missing.')
    if not Path('/usr/lib/plymouth/two-step.so').is_file():
        raise ValueError('Plymouth two-step plugin missing.')
    if any(Path(d).exists() and any(Path(d).iterdir()) for d in ('/etc/initcpio/post', '/usr/lib/initcpio/post')):
        raise ValueError('Custom mkinitcpio post hooks require manual setup to avoid extra boot writes.')
    if list(Path('/etc/mkinitcpio.conf.d').glob('*.conf')):
        raise ValueError('mkinitcpio drop-ins require manual setup; no hooks changed.')
    config = Path('/etc/mkinitcpio.conf')
    defaults = Path('/etc/default/grub')
    hooks = plymouth_hooks(config.read_text())
    cmdline = splash_defaults(defaults.read_text())
    jobs = preset_jobs(Path('/etc/mkinitcpio.d'))
    # Keep originals plus new staged images; allow ample room for Plymouth/fonts.
    needed = sum(image.stat().st_size for _, image, _ in jobs) + 256 * 1024 * 1024
    if shutil.disk_usage('/boot').free < needed:
        raise ValueError('Insufficient free /boot space for safe staged initramfs builds.')
    with Transaction('plymouth') as tx:
        for path in (config, defaults, Path('/etc/plymouth/plymouthd.conf'),
                     Path('/usr/share/plymouth/themes/default.plymouth')):
            # Theme selector can remove this legacy symlink; preserve it separately.
            if path.is_symlink():
                raise ValueError(f'Legacy/symlink configuration needs manual setup: {path}')
            tx.save(path)
        for _, image, _ in jobs:
            tx.save(image)
        deploy(tx, ROOT / 'boot/plymouth', Path('/usr/share/plymouth/themes/nocturne'))
        config.write_text(hooks)
        defaults.write_text(cmdline)
        run('plymouth-set-default-theme', 'nocturne')
        staged_images = []
        for kernel, image, options in jobs:
            stage = tx.stage(image)
            run('mkinitcpio', '-c', str(config), '-k', str(kernel), '-g', str(stage), *options)
            listing = subprocess.check_output(['lsinitcpio', str(stage)], text=True)
            if 'usr/bin/plymouth' not in listing or 'nocturne.plymouth' not in listing:
                raise ValueError('Generated initramfs does not contain Plymouth and Nocturne.')
            os.chmod(stage, image.stat().st_mode & 0o777)
            staged_images.append((stage, image))
        generate_grub(tx)
        for stage, image in staged_images:
            os.replace(stage, image)
    print('Nocturne Plymouth theme applied and initramfs rebuilt. Reboot when convenient.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', type=Path, help='restore a recorded boot transaction (newest first)')
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run through ./install.sh --boot-only or sudo.')
    with open('/run/nocturne-boot.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.restore:
            directory = args.restore.resolve()
            if directory.parent != BACKUPS or not (directory / 'manifest.json').is_file():
                parser.error('Choose a backup directory under ' + str(BACKUPS))
            restore(directory)
            return
        available = grub_detected()
        print('GRUB: ' + ('verified/confirmed.' if available else 'not verified; boot configuration will be skipped.'))
        if available and ask('Apply the Nocturne GRUB theme (back up and regenerate menu)'):
            apply_grub()
        installed = subprocess.run(['pacman', '-Qq', 'plymouth'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        print('Plymouth: ' + ('installed.' if installed else 'not installed.'))
        if not installed and ask('Install Plymouth from the configured Arch repositories'):
            run('pacman', '-S', '--needed', 'plymouth')
            installed = True
        if installed and available and ask('Apply Nocturne to Plymouth (add splash/hook and rebuild initramfs)'):
            apply_plymouth()
        elif installed and not available:
            print('Plymouth theme is in boot/plymouth; boot integration requires a verified supported GRUB setup.')


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        print(f'Boot theming stopped: {error}', flush=True)
        raise SystemExit(1)
