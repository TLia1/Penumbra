"""Every distribution folder gives install.sh what it needs, and every template fills in."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
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


def settings_defaults():
    """penumbra-settings' DEFAULTS, loaded from the script."""
    loader = importlib.machinery.SourceFileLoader('penumbra_settings', str(ROOT / 'bin/penumbra-settings'))
    spec = importlib.util.spec_from_loader('penumbra_settings', loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module.DEFAULTS


class SettingsDefaults(unittest.TestCase):
    """install.sh, penumbra-settings and hyprland.lua each know the settings' defaults."""

    def test_installer_matches_penumbra_settings(self):
        # With nothing detected: no keyboard from localectl, and Lia Files installed.
        result = bash('localectl_field() { :; }; lia_files_installed() { true; }; settings=(); detect_settings; '
                      'for key in "${SETTING_KEYS[@]}"; do printf "%s=%s\\n" "$key" "${settings[$key]}"; done', 'arch')
        self.assertEqual(result.returncode, 0, result.stderr)
        installer = dict(line.split('=', 1) for line in result.stdout.splitlines())
        defaults = settings_defaults()
        self.assertEqual(list(installer), list(defaults), 'SETTING_KEYS and DEFAULTS list different keys or orders')
        self.assertEqual(installer, defaults)

    def test_hyprland_matches_penumbra_settings(self):
        text = (ROOT / 'config/hypr/hyprland.lua').read_text()
        table = re.search(r'local s = \{(.*?)\}\n', text).group(1)
        lua = dict(re.findall(r'(\w+) = "([^"]*)"', table))
        self.assertTrue(lua)
        defaults = settings_defaults()
        self.assertEqual({key: defaults[key] for key in lua}, lua)


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
mkdir -p ~/.config/mozilla/firefox/abc.default/chrome ~/.config/mpv ~/.config/vesktop/settings ~/.config/btop ~/.config/cava
printf '[Profile0]\\nName=default\\nIsRelative=1\\nPath=abc.default\\n' > ~/.config/mozilla/firefox/profiles.ini
printf '#nav-bar { padding: 0 }\\n' > ~/.config/mozilla/firefox/abc.default/chrome/userChrome.css
printf '/* My content styles */\\n' > ~/.config/mozilla/firefox/abc.default/chrome/userContent.css
printf '[quiet]\\nvolume=50' > ~/.config/mpv/mpv.conf
printf 'color_theme = "Default"\\nupdate_ms = 1000\\n' > ~/.config/btop/btop.conf
echo '{"enabledThemes": ["mine.css"]}' > ~/.config/vesktop/settings/settings.json
printf '[input]\\nmethod = fifo\\n[color]\\nforeground = cyan\\n' > ~/.config/cava/config
git config --file ~/.gitconfig delta.features side-by-side
BACKUP=$runs/20260101-000000; mkdir -p "$BACKUP"; install_app_colors >/dev/null
find ~ -type f ! -path "$runs/*" ! -name calls ! -name first -exec md5sum {} + | sort > ~/first
BACKUP=$runs/20260102-000000; mkdir -p "$BACKUP"; install_app_colors >/dev/null
[[ $(find ~ -type f ! -path "$runs/*" ! -name calls ! -name first -exec md5sum {} + | sort) = $(<~/first) ]]
'''


class AppColors(unittest.TestCase):
    def run_install(self, checks):
        with tempfile.TemporaryDirectory() as stubs:
            for app in [p.name for p in (ROOT / 'apps').iterdir()] + ['code', 'codium', 'systemctl', 'gsettings']:
                path = Path(stubs) / app
                path.write_text(STUB)
                path.chmod(0o755)
            # Never reach the real Flatpak or desktop settings from installer tests.
            flatpak = Path(stubs) / 'flatpak'
            flatpak.write_text('#!/bin/sh\nexit 1\n')
            flatpak.chmod(0o755)
            result = bash(APP_SETUP + checks, 'arch', stubs)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, '')
        return result.stdout

    def test_glass_and_cava_preserve_settings_and_restore(self):
        out = self.run_install('''
            python3 -c 'import json,os; s=json.load(open(os.path.expanduser("~/.config/vesktop/settings/settings.json"))); print(s["transparent"], s["enabledThemes"])'
            cat ~/.config/cava/config
            test -s ~/.config/cava/themes/penumbra
            STAMP=later uninstall_user >/dev/null
            cat ~/.config/cava/config
            cat ~/.config/vesktop/settings/settings.json
        ''')
        self.assertEqual(out.splitlines(), [
            "True ['mine.css', 'penumbra.theme.css']",
            '[input]', 'method = fifo', '[color]', "theme = 'penumbra'", 'foreground = cyan',
            '[input]', 'method = fifo', '[color]', 'foreground = cyan',
            '{"enabledThemes": ["mine.css"]}',
        ])

    def test_firefox_content_and_spicetify_install_and_rollback(self):
        out = self.run_install('''
            cat ~/.config/mozilla/firefox/abc.default/chrome/userContent.css
            test -s ~/.config/mozilla/firefox/abc.default/chrome/penumbra-content.css
            test -s ~/.config/spicetify/Themes/Penumbra/color.ini
            test -s ~/.config/spicetify/Themes/Penumbra/user.css
            STAMP=later uninstall_user >/dev/null
            cat ~/.config/mozilla/firefox/abc.default/chrome/userContent.css
            test ! -e ~/.config/spicetify/Themes/Penumbra/color.ini
        ''')
        self.assertEqual(out.splitlines(), ['@import "penumbra-content.css";',
                                          '/* My content styles */', '/* My content styles */'])

    def test_cava_keeps_named_theme_and_handles_fresh_config(self):
        out = self.run_install('''
            printf '[color]\\ntheme = "my-theme"\\n' > ~/.config/cava/config
            color_cava
            cat ~/.config/cava/config
            rm ~/.config/cava/config
            color_cava
            color_cava
            cat ~/.config/cava/config
        ''')
        self.assertEqual(out.splitlines(), ['[color]', 'theme = "my-theme"',
            '[general]', 'framerate = 60', 'sleep_timer = 2', '', '[color]', "theme = 'penumbra'"])

    def test_vesktop_enables_glass_with_existing_theme_or_fresh_settings(self):
        out = self.run_install('''
            echo '{"enabledThemes": ["penumbra.theme.css"], "transparent": false, "custom": 42}' > ~/.config/vesktop/settings/settings.json
            color_vesktop
            python3 -c 'import json,os; s=json.load(open(os.path.expanduser("~/.config/vesktop/settings/settings.json"))); print(s["transparent"], s["enabledThemes"], s["custom"])'
            rm ~/.config/vesktop/settings/settings.json
            color_vesktop
            color_vesktop
            python3 -c 'import json,os; s=json.load(open(os.path.expanduser("~/.config/vesktop/settings/settings.json"))); print(s["transparent"], s["enabledThemes"])'
        ''')
        self.assertEqual(out.splitlines(), ["True ['penumbra.theme.css'] 42", "True ['penumbra.theme.css']"])

    def test_file_manager_detection_preserves_existing_choice(self):
        out = self.run_install('''
            localectl_field() { :; }
            settings=(); detect_settings; echo "${settings[file_manager]}"
            python3 "$ROOT/bin/penumbra-settings" get | python3 -c 'import json,sys; print(json.load(sys.stdin)["file_manager"])'
            settings[file_manager]=custom; detect_settings; echo "${settings[file_manager]}"
            missing=(lia-files)
            command() {
                if [[ $1 = -v && " ${missing[*]} " = *" $2 "* ]]; then return 1; fi
                if [[ $1 = -v && $2 = dolphin ]]; then echo /usr/bin/dolphin; return 0; fi
                builtin command "$@"
            }
            settings=(); detect_settings; echo "${settings[file_manager]}"
            missing=(lia-files dolphin)
            settings=(); detect_settings; echo "${settings[file_manager]}"
        ''')
        self.assertEqual(out.splitlines(), ['io.github.lia.Files', 'io.github.lia.Files', 'custom',
                                            'org.kde.dolphin', 'io.github.lia.Files'])

    def test_saved_dolphin_becomes_lia_files_once_installed(self):
        out = self.run_install('''
            SETTINGS_FILE=~/.config/penumbra/settings.conf; mkdir -p ~/.config/penumbra
            printf '%s\\n' file_manager=org.kde.dolphin terminal=kitty > "$SETTINGS_FILE"
            settings=(); load_saved_settings; echo "${settings[file_manager]}"
            lia_files_installed() { false; }
            settings=(); load_saved_settings; echo "${settings[file_manager]}"
            settings=([file_manager]=org.kde.dolphin); lia_files_installed() { true; }
            load_saved_settings; echo "${settings[file_manager]}"
        ''')
        self.assertEqual(out.splitlines(), ['io.github.lia.Files', 'org.kde.dolphin', 'org.kde.dolphin'])

    def test_folders_open_in_the_installed_file_manager(self):
        out = self.run_install('''
            xdg-mime() { if [[ $1 = query ]]; then cat ~/folders 2>/dev/null; else echo "$2" > ~/folders; fi; }
            BACKUP=$runs/20260104-000000; mkdir -p "$BACKUP"
            XDG_DATA_HOME=~/data XDG_DATA_DIRS=/nonexistent
            settings=([file_manager]=org.example.Files); set_folder_default; cat ~/folders 2>/dev/null || echo none
            mkdir -p ~/data/applications; touch ~/data/applications/org.example.Files.desktop
            set_folder_default; cat ~/folders
            set_folder_default
        ''')
        self.assertEqual(out.splitlines(), ['none', 'Folders open in org.example.Files.', 'org.example.Files.desktop'])

    def test_stale_user_lia_overrides_are_removed(self):
        out = self.run_install('''
            XDG_DATA_HOME=~/data
            mkdir -p ~/data/dbus-1/services ~/data/xdg-desktop-portal/portals ~/data/applications
            printf '[D-BUS Service]\\nExec=/nonexistent/lia-files-portal --file-chooser-portal\\n' \\
                > ~/data/dbus-1/services/org.freedesktop.impl.portal.desktop.lia.service
            touch ~/data/xdg-desktop-portal/portals/lia.portal
            printf '[Desktop Entry]\\nExec=/bin/sh %%U\\n' > ~/data/applications/io.github.lia.Files.desktop
            clean_stale_lia_overrides && echo cleaned
            test ! -e ~/data/dbus-1/services/org.freedesktop.impl.portal.desktop.lia.service
            test ! -e ~/data/xdg-desktop-portal/portals/lia.portal
            test -e ~/data/applications/io.github.lia.Files.desktop
            clean_stale_lia_overrides || echo kept
        ''')
        self.assertEqual(out.splitlines(), ['cleaned', 'kept'])

    def test_flatpak_gets_theme_schemes_and_action(self):
        out = self.run_install('''
            flatpak() { [[ $1 = info ]]; }
            BACKUP=$runs/20260103-000000; mkdir -p "$BACKUP"
            install_app_colors >/dev/null
            test -s ~/.var/app/io.github.lia.Files/config/lia-files/penumbra.css
            test -s ~/.var/app/io.github.lia.Files/data/gtksourceview-5/styles/penumbra.xml
            test -s ~/.var/app/io.github.lia.Files/data/lia-files/actions/penumbra-wallpaper.desktop
            echo flatpak
        ''')
        self.assertEqual(out.strip(), 'flatpak')

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
            '[flavor]', 'dark = "penumbra"', 'light = "penumbra"', 'tmtheme',
            'include penumbra-colors', 'include="~~/penumbra.conf"', '[quiet]', 'volume=50',
            "['mine.css', 'penumbra.theme.css']",
            '@import "penumbra.css";', '#nav-bar { padding: 0 }',
            'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);',
            'user_pref("widget.use-xdg-desktop-portal.file-picker", 1);',
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
