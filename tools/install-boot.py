#!/usr/bin/env python3
"""Opt-in boot themes. Never installs GRUB, Limine or rEFInd, or writes boot sectors/EFI entries."""
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
BACKUPS = Path('/var/lib/penumbra/boot-backups')


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
            allowed.update({p + '_image', p + '_kver', p + '_config', p + '_options', p + '_uki'})
        # Presets may retain assignments for disabled fallback entries.
        allowed.update(k for k in values if re.fullmatch(r'\w+_(image|uki|kver|config|options)', k))
        if set(values) - allowed:
            raise ValueError(f'UKI/custom preset keys require manual setup: {path}')
        for p in presets:
            config = values.get(p + '_config', values.get('ALL_config', '/etc/mkinitcpio.conf'))
            if p + '_image' in values and p + '_uki' in values:
                raise ValueError('Combined initramfs/UKI outputs require manual setup.')
            uki = p + '_uki' in values
            image = Path(values.get(p + ('_uki' if uki else '_image'), ''))
            kernel = Path(values.get(p + '_kver', values.get('ALL_kver', '')))
            options = shlex.split(values.get(p + '_options', ''))
            checked_options = options[:]
            if uki and '--splash' in checked_options:
                index = checked_options.index('--splash')
                if index + 1 >= len(checked_options) or not Path(checked_options[index + 1]).is_file():
                    raise ValueError('UKI splash bitmap is missing.')
                del checked_options[index:index + 2]
            if config != '/etc/mkinitcpio.conf' or checked_options not in ([], ['-S', 'autodetect']):
                raise ValueError(f'Custom config/options require manual setup: {path}')
            valid_image = (image.parent == Path('/boot/EFI/Linux') and image.suffix == '.efi') if uki else (image.parent == Path('/boot') and image.name.startswith('initramfs-') and image.suffix == '.img')
            if not valid_image:
                raise ValueError(f'Nonstandard initramfs destination: {path}')
            if kernel.parent != Path('/boot') or not kernel.name.startswith('vmlinuz-') or not kernel.is_file():
                raise ValueError(f'Unsupported kernel location: {path}')
            if image.is_symlink() or not image.is_file():
                raise ValueError(f'Existing regular initramfs required: {image}')
            jobs.append((kernel, image, options))
    if not jobs or len({j[1] for j in jobs}) != len(jobs):
        raise ValueError('Missing presets or duplicate initramfs destinations.')
    return jobs


def loader_info():
    """The Boot Loader Interface name of the UEFI loader that ran, e.g. 'Limine 12.9.4'."""
    info = Path('/sys/firmware/efi/efivars/LoaderInfo-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f')
    try:
        return info.read_bytes()[4:].decode('utf-16-le').rstrip('\0')
    except (OSError, UnicodeError):
        return ''


def grub_detected():
    required = ('grub-mkconfig', 'grub-script-check', 'grub-probe', 'grub-mkrelpath', 'findmnt')
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
            # Firmware fallback entries often name only the physical disk.
            # LoaderInfo identifies the loader that ran, independently of its filename.
            loader = loader_info()
            if not loader.startswith('GRUB '):
                print('Active EFI entry is not clearly GRUB and firmware LoaderInfo does not identify GRUB.')
                return False
            print(f'Firmware reports {loader}; EFI entry uses a fallback/custom path.')
            if not ask('Confirm this boot uses /boot/grub/grub.cfg (fallback/custom EFI path)'):
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
        fd, name = tempfile.mkstemp(prefix='.penumbra-', dir=Path(destination).parent)
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
    # Replace rather than merge, so files a previous version shipped do not linger.
    if dest.is_dir():
        shutil.rmtree(dest)
    shutil.copytree(source, dest)


