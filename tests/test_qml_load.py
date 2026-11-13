"""Compile shell components offscreen without instantiating desktop services.

Only PanelWindow is substituted: Qt offscreen has no Wayland layer-shell backend.
This catches QML API/type errors, not compositor geometry or live input behaviour.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WINDOW = '''import QtQuick
import Quickshell
FloatingWindow {
    component EdgeFlags: QtObject {
        property bool top: false; property bool bottom: false
        property bool left: false; property bool right: false
    }
    property EdgeFlags anchors: EdgeFlags {}
    component Margins: QtObject {
        property real top: 0; property real bottom: 0
        property real left: 0; property real right: 0
    }
    property Margins margins: Margins {}
    property int exclusionMode: 0
    property int exclusiveZone: 0
}
'''
HARNESS = '''import QtQuick
import Quickshell
ShellRoot {
    Timer {
        interval: 100; running: true
        onTriggered: {
            let failed = false;
            for (const name of COMPONENTS) {
                const component = Qt.createComponent(name);
                if (component.status !== Component.Ready) {
                    console.error(name + ": " + component.errorString());
                    failed = true;
                }
            }
            Qt.exit(failed ? 1 : 0);
        }
    }
}
'''


@unittest.skipUnless(shutil.which('quickshell'), 'needs Quickshell')
class QmlLoad(unittest.TestCase):
    def test_shell_components_compile(self):
        with tempfile.TemporaryDirectory(prefix='penumbra-load-') as temp:
            stage = Path(temp)
            shutil.copytree(ROOT / 'config/quickshell/penumbra', stage, dirs_exist_ok=True)
            names = ['Bar', 'SettingsPage', 'LookPage', 'WeatherPage', 'PackagesPage', 'Osd', 'Overview', 'Wallpaper', 'ControlCenter',
                     'KeybindsPanel', 'MonitorPanel', 'WallpaperPicker', 'DownloadsPanel', 'ScreenFrame', 'SessionMenu', 'Launcher']
            for path in stage.glob('*.qml'):
                path.write_text(path.read_text().replace('PanelWindow {', 'TestPanelWindow {'))
            (stage / 'TestPanelWindow.qml').write_text(WINDOW)
            (stage / 'shell.qml').write_text(HARNESS.replace('COMPONENTS', json.dumps([n + '.qml' for n in names])))
            (stage / 'runtime').mkdir(mode=0o700)
            env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp, 'XDG_CACHE_HOME': temp,
                   'XDG_RUNTIME_DIR': str(stage / 'runtime'), 'QT_QPA_PLATFORM': 'offscreen',
                   'QT_QUICK_BACKEND': 'software'}
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
            env.pop('WAYLAND_DISPLAY', None)
            result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
