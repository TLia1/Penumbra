pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shell preferences from the settings page, kept in ~/.config/penumbra/shell.json. The corner
// style is penumbra-corners' instead (see Theme), since MangoWM and other apps follow it too.
Singleton {
    property alias animatedWallpapers: adapter.animatedWallpapers
    // Animated wallpapers hold still while tiled windows hide them, and on battery or in power saver.
    property alias stillWhenCovered: adapter.stillWhenCovered
    property alias stillOnBattery: adapter.stillOnBattery
    // Optional desktop depth and a frame joined to the bar.
    property alias desktopMusic: adapter.desktopMusic
    property alias desktopLyricsOnline: adapter.desktopLyricsOnline
    property alias desktopClock: adapter.desktopClock
    property alias desktopAura: adapter.desktopAura
    property alias compactMonitor: adapter.compactMonitor
    property alias barStyle: adapter.barStyle
    property alias workspaceStyle: adapter.workspaceStyle
    property alias osdPosition: adapter.osdPosition
    property alias volumeBoost: adapter.volumeBoost
    readonly property int maxOutputVolume: volumeBoost ? 150 : 100
    property alias glassFrost: adapter.glassFrost
    property alias weatherInBar: adapter.weatherInBar
    property alias screenFrame: adapter.screenFrame
    property alias weatherEnabled: adapter.weatherEnabled
    property alias weatherPlace: adapter.weatherPlace
    property alias dockMode: adapter.dockMode
    property alias dockPins: adapter.dockPins
    property alias hotCorner: adapter.hotCorner
    // Window tiling: layout, smart gaps, and MangoWM layout-specific tuning.
    property alias tilingLayout: adapter.tilingLayout
    property alias showAllTags: adapter.showAllTags
    property alias smartGaps: adapter.smartGaps
    property alias dwindleSmartSplit: adapter.dwindleSmartSplit
    property alias masterRatio: adapter.masterRatio
    property alias newWindowMaster: adapter.newWindowMaster
    property alias scrollerProportion: adapter.scrollerProportion
    property alias scrollerCenter: adapter.scrollerCenter
    property alias monocleTabBar: adapter.monocleTabBar
    property alias deckTabBar: adapter.deckTabBar
    property alias floatingSnap: adapter.floatingSnap
    property alias sloppyFocus: adapter.sloppyFocus
    property alias warpCursor: adapter.warpCursor
    property alias nativeHotarea: adapter.nativeHotarea
    // Night light: its warmth in kelvin, and when it comes on (see NightLight).
    property alias nightTemperature: adapter.nightTemperature
    property alias nightSchedule: adapter.nightSchedule // manual, times or sun
    readonly property var nightSchedules: [
        { value: "manual", title: "By hand" },
        { value: "times", title: "Set times" },
        { value: "sun", title: "Sunset to sunrise" }
    ]
    property alias nightFrom: adapter.nightFrom
    property alias nightTo: adapter.nightTo
    property alias nightPlace: adapter.nightPlace // a city or "latitude, longitude"; empty: the time zone's
    property alias nightOn: adapter.nightOn // the last toggle by hand, restored on start in manual mode
    // Casting: whether the TV also plays what the computer plays, and a fixed port for the stream
    // (0: any free one), so a firewall rule can let the TV in.
    property alias castSound: adapter.castSound
    property alias castPort: adapter.castPort
    // Accessibility: no animations anywhere (shell, wallpapers, MangoWM), and larger text.
    property alias reducedMotion: adapter.reducedMotion
    property alias textScale: adapter.textScale
    readonly property var textSizes: [1, 1.1, 1.25, 1.4]
    readonly property var textSizeLabels: ["Default", "Large", "Larger", "Largest"]
    readonly property int textSizeIndex: Math.max(0, textSizes.indexOf(textScale))
    // Do not disturb: on a schedule, while recording or casting, while a window is fullscreen.
    property alias dndSchedule: adapter.dndSchedule
    property alias dndFrom: adapter.dndFrom
    property alias dndTo: adapter.dndTo
    property alias dndWhileSharing: adapter.dndWhileSharing
    property alias dndFullscreen: adapter.dndFullscreen
    // A sound for new notifications (not for low urgency).
    property alias notificationSounds: adapter.notificationSounds
    // Per app: { "App name": "silent" (history only) | "mute" (dropped) | "keep" (never expires) }.
    property alias notificationRules: adapter.notificationRules
    // Clipboard: pinned texts, which "Clear history" keeps, and days the history keeps (0: always).
    property alias clipboardPins: adapter.clipboardPins
    property alias clipboardDays: adapter.clipboardDays
    // Recording: the microphone along with (or instead of) what the computer plays.
    property alias recordMicrophone: adapter.recordMicrophone
    // The lock screen shows how many notifications came in, never what they say.
    property alias lockNotificationCount: adapter.lockNotificationCount
    // Window classes (or app ids) that keep the screen awake while open, like a video call.
    property alias idleInhibitApps: adapter.idleInhibitApps
    property alias calendarWeekNumbers: adapter.calendarWeekNumbers
    // Stop charging at this percentage where the battery supports it (100: off).
    property alias batteryLimit: adapter.batteryLimit
    // The Downloads panel's last choices: kind (video or audio), videoFormat, videoQuality,
    // audioFormat, audioQuality, videoFolder, audioFolder.
    property alias downloads: adapter.downloads

    // mango/config.conf reads it at start; a change applies to the running compositor at once.
    onReducedMotionChanged: Wm.setReducedMotion(reducedMotion)
    onTilingLayoutChanged: Wm.syncTiling()
    onSmartGapsChanged: Wm.syncTiling()
    onDwindleSmartSplitChanged: Wm.syncTiling()
    onMasterRatioChanged: Wm.syncTiling()
    onNewWindowMasterChanged: Wm.syncTiling()
    onScrollerProportionChanged: Wm.syncTiling()
    onScrollerCenterChanged: Wm.syncTiling()
    onMonocleTabBarChanged: Wm.syncTiling()
    onDeckTabBarChanged: Wm.syncTiling()
    onFloatingSnapChanged: Wm.syncTiling()
    onSloppyFocusChanged: Wm.syncTiling()
    onWarpCursorChanged: Wm.syncTiling()
    onNativeHotareaChanged: Wm.syncTiling()

    function signatureComposition() {
        barStyle = "floating";
        workspaceStyle = "pills";
        osdPosition = "bottom";
        screenFrame = false;
        desktopMusic = true;
        desktopClock = false;
        desktopAura = false;
        weatherInBar = false;
        dockMode = "off";
        glassFrost = 0;
    }

    function setRule(app, rule) {
        const rules = Object.assign({}, notificationRules);
        if (rule === "" || rule === "normal")
            delete rules[app];
        else
            rules[app] = rule;
        notificationRules = rules;
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/penumbra/shell.json"
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
            property bool desktopMusic: true
            property bool desktopLyricsOnline: false
            property bool desktopClock: false
            property bool desktopAura: false
            property bool compactMonitor: false
            property string barStyle: "floating"
            property string workspaceStyle: "pills"
            property string osdPosition: "bottom"
            property bool volumeBoost: false
            property real glassFrost: 0
            property bool weatherInBar: false
            property bool screenFrame: false
            property bool weatherEnabled: false
            // null preserves the old shared location until a weather location is chosen;
            // an empty string explicitly uses the computer's time zone.
            property var weatherPlace: null
            property string dockMode: "off" // off, auto, empty
            property var dockPins: ["firefox", "kitty", "io.github.lia.Files"]
            property bool hotCorner: true
            property string tilingLayout: "dwindle"
            property bool showAllTags: false
            property bool smartGaps: false
            property bool dwindleSmartSplit: false
            property real masterRatio: 0.55
            property bool newWindowMaster: true
            property real scrollerProportion: 0.8
            property bool scrollerCenter: false
            property bool monocleTabBar: true
            property bool deckTabBar: true
            property bool floatingSnap: true
            property bool sloppyFocus: true
            property bool warpCursor: false
            property bool nativeHotarea: false
            property int nightTemperature: 4500
            property string nightSchedule: "manual"
            property string nightFrom: "21:00"
            property string nightTo: "07:00"
            property string nightPlace: ""
            property bool nightOn: false
            property bool castSound: true
            property int castPort: 0
            property bool reducedMotion: false
            property real textScale: 1
            property bool dndSchedule: false
            property string dndFrom: "22:00"
            property string dndTo: "07:00"
            property bool dndWhileSharing: true
            property bool dndFullscreen: false
            property bool notificationSounds: false
            property var notificationRules: ({})
            property var clipboardPins: []
            property int clipboardDays: 0
            property bool recordMicrophone: false
            property bool lockNotificationCount: true
            property var idleInhibitApps: []
            property bool calendarWeekNumbers: false
            property int batteryLimit: 100
            property var downloads: ({})
        }
    }
}
