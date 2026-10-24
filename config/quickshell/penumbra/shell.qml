//@ pragma UseQApplication
//@ pragma IconTheme Penumbra
// PENUMBRA shell: animated wallpapers, bar, control center, notifications, OSD, calendar, session
// overlay, launcher, lock screen, polkit agent and screenshot overlay.
// Run with `quickshell -c penumbra`; scripts talk to it with `quickshell -c penumbra ipc call …`.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Wallpaper {
        id: wallpaper
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    ControlCenter {}
    CalendarPanel {}
    ProcessPanel {}
    UpdatesPanel {}
    WallpaperPicker {}
    NotificationPopups {}
    Osd {}
    SessionMenu {}
    Launcher {}
    HotCorners {}
    PolkitDialog {}
    ScreenshotOverlay {
        id: shot
    }
    LockScreen {
        id: lockScreen
    }

    IpcHandler {
        target: "osd"
        function flash(kind: string, value: int, muted: bool): void {
            Ui.showOsd(kind, value, muted);
        }
    }

    IpcHandler {
        target: "panel"
        function control(): void { Ui.toggleControl(); }
        function wifi(): void { Ui.openControl("wifi"); }
        function bluetooth(): void { Ui.openControl("bluetooth"); }
        function mixer(): void { Ui.openControl("mixer"); }
        function calendar(): void { Ui.toggleCalendar(); }
        function monitor(): void { Ui.toggleMonitor(); }
        function session(): void { Ui.openSession(); }
        function updates(): void { Ui.toggleUpdates(); }
        function wallpapers(): void { Ui.toggleWallpapers(); }
        function close(): void { Ui.closeOverlays(); }
    }

    IpcHandler {
        target: "launcher"
        function apps(): void { Ui.toggleLauncher("apps"); }
        function clipboard(): void { Ui.toggleLauncher("clipboard"); }
        function emoji(): void { Ui.toggleLauncher("emoji"); }
        function symbols(): void { Ui.toggleLauncher("symbols"); }
    }

    IpcHandler {
        target: "shot"
        function open(annotate: bool): void { shot.open(annotate); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen.lock(); }
        function isLocked(): bool { return lockScreen.locked; }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clear(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
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
