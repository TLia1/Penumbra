//@ pragma UseQApplication
//@ pragma IconTheme Nocturne
// NOCTURNE shell: animated wallpapers, bar, control center, notifications, OSD, calendar and session overlay.
// Run with `quickshell -c nocturne`; scripts talk to it with `quickshell -c nocturne ipc call …`.
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
    NotificationPopups {}
    Osd {}
    SessionMenu {}

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
        function calendar(): void { Ui.toggleCalendar(); }
        function monitor(): void { Ui.toggleMonitor(); }
        function session(): void { Ui.openSession(); }
        function close(): void { Ui.close(); Ui.sessionOpen = false; }
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
