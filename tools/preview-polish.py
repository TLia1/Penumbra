#!/usr/bin/env python3
"""Render the remaining aesthetics with actual components and offline sample data."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'share/penumbra'))
import palette
spec = importlib.util.spec_from_file_location('widgets', ROOT / 'tools/preview-widgets.py')
widgets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(widgets)

QML = '''import QtQuick
import QtQuick.Layouts
import Quickshell
ShellRoot {
    FloatingWindow {
        visible: true
        implicitWidth: 1440; implicitHeight: 1000
        Rectangle {
            id: scene
            anchors.fill: parent
            color: Theme.base
            Label { x: 48; y: 30; text: "P E N U M B R A"; font.pixelSize: 28; font.weight: Font.Bold }
            Label { x: 48; y: 78; text: "Six atmospheres. One desktop."; color: Theme.muted; font.pixelSize: 18 }
            Rectangle {
                x: 48; y: 124; width: 1344; height: 400
                radius: Theme.radiusLarge
                color: Theme.surface
                clip: true
                Image { anchors.fill: parent; source: "WALLPAPER"; fillMode: Image.PreserveAspectCrop }
                IslandSurface { x: 110; y: 0; width: 780; height: 62 }
                RowLayout {
                    x: 144; y: 10; spacing: 10
                    Capsule { Glyph { text: "󰣇"; color: Theme.accentBright } }
                    Capsule { Label { text: "18:30"; font.weight: Font.Bold } }
                    WorkspaceStrip {
                        workspaces: [
                            {name: "1", active: true, toplevels: {values: []}},
                            {name: "2", active: false, toplevels: {values: []}},
                            {name: "3", active: false, toplevels: {values: []}}]
                    }
                    MediaCapsule { id: previewMedia }
                }
                Label { x: 64; y: 225; text: "LIGHT AT THE EDGE"; font.pixelSize: 15; font.letterSpacing: 6; color: Theme.accentBright }
                Label { x: 60; y: 248; text: "of shadow"; font.pixelSize: 64; color: Theme.white; font.weight: Font.Light }
                Rectangle {
                    x: 940; y: 24; width: 380; height: 350
                    radius: Theme.radiusLarge; color: Theme.glassStrong; border.color: Theme.line
                    GlassEdge { radius: parent.radius }
                    ColumnLayout {
                        anchors { fill: parent; margins: 20 }
                        spacing: 12
                        Label { text: "Small details, in motion"; font.pixelSize: 18; font.weight: Font.Bold }
                        Tile { Layout.fillWidth: true; glyph: "󰖩"; title: "Connected"; subtitle: "Sample network"; on: true }
                        Tile { Layout.fillWidth: true; glyph: "󰂓"; title: "Glass frost"; subtitle: "Light, layered surfaces" }
                        SliderRow { Layout.fillWidth: true; glyph: "󰕾"; value: 68 }
                        RowLayout { PillButton { text: "Moonlight"; primary: true } PillButton { text: "Stillness" } }
                    }
                }
            }
            LauncherPreview {
                visible: false
                width: 304; height: 370
                result: ({kind: "app", entry: {name: "Sample app", comment: "An offline preview", icon: ""}})
            }
            Grid {
                x: 48; y: 552; columns: 3; spacing: 18
                Repeater {
                    model: PRESETS
                    delegate: Rectangle {
                        required property var modelData
                        width: 436; height: 174; radius: 16
                        color: modelData.base; border.color: modelData.accent
                        Rectangle { x: 18; y: 18; width: 400; height: 78; radius: 12; color: modelData.surface
                            Image { anchors.fill: parent; source: modelData.artwork; fillMode: Image.PreserveAspectCrop }
                            Row { x: 18; y: 22; spacing: 12
                                Rectangle { width: 34; height: 34; radius: 17; color: modelData.accent }
                                Label { text: "Aa  012345"; color: modelData.accent; font.pixelSize: 26 }
                            }
                        }
                        Label { x: 20; y: 112; text: modelData.title; color: modelData.text; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Label { x: 20; y: 140; text: modelData.wallpaper.replace("wallpaper-", "").replace("wallpaper", "night").toUpperCase() + "  /  " + modelData.mode.toUpperCase(); color: modelData.muted; font.pixelSize: 11; font.letterSpacing: 2 }
                    }
                }
            }
            Label { x: 48; y: 948; text: "OFFLINE COMPONENT STUDY / SAMPLE DATA · SOFTWARE RENDER · SHADER LIGHTING REQUIRES THE LIVE GPU SHELL"; color: Theme.dim; font.pixelSize: 10; font.letterSpacing: 1.1 }
        }
        Timer { interval: 1200; running: true; onTriggered: {
            if (Math.abs(previewMedia.artTint.g - 187/255) > 0.05) {
                console.error("Album palette was not sampled: " + previewMedia.artTint); Qt.exit(1); return;
            }
            scene.grabToImage(result => {
            if (!result.saveToFile(Quickshell.env("PENUMBRA_PREVIEW"))) Qt.exit(1); else Qt.quit();
        }); } }
    }
}
'''


def stage(folder):
    widgets.stage(folder)
    for name in ['Capsule', 'Tile', 'SliderRow', 'CardLight', 'IslandSurface', 'WorkspaceStrip', 'MediaCapsule', 'MediaPopover', 'LauncherPreview']:
        shutil.copy2(widgets.SHELL / (name + '.qml'), folder)
    (folder / 'Settings.qml').write_text('''pragma Singleton
import Quickshell
Singleton { property real glassFrost: 0; property real textScale: 1; property bool reducedMotion: true; property string workspaceStyle: "icons"; property string barStyle: "island" }
''')
    (folder / 'Media.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell
Singleton {
    property QtObject player: QtObject {
        property string trackTitle: "Orbit / Sample track"
        property string trackArtist: "Penumbra"
        property string trackArtUrl: "COVER_URL"
        property bool isPlaying: true
        property bool canTogglePlaying: true
        property bool canGoPrevious: false
        property bool canGoNext: false
        property bool canSeek: false
        property real length: 240
        property real position: 60
        function togglePlaying() { isPlaying = !isPlaying; }
        function positionChanged() {}
    }
    property var playing: player
    property int count: 8
    property var bars: [.2, .5, .8, .4, .9, .6, .3, .5]
    function isLive(p) { return false; }
    function hasLength(p) { return true; }
    function time(v) { return "1:00"; }
    function appName(p) { return "Sample player"; }
}
'''.replace('        function positionChanged() {}\n', '').replace('COVER_URL', (folder / 'cover.svg').as_uri()))
    (folder / 'cover.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#33bbaa"/></svg>')
    (folder / 'Ui.qml').write_text('''pragma Singleton
import Quickshell
Singleton { property bool hasVisualizer: true; property string bin: "/nonexistent/" }
''')
    palettes = palette.load(ROOT / 'palette/palette.toml')
    presets = [{**preset, 'artwork': (ROOT / 'assets' / (preset['wallpaper'] + '-clean.png')).as_uri(), **palette.preset_palette(palettes, preset['mode'], key)} for key, preset in palette.PRESETS.items()]
    (folder / 'shell.qml').write_text(QML.replace('PRESETS', json.dumps(presets)).replace('WALLPAPER', (ROOT / 'assets/wallpaper-eclipse-clean.png').as_uri()))


def main():
    output = Path(sys.argv[1] if len(sys.argv) > 1 else ROOT / 'previews/aesthetics.png').resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='penumbra-polish-') as temp:
        folder = Path(temp)
        stage(folder)
        runtime = folder / 'runtime'; runtime.mkdir(mode=0o700)
        env = {**os.environ, 'HOME': temp, 'XDG_CONFIG_HOME': temp, 'XDG_CACHE_HOME': temp,
               'XDG_RUNTIME_DIR': str(runtime), 'QT_QPA_PLATFORM': 'offscreen', 'QT_QUICK_BACKEND': 'software',
               'PENUMBRA_PREVIEW': str(output)}
        env.pop('WAYLAND_DISPLAY', None); env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
        result = subprocess.run(['quickshell', '-p', temp, '--no-color'], env=env, capture_output=True, text=True, timeout=20)
        log = result.stdout + result.stderr
        errors = [line for line in log.splitlines() if 'ERROR' in line and 'quickshell.ipc:' not in line]
        if result.returncode or errors or any(s in log for s in ['ReferenceError', 'TypeError', 'Unable to assign', 'Binding loop']) or not output.exists():
            print(log, file=sys.stderr); return 1
        print(output)
    return 0


if __name__ == '__main__':
    sys.exit(main())