def generate_grub(tx):
    destination = Path('/boot/grub/grub.cfg')
    tx.save(destination)
    staged = tx.stage(destination)
    # stdout mode avoids grub-mkconfig writing the active configuration itself.
    with staged.open('w') as output:
        subprocess.run(['grub-mkconfig'], stdout=output, check=True)
    run('grub-script-check', str(staged))
    text = staged.read_text()
    if not re.search(r'^\s*menuentry\s', text, re.M) or not re.search(r'^\s*(?:linux(?:efi)?|chainloader)\s', text, re.M):
        raise ValueError('Generated GRUB config has no Linux boot entry.')
    # Theming must not alter the generated kernel/initrd boot commands.
    pattern = r'^\s*(?:linux(?:efi)?|initrd(?:efi)?|chainloader)\s+.*$'
    old = re.findall(pattern, destination.read_text(), re.M)
    new = re.findall(pattern, text, re.M)
    normalize = lambda lines: [' '.join(w for w in line.split() if w != 'splash') for line in lines]
    if normalize(old) != normalize(new):
        raise ValueError('Generated kernel/initrd commands changed beyond splash; review manually.')
    os.chmod(staged, destination.stat().st_mode & 0o777)
    os.replace(staged, destination)


def theme_existing_grub(tx):
    """Append graphics setup while retaining the working boot menu verbatim."""
    destination = Path('/boot/grub/grub.cfg')
    original = destination.read_text()
    begin = '# BEGIN PENUMBRA GRAPHICS'
    end = '# END PENUMBRA GRAPHICS'
    # The theme was called Nocturne before; replace a block left by that name too.
    for name in ('PENUMBRA', 'NOCTURNE'):
        old_begin, old_end = f'# BEGIN {name} GRAPHICS', f'# END {name} GRAPHICS'
        if old_begin in original or old_end in original:
            # Only replace our own final block; never remove intervening user edits.
            pattern = r'\n' + old_begin + r'\n.*?\n' + old_end + r'\n\Z'
            if original.count(old_begin) != 1 or original.count(old_end) != 1 or not re.search(pattern, original, re.S):
                raise ValueError('Penumbra graphics block was edited/moved; review manually.')
            original = re.sub(pattern, '', original, flags=re.S)
    uuid = subprocess.check_output(['grub-probe', '--target=fs_uuid', '/boot/grub'], text=True).strip()
    if not re.fullmatch(r'[A-Za-z0-9-]+', uuid):
        raise ValueError('Cannot determine a safe GRUB filesystem UUID.')
    paths = []
    for name in ('/boot/grub/fonts/unicode.pf2', '/boot/grub/themes/penumbra/theme.txt'):
        value = subprocess.check_output(['grub-mkrelpath', name], text=True).strip()
        if not re.fullmatch(r'/[A-Za-z0-9_./-]+', value):
            raise ValueError('Unsupported GRUB filesystem-relative theme path.')
        paths.append(value)
    font, theme = paths
    block = f"""
{begin}
# Keep root, boot entries, default selection and timeout unchanged.
search --no-floppy --fs-uuid --set=penumbra_root {uuid}
if loadfont ($penumbra_root){font}; then
    insmod all_video
    insmod gfxterm
    insmod gfxmenu
    insmod png
    if [ -z "$gfxmode" ]; then
        set gfxmode=auto
    fi
    terminal_output gfxterm
    set theme=($penumbra_root){theme}
    export theme
fi
{end}
"""
    tx.save(destination)
    staged = tx.stage(destination)
    staged.write_text(original + block)
    run('grub-script-check', str(staged))
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
        deploy(tx, ROOT / 'boot/grub', Path('/boot/grub/themes/penumbra'))
        # Last shell assignments win; preserve all original lines and boot arguments.
        text = defaults.read_text()
        text = re.sub(r'\n# BEGIN (PENUMBRA|NOCTURNE) GRUB\n.*?# END \1 GRUB\n', '', text, flags=re.S)
        text += '\n# BEGIN PENUMBRA GRUB\nGRUB_THEME="/boot/grub/themes/penumbra/theme.txt"\nGRUB_TERMINAL_OUTPUT="gfxterm"\n# END PENUMBRA GRUB\n'
        defaults.write_text(text)
        theme_existing_grub(tx)
        if 'themes/penumbra/theme.txt' not in Path('/boot/grub/grub.cfg').read_text():
            raise ValueError('Generated GRUB configuration did not activate the theme.')
    print('Penumbra GRUB theme applied. Boot installation and timeout were preserved.')


