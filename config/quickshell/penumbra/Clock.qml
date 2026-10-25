pragma Singleton
import QtQuick
import Quickshell

// Wall-clock time to the minute. Stands in for Quickshell's SystemClock, which during the hour
// repeated when DST ends schedules its next tick in the past and spins a 1ms timer, flooding the
// log. Checking every second also catches up straight away after suspend or a clock change.
Singleton {
    id: root

    property date date: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            if (Math.floor(now.getTime() / 60000) !== Math.floor(root.date.getTime() / 60000))
                root.date = now;
        }
    }
}
