"""Exercise visual component lifecycles offscreen, without shell services or user settings."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
RUNNER = next((str(p) for p in [Path('/usr/lib/qt6/bin/qmltestrunner'),
                              Path('/usr/lib64/qt6/bin/qmltestrunner')]
               if p.is_file()), shutil.which('qmltestrunner6'))

STUBS = {
    'Theme': '''property bool reducedMotion: false
        property bool sharp: false
        property int motion: reducedMotion ? 0 : 1
        property int normal: 260 * motion
        property int barHeight: 40
        property string sans: "sans-serif"
        property string display: "sans-serif"
        property color accentBright: "#d4bfff"
        property color white: "#eee8f6"
        property color base: "#0d0a12"
        property color surface: "#100d18"
        property color pink: "#f3b4d6"
        function corner(n) { return sharp ? 0 : n; }
        function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }''',
    'Settings': 'property bool desktopClock: true; property bool desktopAura: true',
    'Ui': 'property bool hasVisualizer: true',
    'Media': 'property bool playing: true; property var bars: [0.2, 0.4, 0.8, 1, 0.7, 0.5, 0.3, 0.15]',
    'Clock': 'property date date: new Date(2026, 10, 3, 10, 24)',
}


@unittest.skipUnless(RUNNER, 'needs Qt 6 qmltestrunner (qt6-declarative)')
class Motion(unittest.TestCase):
    def test_visual_lifecycles(self):
        with tempfile.TemporaryDirectory(prefix='penumbra-motion-') as folder:
            stage = Path(folder)
            for name in ['DesktopDepth', 'StaggerReveal', 'FrameSurface']:
                shutil.copy2(ROOT / 'config/quickshell/penumbra' / f'{name}.qml', stage)
            shutil.copy2(ROOT / 'tests/qml/tst_motion.qml', stage)
            (stage / 'qmldir').write_text(''.join(f'singleton {name} 1.0 {name}.qml\n' for name in STUBS))
            for name, body in STUBS.items():
                (stage / f'{name}.qml').write_text(f'pragma Singleton\nimport QtQuick\nQtObject {{ {body} }}\n')
            result = subprocess.run([RUNNER, '-input', folder, '-o', '-,txt'],
                                    env={**os.environ, 'QT_QPA_PLATFORM': 'offscreen',
                                         'QT_QUICK_BACKEND': 'software', 'QML_DISABLE_DISK_CACHE': '1'},
                                    capture_output=True, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertNotIn('QWARN', result.stdout + result.stderr)


if __name__ == '__main__':
    unittest.main()
