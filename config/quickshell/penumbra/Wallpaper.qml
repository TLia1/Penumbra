import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Animated wallpapers: the dawn and eclipse scenes, and your GIFs and videos. Each sits on the
// bottom layer over awww's still copy of the same image (a GIF's or video's first frame), so
// fading it in or out changes nothing at rest; night and plain images have nothing to animate.
// penumbra-wallpaper says when the wallpaper changes; the settings page can keep them still.
Scope {
    id: root

    // The chosen wallpaper; the animated one that should be up, and the one loaded now (they
    // differ while one fades out).
    property string chosen: ""
    readonly property string target: Settings.animatedWallpapers && Ui.wallpaperKind(chosen) !== "still" ? chosen : ""
    property string scene: ""
    // awww's transition is still running.
    property bool waiting: false
    readonly property bool shown: target !== "" && scene === target && !waiting
    // Nothing to see behind the lock screen; stop drawing.
    property bool paused: false

    property real fade: shown ? 1 : 0
    Behavior on fade { NumberAnimation { duration: root.shown ? 900 : 350; easing.type: Easing.InOutQuad } }
    onFadeChanged: if (fade === 0) scene = target
    onTargetChanged: if (fade === 0) scene = target

    // Wait out awww's transition before covering it.
    function show(name, delay) {
        chosen = name;
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
        path: Quickshell.env("HOME") + "/.local/state/penumbra/wallpaper"
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
                    // Not penumbra-*: the glass layer rule would blur it.
                    WlrLayershell.namespace: "animated-wallpaper"

                    // Nothing to see under a fullscreen window; stop drawing.
                    readonly property bool running: !root.paused && !(Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false)

                    // Cover the screen like `awww img --resize crop`.
                    Loader {
                        id: scene
                        anchors.centerIn: parent
                        scale: item && item.width > 0 && item.height > 0 ? Math.max(window.width / item.width, window.height / item.height) : 1
                        opacity: root.fade
                        sourceComponent: ({ "wallpaper-dawn": dawn, "wallpaper-eclipse": eclipse })[root.scene]
                            ?? (Ui.wallpaperKind(root.scene) === "gif" ? gif : video)

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
                        Component {
                            id: gif
                            AnimatedImage {
                                width: window.width
                                height: window.height
                                source: Ui.fileUrl(root.scene)
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                playing: window.running
                            }
                        }
                        // Silent, looping, and with no audio output, so it never shows in the mixer.
                        Component {
                            id: video
                            VideoOutput {
                                id: clip
                                width: window.width
                                height: window.height
                                fillMode: VideoOutput.PreserveAspectCrop
                                readonly property bool running: window.running
                                onRunningChanged: running ? player.play() : player.pause()
                                MediaPlayer {
                                    id: player
                                    source: Ui.fileUrl(root.scene)
                                    videoOutput: clip
                                    loops: MediaPlayer.Infinite
                                    Component.onCompleted: if (clip.running) play()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