LIMINE_BEGIN = '# BEGIN PENUMBRA LIMINE'
LIMINE_END = '# END PENUMBRA LIMINE'
# Prefix for the user's own copies of the options the block sets: Limine reads the first
# copy of an option, and picks a random wallpaper when there are several.
LIMINE_OFF = '#penumbra-off# '
LIMINE_KEYS = {'wallpaper', 'wallpaper_style', 'backdrop', 'interface_branding',
               'interface_branding_colour', 'interface_branding_color', 'interface_help_colour',
               'interface_help_color', 'interface_help_colour_bright', 'interface_help_color_bright',
               'term_palette', 'term_palette_bright', 'term_background', 'term_foreground',
               'term_background_bright', 'term_foreground_bright', 'term_margin', 'term_margin_gradient'}
# Where Limine looks for its configuration on each volume, in its own order.
LIMINE_CONFIGS = ('boot/limine/limine.conf', 'boot/limine.conf', 'limine/limine.conf', 'limine.conf')
LIMINE_EFI_CONFIGS = ('EFI/BOOT/limine.conf', 'EFI/limine/limine.conf')
LIMINE_BIOS_STAGE = ('limine-bios.sys', 'limine/limine-bios.sys', 'boot/limine-bios.sys', 'boot/limine/limine-bios.sys')


def boot_volumes():
    """Mounted FAT volumes where Limine's configuration and artwork can live."""
    volumes = []
    for mount in ('/boot', '/efi', '/boot/efi'):
        result = subprocess.run(['findmnt', '--noheadings', '--output', 'FSTYPE', '--mountpoint', mount],
                                text=True, capture_output=True)
        if result.returncode == 0 and result.stdout.strip() == 'vfat':
            volumes.append(Path(mount))
    return volumes


def mount_of(path):
    return Path(subprocess.check_output(['findmnt', '--noheadings', '--output', 'TARGET', '--target', str(path)], text=True).strip())


def limine_version(volume):
    """Version of the deployed Limine: firmware LoaderInfo on UEFI, the stage file on BIOS."""
    if Path('/sys/firmware/efi').exists():
        match = re.fullmatch(r'Limine (\d+)\.(\d+)\S*', loader_info())
        return (int(match[1]), int(match[2])) if match else None
    for name in LIMINE_BIOS_STAGE:
        stage = volume / name
        if stage.is_file():
            match = re.search(rb'Limine (\d+)\.(\d+)\.\d+', stage.read_bytes())
            return (int(match[1]), int(match[2])) if match else None
    return None


def limine_detected():
    """Return the limine.conf of a confirmed Limine 12+ boot, else None."""
    if not shutil.which('findmnt'):
        return None
    efi = Path('/sys/firmware/efi').exists()
    if efi and not loader_info().startswith('Limine '):
        return None
    names = (LIMINE_EFI_CONFIGS if efi else ()) + LIMINE_CONFIGS
    found = []
    for volume in boot_volumes():
        for name in names:
            path = volume / name
            # FAT names are case-insensitive, so one file can show up under two spellings.
            if path.is_file() and not any(os.path.samefile(path, other) for other in found):
                found.append(path)
    if not found:
        return None
    if len(found) > 1:
        print('Several limine.conf files found; which one Limine reads needs manual review: '
              + ', '.join(map(str, found)))
        return None
    config = found[0]
    if config.is_symlink():
        return None
    version = limine_version(mount_of(config))
    if version is None or version < (12, 0):
        # Limine 12 takes RRGGBB interface colours; older releases took a 0-7 index.
        print('Limine 12 or newer is required for its theme (deploy the updated Limine files first).')
        return None
    print(f'Limine {version[0]}.{version[1]} configuration found: {config}')
    if not ask(f'Confirm this machine boots with Limine and reads {config}'):
        return None
    return config


