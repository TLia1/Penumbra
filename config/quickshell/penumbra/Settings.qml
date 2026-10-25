pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shell preferences from the settings page, kept in ~/.config/penumbra/shell.json. The corner
// style is penumbra-corners' instead (see Theme), since Hyprland and other apps follow it too.
Singleton {
    property alias animatedWallpapers: adapter.animatedWallpapers
    property alias hotCorner: adapter.hotCorner

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
            property bool hotCorner: true
        }
    }
}
