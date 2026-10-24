//@ pragma UseQApplication
//@ pragma IconTheme Nocturne
// NOCTURNE shell: bar, control center, notifications, OSD, calendar and session overlay.
// Run with `quickshell -c nocturne`; scripts talk to it with `quickshell -c nocturne ipc call …`.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    ControlCenter {}
    CalendarPanel {}
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
        function session(): void { Ui.openSession(); }
        function close(): void { Ui.close(); Ui.sessionOpen = false; }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clear(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
    }

    IpcHandler {
        target: "updates"
        function refresh(): void { Sys.refreshUpdates(); }
    }
}