def limine_theme(text, wallpaper):
    """Put the managed appearance block first; switch off other copies of its options."""
    lines = text.splitlines(keepends=True)
    begins = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == LIMINE_BEGIN]
    ends = [i for i, line in enumerate(lines) if line.rstrip('\r\n') == LIMINE_END]
    if begins or ends:
        # Only replace our own leading block; never remove intervening user edits.
        if begins != [0] or len(ends) != 1:
            raise ValueError('Penumbra Limine block was edited/moved; review manually.')
        lines = lines[ends[0] + 1:]
        if lines and not lines[0].strip():
            lines = lines[1:]
    for index, line in enumerate(lines):
        match = re.match(r'\s*([A-Za-z_]+)\s*:', line)
        if match and match[1].lower() in LIMINE_KEYS:
            lines[index] = LIMINE_OFF + line
    block = f"""{LIMINE_BEGIN}
# Appearance only: entries, timeout and default entry are unchanged.
wallpaper: {wallpaper}
wallpaper_style: centered
backdrop: 07070b
interface_branding: P E N U M B R A
interface_branding_colour: b8a4cf
interface_help_colour: b69af7
interface_help_colour_bright: dac5ff
term_palette: 0d0a12;ef8fa4;a5ccb3;e5c89a;a1a5e9;b69af7;9ccbd2;ded5e8
term_palette_bright: 71637f;f7a3b6;b9e0c6;f4dab0;b8bdf5;ceb4ff;b4e0e5;faf5ff
term_foreground: c8bbde
term_foreground_bright: f3eaff
term_background: ff000000
term_background_bright: ff000000
term_margin: 0
term_margin_gradient: 0
{LIMINE_END}

"""
    return block + ''.join(lines)


def limine_entries(text):
    """Yield (protocol, [line indexes of cmdline options]) for each menu entry."""
    lines = text.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if re.match(r'\s*/', line)] + [len(lines)]
    for start, stop in zip(starts, starts[1:]):
        protocol, cmdlines = None, []
        for index in range(start + 1, stop):
            match = re.match(r'\s*([A-Za-z_]+)\s*:\s*(.*?)\s*$', lines[index])
            if not match:
                continue
            key = match[1].lower()
            if key == 'protocol':
                protocol = match[2].lower()
            elif key in ('cmdline', 'kernel_cmdline'):
                cmdlines.append(index)
        yield protocol, cmdlines


def limine_splash(text, uki=False):
    """Append splash to every Linux entry's command line; other entries stay as they are."""
    lines = text.splitlines(keepends=True)
    for protocol, cmdlines in limine_entries(text):
        if uki:
            # Limine hands an EFI entry's cmdline to the UKI, which then ignores its own.
            if protocol in ('efi', 'uefi', 'efi_chainload') and any('splash' not in lines[i].split(':', 1)[1].split() for i in cmdlines):
                raise ValueError('A Limine EFI entry passes its own command line without splash; add it there manually.')
            continue
        if protocol != 'linux':
            continue
        if not cmdlines:
            raise ValueError('A Limine Linux entry has no cmdline; add splash manually.')
        for index in cmdlines:
            key, value = lines[index].split(':', 1)
            ending = value[len(value.rstrip('\r\n')):]
            words = value.split()
            if '${' in value:
                raise ValueError('Limine command lines built from macros require manual setup.')
            if any(w in ('plymouth.enable=0', 'rd.plymouth=0', 'nosplash') for w in words):
                raise ValueError('Plymouth is explicitly disabled in a Limine command line.')
            if 'splash' not in words:
                lines[index] = key + ':' + value.rstrip() + ' splash' + ending
    return ''.join(lines)


def limine_entry_tool():
    # limine-entry-tool (limine-mkinitcpio-hook, limine-snapper-sync) rewrites entries from
    # /etc/default/limine, so command lines belong there rather than in limine.conf.
    return Path('/etc/default/limine').exists() or bool(shutil.which('limine-entry-tool'))


