import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Animated wallpapers. Each scene sits on the bottom layer over awww's still copy of the same
// image, so fading it in or out changes nothing at rest; night has no animated scene.
// nocturne-wallpaper says when the wallpaper changes.
Scope {
    id: root

    readonly property var scenes: ["wallpaper-dawn", "wallpaper-eclipse"]
    // The animated scene that should be up, and the one loaded now; they differ while one fades out.
    property string target: ""
    property string scene: ""
    // awww's transition is still running.
    property bool waiting: false
    readonly property bool shown: target !== "" && scene === target && !waiting

    property real fade: shown ? 1 : 0
    Behavior on fade { NumberAnimation { duration: root.shown ? 900 : 350; easing.type: Easing.InOutQuad } }
    onFadeChanged: if (fade === 0) scene = target
    onTargetChanged: if (fade === 0) scene = target

    // Wait out awww's transition before covering it.
    function show(name, delay) {
        target = scenes.includes(name) ? name : "";
        waiting = delay > 0;
        if (waiting) {
            reveal.interval = delay;
            reveal.restart();
        }
    }
    Timer {
        id: reveal
        onTriggered: root.waiting = false
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/nocturne/wallpaper"
        onLoaded: root.show(text().trim(), 0)
    }

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: output
            required property var modelData

            LazyLoader {
                active: root.fade > 0

                PanelWindow {
                    id: window
                    screen: output.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Bottom
                    // Not nocturne-*: the glass layer rule would blur it.
                    WlrLayershell.namespace: "animated-wallpaper"

                    // Nothing to see under a fullscreen window; stop drawing.
                    readonly property bool running: !(Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false)

                    // Cover the screen like `awww img --resize crop`.
                    Loader {
                        id: scene
                        anchors.centerIn: parent
                        scale: item ? Math.max(window.width / item.width, window.height / item.height) : 1
                        opacity: root.fade
                        sourceComponent: root.scene === "wallpaper-eclipse" ? eclipse : dawn

                        Component {
                            id: dawn
                            DawnScene {
                                running: window.running
                                pixelScale: Math.max(window.width / width, window.height / height) * window.devicePixelRatio
                            }
                        }
                        Component {
                            id: eclipse
                            EclipseScene {
                                running: window.running
                                pixelScale: Math.max(window.width / width, window.height / height) * window.devicePixelRatio
                            }
                        }
                    }
                }
            }
        }
    }
}
