"""Exercise actual QML color bindings and interruption, not just palette generation."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('preview', ROOT / 'tools/preview-widgets.py')
preview = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preview)


@unittest.skipUnless(shutil.which('quickshell'), 'needs Quickshell')
class ThemeRender(unittest.TestCase):
    def test_accent_ink_and_interrupted_fades(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            preview.stage(folder)
            (folder / 'runtime').mkdir(mode=0o700)
            (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    function check(ok, message) {
        if (!ok) { console.error(message); Qt.exit(1); }
    }
    Timer { interval: 40; running: true; onTriggered: {
        Settings.reducedMotion = false;
        Theme.show(Theme.makePalette("light", {onAccent: "#ffffff"}), 120);
    } }
    Timer { interval: 250; running: true; onTriggered: {
        check(Qt.colorEqual(Theme.accentInk, "#ffffff"), "Light selection ink is not white");
        Theme.show(Theme.makePalette("dark", {onAccent: "#100d18"}), 400);
    } }
    Timer { interval: 350; running: true; onTriggered: {
        const visibleInk = Theme.accentInk;
        Theme.show(Theme.makePalette("light", {onAccent: "#ffffff"}), 400);
        check(Qt.colorEqual(Theme.accentInk, visibleInk), "Interrupted fade jumped");
        Settings.reducedMotion = true;
        check(Theme.t === 1, "Reduced motion did not settle active fade");
        check(Qt.colorEqual(Theme.accentInk, "#ffffff"), "Reduced motion lost target ink");
        Theme.show(Theme.makePalette("dark", {onAccent: "#100d18"}), 0);
        check(Qt.colorEqual(Theme.accentInk, "#100d18"), "Dark selection ink is incorrect");
        Qt.quit();
    } }
}
''')
            env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp, 'XDG_CACHE_HOME': temp,
                   'XDG_RUNTIME_DIR': str(folder / 'runtime'), 'QT_QPA_PLATFORM': 'offscreen',
                   'QT_QUICK_BACKEND': 'software'}
            env.pop('WAYLAND_DISPLAY', None)
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
            result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