def replace_text(tx, destination, text):
    """Swap in new contents through a staged file, so a failed write leaves the original."""
    tx.save(destination)
    staged = tx.stage(destination)
    staged.write_text(text)
    os.replace(staged, destination)


def apply_limine(config):
    volume = mount_of(config)
    artwork = config.parent / 'penumbra'
    wallpaper = 'boot():/' + str((artwork / 'background.png').relative_to(volume))
    if not re.fullmatch(r'boot\(\):/[A-Za-z0-9_./-]+', wallpaper):
        raise ValueError('Unsupported Limine artwork path.')
    with Transaction('limine') as tx:
        deploy(tx, ROOT / 'boot/limine', artwork)
        replace_text(tx, config, limine_theme(config.read_text(), wallpaper))
    print('Penumbra Limine theme applied. Entries, timeout and default entry were preserved.')
    if limine_entry_tool():
        print('limine-entry-tool keeps global options; if an update drops the theme, run --boot-only again.')


REFIND_BEGIN = '# BEGIN PENUMBRA REFIND'
REFIND_END = '# END PENUMBRA REFIND'
REFIND_CONFIGS = ('EFI/refind/refind.conf', 'EFI/BOOT/refind.conf', 'refind/refind.conf')


def refind_booted(config):
    if loader_info().startswith('rEFInd '):
        return True
    if shutil.which('efibootmgr'):
        result = subprocess.run(['efibootmgr', '-v'], text=True, capture_output=True)
        current = re.search(r'^BootCurrent: ([0-9A-Fa-f]{4})$', result.stdout, re.M)
        if result.returncode == 0 and current:
            entry = re.search(r'^Boot' + current[1] + r'\*?\s+(.+)$', result.stdout, re.M)
            if entry and re.search(r'refind', entry[1], re.I):
                return True
    # rEFInd records its own PreviousBoot variable in vars/ (use_nvram false) or NVRAM.
    return ((config.parent / 'vars/PreviousBoot').is_file()
            or Path('/sys/firmware/efi/efivars/PreviousBoot-36d08fa7-cf0b-42f5-8f14-68df73ed3740').is_file())


def refind_detected():
    """Return the refind.conf of a confirmed rEFInd boot, else None."""
    if not shutil.which('findmnt') or not Path('/sys/firmware/efi').exists():
        return None
    found = []
    for volume in boot_volumes():
        for name in REFIND_CONFIGS:
            path = volume / name
            if path.is_file() and not any(os.path.samefile(path, other) for other in found):
                found.append(path)
    if not found:
        return None
    if len(found) > 1:
        print('Several refind.conf files found; which one rEFInd reads needs manual review: '
              + ', '.join(map(str, found)))
        return None
    config = found[0]
    if config.is_symlink() or not refind_booted(config):
        return None
    print(f'rEFInd configuration found: {config}')
    if not ask(f'Confirm this machine boots with rEFInd and reads {config}'):
        return None
    return config


def refind_theme(text):
    """Append the managed rEFInd theme include while preserving existing configuration."""
    if REFIND_BEGIN in text or REFIND_END in text:
        pattern = r'\n' + re.escape(REFIND_BEGIN) + r'\n.*?\n' + re.escape(REFIND_END) + r'\n\Z'
        if text.count(REFIND_BEGIN) != 1 or text.count(REFIND_END) != 1 or not re.search(pattern, text, re.S):
            raise ValueError('Penumbra rEFInd block was edited/moved; review manually.')
        text = re.sub(pattern, '', text, flags=re.S)
    else:
        text = re.sub(r'\n[ \t]*include[ \t]+themes/penumbra/theme\.conf[ \t]*\n\Z', '\n', text)
    block = (f'\n{REFIND_BEGIN}\n'
             '# Appearance only: boot entries, timeout and scanning settings are unchanged.\n'
             'include themes/penumbra/theme.conf\n'
             f'{REFIND_END}\n')
    return text + block


