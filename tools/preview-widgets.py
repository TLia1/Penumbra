#!/usr/bin/env python3
"""Render actual Phase 3 QML components with deterministic, offline sample data.

No running shell, media, location or user settings are read or changed. Requires Quickshell
and Qt's offscreen software renderer. Output defaults to previews/widgets.png.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parent.parent
SHELL = ROOT / 'config/quickshell/penumbra'

STUBS = {
    'Settings': 'property real textScale: 1; property bool reducedMotion: true; property bool weatherEnabled: true',
    'Ui': 'property string bin: "/nonexistent/"',
    'Media': 'function isLive(p) { return false; }',
    'Clock': 'property date date: new Date("2026-11-03T17:30:00Z")',
    'Weather': '''property var place: ({name: "Paris"})
        property var current: ({temperature_2m: 14, apparent_temperature: 12, wind_speed_10m: 9})
        property string description: "Cloudy"
        property var result: ({status: "ok", at: 1793727000})
        property bool stale: false
        property double lastAttempt: 0
        function refresh() {}''',
}

QML = '''import QtQuick
import QtQuick.Layouts
import Quickshell
ShellRoot {
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1040
        implicitHeight: 640
        color: "#0d0a12"
        Rectangle {
            id: scene
            anchors.fill: parent
            color: Theme.base
            Rectangle {
                x: 420; y: -300; width: 800; height: 800; radius: 400
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.alpha(Theme.accentDeep, 0.28) }
                    GradientStop { position: 1; color: Theme.base }
                }
                border.color: Theme.line
            }
            Column {
                x: 56; y: 42; spacing: 8
                Label { text: "P E N U M B R A"; color: Theme.accent; font.pixelSize: 13; font.letterSpacing: 2 }
                Label { text: "A little closer to your day."; font.family: Theme.display; font.pixelSize: 32; font.weight: Font.DemiBold }
                Label { text: "Lyrics, sky and a place for your favourite apps."; color: Theme.textSoft; font.pixelSize: 16 }
            }
            Rectangle {
                x: 56; y: 172; width: 568; height: 300; radius: Theme.radiusLarge
                color: Theme.glassStrong; border.color: Theme.line
                ColumnLayout {
                    anchors { fill: parent; margins: 22 }
                    spacing: 12
                    Label { text: "NOW PLAYING"; color: Theme.accent; font.pixelSize: 11; font.letterSpacing: 2 }
                    Label { text: "Between the stars"; font.pixelSize: 24; font.weight: Font.DemiBold }
                    Label { text: "Penumbra · Preview session"; color: Theme.textSoft }
                    LyricsView {
                        id: lyrics
                        Layout.fillWidth: true
                        player: QtObject {
                            property string trackTitle: "Between the stars"
                            property string trackArtist: "Penumbra"
                            property string trackAlbum: "Preview session"
                            property real length: 180
                            property real position: 12
                        }
                        Component.onCompleted: result = { status: "ok", synced: "[00:00]The evening folds around us\\n[00:10]We leave a little light between the stars\\n[00:20]And carry it into tomorrow" }
                    }
                    Item { Layout.fillHeight: true }
                    Row {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: 52
                            Rectangle {
                                required property int index
                                width: 6; height: 3 + 18 * Math.abs(Math.sin(index * 0.41)); y: (24-height)/2
                                radius: 3; color: Theme.alpha(Theme.accentBright, 0.65)
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                x: 650; y: 172; width: 334; spacing: 12
                Label { text: "TUESDAY · 3 NOVEMBER"; color: Theme.accent; font.pixelSize: 11; font.letterSpacing: 1.4 }
                WeatherCard { Layout.fillWidth: true }
                Label { Layout.fillWidth: true; text: "A local lunar phase. A glance at the weather."; wrapMode: Text.Wrap; color: Theme.textSoft; font.pixelSize: 13 }
            }
            DockSurface {
                id: dock
                x: 250; y: 310; width: 540; height: 246; shown: true
                apps: [
                    {key: "firefox", pin: "firefox", entry: {icon: "firefox"}, windows: [{activated: true}]},
                    {key: "kitty", pin: "kitty", entry: {icon: "kitty"}, windows: [{activated: false}, {activated: false}]},
                    {key: "files", pin: "files", entry: {icon: "system-file-manager"}, windows: []},
                    {key: "code", pin: "", entry: {icon: "text-editor"}, windows: [{activated: false}]},
                    {key: "music", pin: "", entry: {icon: "multimedia-player"}, windows: [{activated: false}]}
                ]
            }
            Label { x: 56; y: 594; text: "PHASE 03  /  OFFLINE COMPONENT PREVIEW · SAMPLE DATA"; color: Theme.dim; font.pixelSize: 10; font.letterSpacing: 1.4 }
        }
        Timer {
            interval: 900; running: true
            onTriggered: {
                if (lyrics.current !== 1 || lyrics.lines.length !== 3 || !dock.shown || dock.apps.length !== 5) {
                    console.error("Widget fixture assertion failed"); Qt.exit(1); return;
                }
                scene.grabToImage(result => {
                    if (!result.saveToFile(Quickshell.env("PENUMBRA_PREVIEW"))) Qt.exit(1);
                    else Qt.quit();
                });
            }
        }
    }
}
'''


def stage(folder):
    for name in ['Theme.qml', 'palette.js', 'Label.qml', 'Glyph.qml', 'GlassEdge.qml', 'PillButton.qml',
                 'LyricsView.qml', 'lyrics.js', 'WeatherCard.qml', 'sun.js', 'DockSurface.qml']:
        shutil.copy2(SHELL / name, folder / name)
    shutil.copytree(SHELL / 'shaders', folder / 'shaders')
    for name, body in STUBS.items():
        (folder / f'{name}.qml').write_text('pragma Singleton\nimport QtQuick\nimport Quickshell\nSingleton {\n' + body + '\n}\n')
    (folder / 'shell.qml').write_text(QML)


def main():
    args = [arg for arg in sys.argv[1:] if arg != '--light']
    output = Path(args[0] if args else ROOT / 'previews/widgets.png').resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='penumbra-preview-') as temp:
        folder = Path(temp)
        stage(folder)
        if '--light' in sys.argv:
            import json
            sys.path.insert(0, str(ROOT / 'share/penumbra'))
            import palette
            state = folder / '.local/state/penumbra'
            state.mkdir(parents=True)
            (state / 'palette.json').write_text(json.dumps({'mode': 'light', 'duration': 0,
                'colors': palette.load(ROOT / 'palette/palette.toml')['light']}))
        runtime = folder / 'runtime'
        runtime.mkdir(mode=0o700)
        env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': str(folder / 'config'),
               'XDG_CACHE_HOME': str(folder / 'cache'), 'XDG_RUNTIME_DIR': str(runtime),
               'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
               'PENUMBRA_PREVIEW': str(output), 'TZ': 'Europe/Paris'}
        env.pop('WAYLAND_DISPLAY', None)
        env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env, capture_output=True, text=True, timeout=20)
        log = result.stdout + result.stderr
        # Sandboxed runners can refuse local IPC sockets; rendering does not use them.
        errors = [line for line in log.splitlines() if 'ERROR' in line and 'quickshell.ipc:' not in line]
        if result.returncode or errors or 'ReferenceError' in log or 'TypeError' in log or not output.exists():
            print(log, file=sys.stderr)
            return 1
        print(output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
