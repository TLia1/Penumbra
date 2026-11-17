.pragma library

var entries = [
        { page: "look", tab: "theme", glyph: "󰏘", title: "Look", words: "theme dark light auto colours colors accent hue vividness corners rounded sharp harmonize glass frost" },
        { page: "look", tab: "desktop", glyph: "󰍹", title: "Bar, dock & desktop", words: "bar compact monitor cpu ram memory island capsules framed workspaces dock depth clock audio aura wallpaper music player lyrics lrclib screen frame bezel signature layout osd" },
        { page: "wallpapers", glyph: "󰸉", title: "Wallpaper", words: "background picture image video gif" },
        { page: "displays", glyph: "󰍹", title: "Displays", words: "monitors screens resolution refresh rate scale rotation arrangement" },
        { page: "mixer", glyph: "󰕾", title: "Sound", words: "audio volume boost output input microphone speakers apps" },
        { page: "keyboard", glyph: "󰌌", title: "Keyboard", words: "layout variant options num lock xkb" },
        { page: "idle", glyph: "󰒲", title: "Idle and sleep", words: "dim lock screens off suspend timeout stay awake apps inhibit video calls" },
        { page: "notifications", glyph: "󰂚", title: "Notifications", words: "do not disturb dnd schedule fullscreen sharing sounds lock screen count mute quiet keep rules" },
        { page: "apps", glyph: "󰀻", title: "Default apps", words: "browser file manager terminal" },
        { page: "packages", glyph: "󰏗", title: "Installed packages", words: "software pacman aur foreign flatpak appimage uninstall update manage" },
        { page: "downloads", glyph: "󰇚", title: "Download video or audio", words: "yt-dlp youtube video audio music mp4 mp3 mkv webm opus flac" },
        { page: "weather", glyph: "󰖐", title: "Weather", words: "location city coordinates forecast temperature calendar clock bar" },
        { page: "notes", glyph: "󰎞", title: "Quick notes", words: "notes draft text writing local sidebar" },
        { page: "night", glyph: "󰖔", title: "Night light", words: "warmth temperature kelvin sunset sunrise schedule wlsunset" },
        { page: "wifi", glyph: "󰤨", title: "Wi-Fi", words: "wireless network internet" },
        { page: "bluetooth", glyph: "󰂯", title: "Bluetooth", words: "devices headphones mouse pair battery" },
        { page: "cast", glyph: "󰄘", title: "Cast screen", words: "tv chromecast dlna firewall port" },
        { page: "settings", glyph: "󰐊", title: "Animated wallpapers", words: "motion still battery power covered windows" },
        { page: "settings", glyph: "󰆾", title: "Hot corner", words: "corner control center" },
        { page: "wm", glyph: "󰖯", title: "Window manager", words: "wm compositor mangowm mango session tiling layout tags multi-tag toggleview toggletag windows dwindle master stack scroller monocle grid deck fair vertical jump labels scratchpad group tabs overlay" },
        { page: "settings", glyph: "󰘾", title: "Reduced motion", words: "animations accessibility" },
        { page: "settings", glyph: "󰛖", title: "Text size", words: "font larger bigger accessibility zoom" },
        { page: "settings", glyph: "󰂄", title: "Battery care", words: "charge limit threshold power" },
        { page: "settings", glyph: "󰅌", title: "Clipboard history", words: "copy paste keep days expire pins" },
        { page: "settings", glyph: "󰈝", title: "Export settings", words: "backup move another computer save file" },
        { page: "settings", glyph: "󰈞", title: "Import settings", words: "restore another computer load file" }
    ];

function matches(text, batteryAvailable) {
    const words = text.trim().toLowerCase().split(/\s+/);
    return entries.filter(entry => (batteryAvailable || entry.title !== "Battery care")
        && words.every(word => (entry.title + " " + entry.words).toLowerCase().includes(word)));
}