def refind_splash(text):
    """Ensure the primary entry in refind_linux.conf includes splash."""
    lines = text.splitlines(keepends=True)
    updated_any = False
    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue
        match = re.match(r'^(\s*"[^"]+"\s+")([^"]*)("\s*\r?\n?)$', line)
        if not match:
            raise ValueError('Custom refind_linux.conf format requires manual setup.')
        prefix, options, suffix = match.groups()
        words = options.split()
        if not updated_any:
            if any(w in ('plymouth.enable=0', 'rd.plymouth=0', 'nosplash') for w in words):
                raise ValueError('Plymouth is explicitly disabled in refind_linux.conf.')
            if 'splash' not in words:
                options = (options.rstrip() + ' splash').lstrip()
                lines[index] = prefix + options + suffix
            updated_any = True
    if not updated_any:
        raise ValueError('refind_linux.conf has no boot options.')
    return ''.join(lines)


def apply_refind(config):
    with Transaction('refind') as tx:
        deploy(tx, ROOT / 'boot/refind', config.parent / 'themes/penumbra')
        replace_text(tx, config, refind_theme(config.read_text()))
    print('Penumbra rEFInd theme applied. Entries, timeout and scanning settings were preserved.')


def uki_section(image, section):
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / 'section'
        # Supply an output copy: objcopy must never rewrite the source EFI image.
        run('objcopy', '--dump-section', f'{section}={output}', str(image), str(Path(directory) / 'copy.efi'))
        return output.read_bytes()


def check_uki(image):
    if not shutil.which('objcopy'):
        raise ValueError('UKI validation requires objcopy (binutils).')
    # Signing and custom ukify settings need a separate integration path.
    for name in ('/etc/kernel/uki.conf', '/usr/lib/kernel/uki.conf'):
        path = Path(name)
        if path.exists() and any(line.strip() and not line.lstrip().startswith(('#', ';')) for line in path.read_text().splitlines()):
            raise ValueError('Custom UKI/signing configuration requires manual setup.')
    for directory in ('/etc/kernel/uki.conf.d', '/usr/lib/kernel/uki.conf.d', '/etc/cmdline.d'):
        if list(Path(directory).glob('*.conf')):
            raise ValueError('UKI/cmdline drop-ins require manual setup.')
    secure = Path('/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c')
    if not secure.is_file() or secure.read_bytes()[4:] != b'\x00':
        raise ValueError('Automatic UKI rebuild requires verified disabled Secure Boot.')
    # The PE certificate table must be empty; do not silently remove an existing signature.
    data = image.read_bytes()
    offset = int.from_bytes(data[60:64], 'little')
    optional = offset + 24
    if data[:2] != b'MZ' or data[offset:offset + 4] != b'PE\0\0' or data[optional:optional + 2] != b'\x0b\x02':
        raise ValueError('Expected a PE32+ UKI.')
    certificate = optional + 112 + 4 * 8
    if len(data) < certificate + 8 or any(data[certificate:certificate + 8]):
        raise ValueError('Signed or malformed UKI requires manual setup.')
    embedded = uki_section(image, '.cmdline').rstrip(b'\0').decode().strip()
    source = Path('/etc/kernel/cmdline')
    if not source.is_file() or source.read_text().strip() != embedded:
        raise ValueError('/etc/kernel/cmdline must match the existing UKI before rebuilding.')
    words = embedded.split()
    if any(w in words for w in ('nosplash', 'plymouth.enable=0', 'rd.plymouth=0')):
        raise ValueError('Plymouth is explicitly disabled in the UKI kernel command line.')


def uki_splash_cmdline(text):
    """Append only splash; retain quoting and spacing of existing arguments."""
    value = text.strip()
    if '\n' in value or '\r' in value or '#' in value or '--' in value.split():
        raise ValueError('Custom UKI kernel command line requires manual setup.')
    if any(w in value.split() for w in ('nosplash', 'plymouth.enable=0', 'rd.plymouth=0')):
        raise ValueError('Plymouth is explicitly disabled in the UKI kernel command line.')
    return value if 'splash' in value.split() else value + (' ' if value else '') + 'splash'


