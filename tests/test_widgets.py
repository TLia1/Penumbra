"""Quickshell runtime checks with fake services and a temporary HOME, never the live desktop."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('preview', ROOT / 'tools/preview-widgets.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


@unittest.skipUnless(shutil.which('quickshell'), 'needs Quickshell')
class Widgets(unittest.TestCase):
    def test_component_render(self):
        with tempfile.TemporaryDirectory() as temp:
            result = subprocess.run(['python', str(ROOT / 'tools/preview-widgets.py'), temp + '/widgets.png'],
                                    capture_output=True, text=True, timeout=25)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertGreater(Path(temp + '/widgets.png').stat().st_size, 10000)

    def test_aesthetics_component_render(self):
        with tempfile.TemporaryDirectory() as temp:
            result = subprocess.run(['python', str(ROOT / 'tools/preview-polish.py'), temp + '/aesthetics.png'],
                                    capture_output=True, text=True, timeout=25)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertGreater(Path(temp + '/aesthetics.png').stat().st_size, 10000)

    def test_notes_save_survives_sidebar_lifetime(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            (folder / '.local/state/penumbra').mkdir(parents=True)
            (folder / 'runtime').mkdir(mode=0o700)
            shutil.copy2(preview.SHELL / 'Notes.qml', folder)
            (folder / 'shell.qml').write_text('import QtQuick\nimport Quickshell\nShellRoot {\n    property bool notesReady: Notes.ready\n    Timer { interval: 100; running: true; onTriggered: { if (!Notes.ready) { Qt.exit(1); return; } Notes.edit("first draft"); } }\n    Timer { interval: 200; running: true; onTriggered: Notes.edit("kept after closing the sidebar") }\n    Timer { interval: 1200; running: true; onTriggered: Qt.exit(Notes.dirty || Notes.error ? 1 : 0) }\n}\n')
            env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp, 'XDG_CACHE_HOME': temp,
                   'XDG_RUNTIME_DIR': str(folder / 'runtime'), 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software'}
            env.pop('WAYLAND_DISPLAY', None)
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
            result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((folder / '.local/state/penumbra/notes.txt').read_text(), 'kept after closing the sidebar')

    def test_track_and_location_races(self):
        with tempfile.TemporaryDirectory() as temp:
            folder = Path(temp)
            preview.stage(folder)
            shutil.copy2(preview.SHELL / 'Weather.qml', folder / 'Weather.qml')
            (folder / 'NightLight.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property bool citiesWanted: false
    property var place: ({name: "First", latitude: 1, longitude: 0})
    function locate(text) { return {name: text, latitude: Number(text), longitude: 0}; }
}
''')
            (folder / 'Ui.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton { property bool calendarOpen: false; property string bin: Quickshell.env("HOME") + "/" }
''')
            script = folder / 'penumbra-online'
            script.write_text('''#!/usr/bin/env python3
import json, sys, time
from pathlib import Path
time.sleep(0.4)
with (Path(__file__).parent / 'calls').open('a') as out: out.write(sys.argv[1] + '\\n')
print(json.dumps({'status': 'ok', 'synced': '[00:00]intro\\n[00:10]' + sys.argv[2]} if sys.argv[1] == 'lyrics' else {'status': 'ok', 'current': {'temperature_2m': float(sys.argv[2])}}))
''')
            script.chmod(0o755)
            (folder / 'shell.qml').write_text('''import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        visible: true
        QtObject {
            id: testPlayer
            property string trackTitle: "first"
            property string trackArtist: "artist"
            property string trackAlbum: "album"
            property real length: 120
            property real position: 12
        }
        LyricsView { id: lyrics; width: 400; active: true; player: testPlayer }
        Component.onCompleted: console.log("weather enabled", Weather.place.name)
        Timer {
            interval: 600; running: true
            onTriggered: {
                testPlayer.trackTitle = "second";
                Settings.weatherPlace = "2";
                NightLight.place = {name: "Night light only", latitude: 9, longitude: 0};
            }
        }
        Timer {
            interval: 2200; running: true
            onTriggered: {
                if (Weather.current?.temperature_2m !== 2 || lyrics.result.synced !== "[00:00]intro\\n[00:10]second" || lyrics.current !== 1) {
                    console.error("stale response or synchronization failure", JSON.stringify(Weather.result), JSON.stringify(lyrics.result)); Qt.exit(1); return;
                }
                testPlayer.position = 2;
                if (lyrics.current !== 0) { console.error("seek failure"); Qt.exit(1); return; }
                Settings.weatherEnabled = false;
                Settings.weatherPlace = "3";
                lyrics.active = false;
                testPlayer.trackTitle = "third";
            }
        }
        Timer {
            interval: 3200; running: true
            onTriggered: {
                if (Weather.current !== null || lyrics.result.status) { console.error("disabled services retained data"); Qt.exit(1); return; }
                console.log("race checks passed"); Qt.quit();
            }
        }
    }
}
''')
            runtime = folder / 'runtime'
            runtime.mkdir(mode=0o700)
            env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp + '/config',
                   'XDG_RUNTIME_DIR': str(runtime), 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software'}
            env.pop('WAYLAND_DISPLAY', None)
            env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
            result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env,
                                    capture_output=True, text=True, timeout=12)
            log = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, log)
            self.assertIn('race checks passed', log)
            self.assertNotIn('ReferenceError', log)
            self.assertNotIn('TypeError', log)
            self.assertEqual((folder / 'calls').read_text().splitlines().count('weather'), 2)
            self.assertEqual((folder / 'calls').read_text().splitlines().count('lyrics'), 2)


if __name__ == '__main__':
    unittest.main()
