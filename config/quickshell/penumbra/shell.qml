//@ pragma UseQApplication
//@ pragma IconTheme Penumbra
// PENUMBRA shell: animated wallpapers, bar, control center, notifications, OSD, calendar, session
// overlay, launcher, workspace overview, lock screen, polkit agent and screenshot/recording overlay.
// Run with `quickshell -c penumbra`; scripts talk to it with `quickshell -c penumbra ipc call …`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    Wallpaper {
        id: wallpaper
        paused: lockScreen.locked
    }

    Variants {
        model: Quickshell.screens
        delegate: Scope {
            id: output
            required property var modelData
            // Keep the original stacking position under the bar, dock and sheets. An idle
            // backdrop needs only one transparent pixel and an empty input region.
            PanelWindow {
                id: backdropWindow
                readonly property bool catching: Ui.openPanel !== "" && Ui.panelGrabFocus
                screen: output.modelData
                visible: Wm.isMango
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                anchors { top: true; left: true; bottom: catching; right: catching }
                implicitWidth: 1
                implicitHeight: 1
                margins.top: Theme.barHeight + 10
                mask: Region { item: panelBackdrop }
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "penumbra-backdrop"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                MouseArea {
                    id: panelBackdrop
                    width: backdropWindow.catching ? parent.width : 0
                    height: backdropWindow.catching ? parent.height : 0
                    acceptedButtons: Qt.AllButtons
                    onPressed: Ui.dismiss()
                }
            }
            ScreenFrame { modelData: output.modelData }
            Bar { modelData: output.modelData }
            Dock { modelData: output.modelData; locked: lockScreen.locked }
        }
    }

    component PanelLoader: LazyLoader {
        id: loader
        required property bool requested
        property bool showing: false
        active: requested || showing
        // Keep the loader active through the sheet's exit animation.
        property Connections visibility: Connections {
            target: loader.item
            function onVisibleChanged() { loader.showing = target.visible; }
        }
    }

    PanelLoader {
        requested: Ui.controlOpen
        ControlCenter {}
    }
    CalendarPanel {}
    MonitorPanel {}
    UpdatesPanel {}
    PanelLoader {
        requested: Ui.wallpapersOpen
        WallpaperPicker {}
    }
    PanelLoader {
        requested: Ui.downloadsOpen
        DownloadsPanel {}
    }
    KeybindsPanel {}
    NotificationPopups {}
    Osd {}
    SessionMenu {}
    Launcher {}
    HotCorners {}
    PolkitDialog {}
    ScreenshotOverlay {
        id: shot
    }
    Overview {}
    LockScreen {
        id: lockScreen
    }

    IpcHandler {
        target: "osd"
        function flash(kind: string, value: int, muted: bool): void {
            Ui.showOsd(kind, value, muted);
        }
        // What the volume, microphone and brightness keys do: penumbra-osd calls this first.
        // `action` is up, down, mute or current (just show the popup).
        function adjust(control: string, action: string): bool {
            return control === "brightness" ? Sys.stepBrightness(action) : Devices.adjust(control, action);
        }
        // MangoWM calls this when Caps Lock is released; the popup says whether it is on.
        function capsLock(): void {
            Devices.showCapsLock();
        }
    }

    IpcHandler {
        target: "panel"
        function control(): void { Ui.toggle("control"); }
        function wifi(): void { Ui.openControl("wifi"); }
        function bluetooth(): void { Ui.openControl("bluetooth"); }
        function mixer(): void { Ui.openControl("mixer"); }
        function cast(): void { Ui.openControl("cast"); }
        function settings(): void { Ui.openControl("settings"); }
        // A page of Settings: look, displays, keyboard, idle or apps; or night (night light).
        function page(name: string): void { Ui.openControl(name); }
        function keybinds(): void {
            const reopen = !Ui.keybindsOpen;
            Ui.closeOverlays();
            if (reopen) Ui.openPanel = "keybinds";
        }
        function overview(): void { Ui.toggleOverview(); }
        function calendar(): void { Ui.toggle("calendar"); }
        function monitor(): void { Ui.toggle("monitor"); }
        function session(): void { Ui.openSession(); }
        function updates(): void { Ui.toggle("updates"); }
        function wallpapers(): void { Ui.toggle("wallpapers"); }
        // Download a video or its sound with yt-dlp; `download URL` opens with the address filled in.
        function downloads(): void { Ui.toggle("downloads"); }
        function download(url: string): void { Ui.openDownloads(url); }
        function close(): void { Ui.closeOverlays(); }
    }

    IpcHandler {
        target: "launcher"
        function apps(): void { Ui.toggleLauncher("apps"); }
        function clipboard(): void { Ui.toggleLauncher("clipboard"); }
        function emoji(): void { Ui.toggleLauncher("emoji"); }
        function symbols(): void { Ui.toggleLauncher("symbols"); }
        function windows(): void { Ui.toggleLauncher("windows"); }
    }

    IpcHandler {
        target: "shot"
        function open(annotate: bool): void { shot.open(annotate, false); }
        // The same overlay, set to record a video.
        function record(): void { shot.open(false, true); }
    }

    IpcHandler {
        target: "recorder"
        // penumbra-record calls this when a recording starts or ends.
        function refresh(): void { Recorder.refresh(); }
        function stop(): void { Recorder.stop(); }
        function pause(): void { Recorder.togglePause(); }
    }

    IpcHandler {
        target: "cast"
        // penumbra-cast calls this when a cast starts, connects or ends.
        function refresh(): void { Cast.refresh(); }
        function stop(): void { Cast.stop(); }
    }

    IpcHandler {
        target: "lock"
        // False if the compositor refused; swayidle then falls back to swaylock.
        function lock(): bool { return lockScreen.lock(); }
        function isLocked(): bool { return lockScreen.locked; }
        function isSecure(): bool { return lockScreen.secure; }
    }

    IpcHandler {
        target: "nightlight"
        // Start the scheduler at login even if the control center is never opened.
        readonly property var service: NightLight
        function toggle(): void { service.toggle(); }
        function isOn(): bool { return service.on; }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clear(); }
        function dnd(): void { Notifs.toggleDnd(); }
    }

    IpcHandler {
        target: "wallpaper"
        // `delay` is how long awww's transition takes, in milliseconds.
        function set(name: string, delay: int): void { wallpaper.show(name, delay); }
    }

    IpcHandler {
        target: "updates"
        function refresh(): void { Sys.refreshUpdates(); }
    }
}