def without_stock_splash(options):
    """Remove Arch's pre-kernel logo; retain custom bitmaps and other options."""
    result = options[:]
    for index in range(len(result) - 1):
        if result[index:index + 2] == ['--splash', '/usr/share/systemd/bootctl/splash-arch.bmp']:
            del result[index:index + 2]
            break
    return result


def stock_splash_preset_updates(directory):
    updates = {}
    for path in sorted(directory.glob('*.preset')):
        original = path.read_text()
        def replace(match):
            options = shlex.split(literal(match[2]))
            updated = without_stock_splash(options)
            if updated == options:
                return match[0]
            return match[1] + shlex.quote(shlex.join(updated))
        updated = re.sub(r'^(\s*\w+_options=)([^\n]*)', replace, original, flags=re.M)
        if updated != original:
            if path.is_symlink():
                raise ValueError('Symlinked mkinitcpio preset requires manual setup.')
            updates[path] = updated
    return updates


def apply_plymouth(limine=None, refind=None):
    """Install the splash; `limine` or `refind` is the confirmed loader config, else GRUB boots."""
    if not shutil.which('mkinitcpio') or not Path('/usr/lib/initcpio/install/plymouth').is_file():
        raise ValueError('Supported mkinitcpio Plymouth hook is missing.')
    if not Path('/usr/lib/plymouth/two-step.so').is_file():
        raise ValueError('Plymouth two-step plugin missing.')
    if any(Path(d).exists() and any(Path(d).iterdir()) for d in ('/etc/initcpio/post', '/usr/lib/initcpio/post')):
        raise ValueError('Custom mkinitcpio post hooks require manual setup to avoid extra boot writes.')
    if list(Path('/etc/mkinitcpio.conf.d').glob('*.conf')):
        raise ValueError('mkinitcpio drop-ins require manual setup; no hooks changed.')
    config = Path('/etc/mkinitcpio.conf')
    # The boot loader's own copy of the kernel command line, which gains splash.
    defaults = limine or (Path('/boot/refind_linux.conf') if refind else Path('/etc/default/grub'))
    hooks = plymouth_hooks(config.read_text())
    jobs = preset_jobs(Path('/etc/mkinitcpio.d'))
    uki_jobs = [job for job in jobs if job[1].suffix == '.efi']
    if uki_jobs and len(uki_jobs) != len(jobs):
        raise ValueError('Mixed UKI/initramfs presets require manual setup.')
    for _, image, _ in uki_jobs:
        check_uki(image)
    source = Path('/etc/kernel/cmdline')
    if uki_jobs:
        cmdline = uki_splash_cmdline(source.read_text())
    elif refind:
        if not defaults.is_file():
            raise ValueError('Missing /boot/refind_linux.conf for rEFInd Plymouth integration.')
        entries = refind_splash(defaults.read_text())
    elif not limine:
        cmdline = splash_defaults(defaults.read_text())
    if limine:
        entries = limine_splash(defaults.read_text(), uki=bool(uki_jobs))
        if entries != defaults.read_text() and limine_entry_tool():
            raise ValueError('limine-entry-tool manages these entries: add splash to KERNEL_CMDLINE '
                             'in /etc/default/limine, regenerate them, then retry.')
    preset_updates = stock_splash_preset_updates(Path('/etc/mkinitcpio.d')) if uki_jobs else {}
    if uki_jobs:
        jobs = [(kernel, image, without_stock_splash(options)) for kernel, image, options in jobs]
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
        if uki_jobs:
            tx.save(source)
            source.write_text(cmdline + '\n')
        for path, updated in preset_updates.items():
            tx.save(path)
            path.write_text(updated)
        theme = Path('/usr/share/plymouth/themes/penumbra')
        deploy(tx, ROOT / 'boot/plymouth', theme)
        # Keyboard layout names are drawn from a sprite sheet whose offsets are compiled into
        # Plymouth, so only the packaged sheet can match; without one the layout is not shown.
        keymaps = Path('/usr/share/plymouth/themes/spinner/keymap-render.png')
        if keymaps.is_file():
            shutil.copy2(keymaps, theme / 'keymap-render.png')
        config.write_text(hooks)
        if limine or (refind and not uki_jobs):
            if entries != defaults.read_text():
                replace_text(tx, defaults, entries)
        elif not uki_jobs:
            defaults.write_text(cmdline)
        run('plymouth-set-default-theme', 'penumbra')
        staged_images = []
        for kernel, image, options in jobs:
            stage = tx.stage(image)
            uki = image.suffix == '.efi'
            uki_options = ['--cmdline', '/etc/kernel/cmdline'] if uki else []
            run('mkinitcpio', '-c', str(config), '-k', str(kernel), '-U' if uki else '-g', str(stage), *options, *uki_options)
            if uki:
                if uki_section(stage, '.cmdline').rstrip(b'\0').decode().strip() != cmdline:
                    raise ValueError('Rebuilt UKI changed the embedded kernel command line.')
                with tempfile.TemporaryDirectory() as directory:
                    initrd = Path(directory) / 'initrd'
                    initrd.write_bytes(uki_section(stage, '.initrd'))
                    listing = subprocess.check_output(['lsinitcpio', str(initrd)], text=True)
            else:
                listing = subprocess.check_output(['lsinitcpio', str(stage)], text=True)
            if 'usr/bin/plymouth' not in listing or 'penumbra.plymouth' not in listing:
                raise ValueError('Generated initramfs does not contain Plymouth and Penumbra.')
            os.chmod(stage, image.stat().st_mode & 0o777)
            staged_images.append((stage, image))
        # UKIs carry their command line and initrd; keep their existing GRUB chainload entries.
        # Limine and rEFInd entries name the images directly, so they need no regeneration.
        if not uki_jobs and not limine and not refind:
            generate_grub(tx)
        for stage, image in staged_images:
            os.replace(stage, image)
    print('Penumbra Plymouth theme applied and initramfs rebuilt. Reboot when convenient.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--restore', type=Path, help='restore a recorded boot transaction (newest first)')
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run through ./install.sh --boot-only or sudo.')
    with open('/run/penumbra-boot.lock', 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if args.restore:
            directory = args.restore.resolve()
            if directory.parent != BACKUPS or not (directory / 'manifest.json').is_file():
                parser.error('Choose a backup directory under ' + str(BACKUPS))
            restore(directory)
            return
        limine = limine_detected()
        print('Limine: ' + ('verified/confirmed.' if limine else 'not verified; its theme will be skipped.'))
        refind = None if limine else refind_detected()
        print('rEFInd: ' + ('verified/confirmed.' if refind else 'not verified; its theme will be skipped.'))
        # A confirmed Limine or rEFInd boot settles which loader ran; GRUB files may still be installed.
        available = not (limine or refind) and grub_detected()
        print('GRUB: ' + ('verified/confirmed.' if available else 'not in use or not verified; its theme will be skipped.'))
        if limine and ask('Apply the Penumbra Limine theme (back up limine.conf; entries unchanged)'):
            apply_limine(limine)
        if refind and ask('Apply the Penumbra rEFInd theme (back up refind.conf; entries unchanged)'):
            apply_refind(refind)
        if available and ask('Apply the Penumbra GRUB theme (back up and preserve existing menu)'):
            apply_grub()
        # ./install.sh --boot-only offers to install it, with the distribution's package manager.
        installed = bool(shutil.which('plymouth-set-default-theme'))
        print('Plymouth: ' + ('installed.' if installed else 'not installed.'))
        if installed and (available or limine or refind) and ask('Apply Penumbra to Plymouth (add splash/hook and rebuild initramfs)'):
            apply_plymouth(limine, refind)
        elif installed and not (available or limine or refind):
            print('Plymouth theme is in boot/plymouth; boot integration requires a verified GRUB, Limine or rEFInd setup.')


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt(f'Signal {signum}')
    signal.signal(signal.SIGTERM, interrupted)
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, KeyboardInterrupt) as error:
        print(f'Boot theming stopped: {error}', flush=True)
        raise SystemExit(1)
