pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shell preferences from the settings page, kept in ~/.config/penumbra/shell.json. The corner
// style is penumbra-corners' instead (see Theme), since Hyprland and other apps follow it too.
Singleton {
    property alias animatedWallpapers: adapter.animatedWallpapers
    // Animated wallpapers hold still while tiled windows hide them, and on battery or in power saver.
    property alias stillWhenCovered: adapter.stillWhenCovered
    property alias stillOnBattery: adapter.stillOnBattery
    property alias hotCorner: adapter.hotCorner
    // Night light: its warmth in kelvin, and when it comes on (see NightLight).
    property alias nightTemperature: adapter.nightTemperature
    property alias nightSchedule: adapter.nightSchedule // manual, times or sun
    property alias nightFrom: adapter.nightFrom
    property alias nightTo: adapter.nightTo
    property alias nightPlace: adapter.nightPlace // a city or "latitude, longitude"; empty: the time zone's
    property alias nightOn: adapter.nightOn // the last toggle by hand, restored on start in manual mode
    // Casting: whether the TV also plays what the computer plays.
    property alias castSound: adapter.castSound

    FileView {
        path: Quickshell.env("HOME") + "/.config/penumbra/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // The first run has no file yet: write the defaults.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool animatedWallpapers: true
            property bool stillWhenCovered: true
            property bool stillOnBattery: true
            property bool hotCorner: true
            property int nightTemperature: 4500
            property string nightSchedule: "manual"
            property string nightFrom: "21:00"
            property string nightTo: "07:00"
            property string nightPlace: ""
            property bool nightOn: false
            property bool castSound: true
        }
    }
}
