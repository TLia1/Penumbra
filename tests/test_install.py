"""Every distribution folder gives install.sh what it needs, and every template fills in."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
DISTROS = sorted(p.parent.name for p in (ROOT / 'distro').glob('*/distro.sh'))
SETTINGS = 'settings=([kb_layout]=us [kb_variant]= [kb_options]= [scale]=auto [numlock]=on [shell]=fish)'


def bash(script, distro, *args):
    """Run `script` with install.sh's functions loaded for `distro`; `args` are "$@". HOME is a
    throwaway folder, so nothing can reach your own configuration."""
    with tempfile.TemporaryDirectory() as home:
        return subprocess.run(['bash', '-c', f'source "$0"; DISTRO=$1; shift; load_distro; {script}',
                               str(ROOT / 'install.sh'), distro, *args],
                              capture_output=True, text=True, env={**os.environ, 'HOME': home})


def templates(distro):
    """The text files install.sh fills in for `distro`."""
    files = [p for folder in (ROOT / 'config', ROOT / 'bin', ROOT / 'share', ROOT / 'distro' / distro)
             for p in folder.rglob('*') if p.is_file()]
    return [str(p) for p in files if b'@@' in p.read_bytes() and b'\0' not in p.read_bytes()]


class Distributions(unittest.TestCase):
    def test_arch_is_supported(self):
        self.assertIn('arch', DISTROS)

    def test_distro_sh_defines_everything(self):
        for distro in DISTROS:
            with self.subTest(distro=distro):
                result = bash('(( ${#PACKAGES[@]} ))', distro)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_updates_module(self):
        for distro in DISTROS:
            path = ROOT / 'distro' / distro / 'share/penumbra/updates.py'
            if not path.exists():
                continue
            with self.subTest(distro=distro):
                spec = importlib.util.spec_from_file_location('updates', path)
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                for source in module.sources():
                    self.assertTrue(source['name'] and source['command'], source)
                self.assertIsInstance(module.notes(), list)
                self.assertTrue(all(name and command for name, command in module.upgrades()))

    def test_templates_fill_in(self):
        for distro in DISTROS:
            with self.subTest(distro=distro):
                result = bash(f'{SETTINGS}; set_placeholders; for f; do render_template "$f"; done',
                              distro, *templates(distro))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertNotRegex(result.stdout, r'@@[A-Z_]+@@')


# Stand-ins for the apps in apps/ (and systemctl, for the uninstall): each records how it was
# called. bat answers the question install.sh asks it.
STUB = '''#!/bin/sh
echo "${0##*/} $*" >> "$HOME/calls"
[ "${0##*/} $1" = "bat --config-file" ] && echo "$HOME/.config/bat/config"
exit 0
'''
# Your own settings before the install, then two installs: the second must change nothing.
APP_SETUP = '''
runs=$HOME/.local/state/penumbra/backups; PATH=$1:$PATH
mkdir -p ~/.config/mozilla/firefox/abc.default/chrome ~/.config/mpv ~/.config/vesktop/settings ~/.config/btop
printf '[Profile0]\\nName=default\\nIsRelative=1\\nPath=abc.default\\n' > ~/.config/mozilla/firefox/profiles.ini
printf '#nav-bar { padding: 0 }\\n' > ~/.config/mozilla/firefox/abc.default/chrome/userChrome.css
printf '[quiet]\\nvolume=50' > ~/.config/mpv/mpv.conf
printf 'color_theme = "Default"\\nupdate_ms = 1000\\n' > ~/.config/btop/btop.conf
echo '{"enabledThemes": ["mine.css"]}' > ~/.config/vesktop/settings/settings.json
git config --file ~/.gitconfig delta.features side-by-side
BACKUP=$runs/20260101-000000; mkdir -p "$BACKUP"; install_app_colors >/dev/null
find ~ -type f ! -path "$runs/*" ! -name calls ! -name first -exec md5sum {} + | sort > ~/first
BACKUP=$runs/20260102-000000; mkdir -p "$BACKUP"; install_app_colors >/dev/null
find ~ -type f ! -path "$runs/*" ! -name calls ! -name first -exec md5sum {} + | sort | diff ~/first - >&2
'''


class AppColors(unittest.TestCase):
    def run_install(self, checks):
        with tempfile.TemporaryDirectory() as stubs:
            for app in [p.name for p in (ROOT / 'apps').iterdir()] + ['code', 'codium', 'systemctl']:
                path = Path(stubs) / app
                path.write_text(STUB)
                path.chmod(0o755)
            result = bash(APP_SETUP + checks, 'arch', stubs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout

    def test_every_app_is_turned_on_once(self):
        out = self.run_install('''
            grep -x 'color_theme = "penumbra"' ~/.config/btop/btop.conf; grep -c . ~/.config/btop/btop.conf
            cat ~/.config/bat/config; grep -c 'cache --build' ~/calls
            git config --file ~/.gitconfig delta.features; git config --file ~/.gitconfig --get-all include.path
            git config --file ~/.config/git/penumbra-delta.gitconfig delta.penumbra.syntax-theme
            cat ~/.config/yazi/theme.toml; test -s ~/.config/yazi/flavors/penumbra.yazi/tmtheme.xml && echo tmtheme
            cat ~/.config/zathura/zathurarc ~/.config/mpv/mpv.conf
            python3 -c 'import json,os; print(json.load(open(os.path.expanduser("~/.config/vesktop/settings/settings.json")))["enabledThemes"])'
            cat ~/.config/mozilla/firefox/abc.default/chrome/userChrome.css ~/.config/mozilla/firefox/abc.default/user.js
            grep -c -- '--install-extension' ~/calls
        ''')
        self.assertEqual(out.split('\n'), [
            'color_theme = "penumbra"', '2',
            '--theme="Penumbra"', '2',
            'side-by-side penumbra', '~/.config/git/penumbra-delta.gitconfig',
            'Penumbra',
            '[flavor]', 'dark = "penumbra"', 'tmtheme',
            'include penumbra-colors', 'include="~~/penumbra.conf"', '[quiet]', 'volume=50',
            "['mine.css', 'penumbra.theme.css']",
            '@import "penumbra.css";', '#nav-bar { padding: 0 }',
            'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);',
            '4', ''])

    def test_uninstall_puts_your_files_back(self):
        out = self.run_install('''
            STAMP=later uninstall_user >/dev/null
            cat ~/.config/mpv/mpv.conf; echo; cat ~/.config/btop/btop.conf
            cat ~/.config/mozilla/firefox/abc.default/chrome/userChrome.css
            git config --file ~/.gitconfig --list
            { ls ~/.config/zathura/zathurarc ~/.config/mozilla/firefox/abc.default/user.js 2>&1 || true; } | grep -c 'No such file'
            grep -c -- '--uninstall-extension' ~/calls
        ''')
        self.assertEqual(out.split('\n'), [
            '[quiet]', 'volume=50',
            'color_theme = "Default"', 'update_ms = 1000',
            '#nav-bar { padding: 0 }',
            'delta.features=side-by-side',
            '2', '2', ''])


if __name__ == '__main__':
    unittest.main()
