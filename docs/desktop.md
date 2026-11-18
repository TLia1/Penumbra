# Using the Penumbra desktop

Use **Super+,** to open Settings and search by feature name.

## Keyboard and mouse shortcuts

Press **Super+F1** for a searchable list of active desktop keybinds (also in
Settings → Keyboard → Keyboard shortcuts). Search by key or action, scroll to
browse, and press Escape or Super+F1 to close. The list reads your MangoWM configuration each time it opens, including
`~/.config/mango/keybinds.conf` and your overrides in `~/.config/mango/user.conf`.
Add a trailing `# description` to a custom binding to label its action.

| Shortcut | Action |
|---|---|
| Super+F1 | Show or hide the searchable keyboard shortcuts panel |
| Super+Enter / Super+Q | Chosen terminal (Kitty by default) |
| Super+Space / Super+R | App launcher (`>` runs a command, `?` searches the web, `/` finds files; sums, units and currencies are worked out) |
| Alt+Tab | Jump to an open window (the launcher's Windows mode) |
| Super+E | Chosen file manager (Lia Files, or Dolphin if only that is installed) |
| Super+B | Your default web browser (`xdg-settings set default-web-browser NAME.desktop` changes it) |
| Super+C | Close focused window |
| Super+V | Toggle floating |
| Super+F | Fullscreen |
| Super+arrow | Focus adjacent window |
| Super+Shift+arrow | Move the window in that direction |
| Super+Ctrl+arrow | Resize the window (repeats while held) |
| Super+physical number-row key | Workspace 1–9, on any keyboard layout (AZERTY included) |
| Super+Shift+physical number-row key | Move window to workspace |
| Super+Alt+physical number-row key | Send window to workspace without following it |
| Super+S / Super+Shift+S | Show or hide the scratchpad / send the window there |
| Super+G | Group windows into tabs (Super+Tab and Super+Shift+Tab step through them) |
| Super+Tab / Super+Shift+Tab | Next / previous tab in a window group |
| Super+P | Pin a floating window to every workspace |
| Three-finger swipe | Previous / next workspace (touchpad) |
| Super+\` (the key left of 1) / four-finger swipe up | Overview of every workspace |
| Super+left/right mouse drag | Move / resize |
| Super+scroll down/up | Next / previous workspace |
| Super+J | Toggle split direction |
| Super+M | Session overlay |
| Super+A | Control center |
| Super+, | Settings (search, look, wallpaper, displays, keyboard, idle, notifications, default apps, accessibility…) |
| Super+L | Lock |
| Super+N | Clear notifications |
| Super+Shift+V | Clipboard history |
| Super+; | Emoji and symbols (Tab switches between them) |
| Super+Shift+C | Pick a color on screen; copies its hex value |
| Super+W | Next wallpaper (Penumbra's, then yours) |
| Super+Shift+W | Wallpaper picker |
| Super+D | Download video or audio with yt-dlp |
| Super+Shift+R | Restart the shell |
| Print | Screenshot a region, window or the whole screen; save to `~/Pictures/Screenshots` and copy it |
| Shift+Print | The same, then annotate it in Satty |
| Ctrl+Print | Record a region, window or the whole screen to `~/Videos/Screencasts`; press again to stop (right-click the bar's red capsule to pause) |
| Caps Lock | Show whether Caps Lock is on; the key still reaches the app |
| Volume up/down / brightness up/down | Adjust volume / brightness (repeat while held, also while locked) |
| Audio mute / microphone mute | Toggle output / microphone mute (also while locked) |
| Media play / pause / next / previous | Play or pause / pause / next track / previous track (also while locked) |

## Bar and workspaces

Click the Arch logo for the launcher or right-click it for clipboard history. Click the clock for the calendar. With several keyboard layouts, click the layout indicator to switch.

Click CPU or RAM for live graphs and the busiest apps, or right-click for btop. On a hybrid laptop the GPU card switches between GPUs and lets a sleeping discrete GPU stay asleep.

Click the status capsule or move the pointer to the top-right hot corner for the Control Center. Scroll the capsule to adjust volume or right-click it for pavucontrol. Right-click a tray icon for its menu.

**Bar** keeps the floating-capsule layout. Workspaces sit beside the clock in one glass capsule, with a travelling accent pill that stretches toward the selected workspace. Each shows its name, up to two app icons and an overflow count; narrower screens keep just the names. Playing media shows rounded cover art (a music glyph when missing), an elided track title and the Cava spectrum when available. Middle-click pauses and scrolling skips tracks. The focused window stays centred when there is room, with its app icon in place of the app name most titles end with. Capsules that come and go (media, recording, casting, updates, keyboard layout) fade and slide rather than jump. Scrolling a capsule steps once per wheel notch, touchpads included. Reduced motion and sharp corners apply to the new surfaces too.

**Overview** (Super+\`, the key left of 1, or four fingers up on a touchpad): every workspace at a glance with live previews of its windows. Click a workspace to go there or a window to focus it, drag a window onto another workspace to move it, or type to find a window by its title or app (Tab steps through the matches, Enter goes to one).

**Saved workspaces.** Arrange the apps for a task, open Overview, and select **Saved workspaces → New workspace**. You can also press **Ctrl+S** inside Overview. Give the task a name such as *Development*, choose the tags to include on each display, and select **Save workspace**. The visible tags are selected initially. You can include tags that are currently out of view.

Optionally enter a project folder such as `~/Projects/orbit` when saving or updating a workspace. Newly opened Kitty, foot, Alacritty, Konsole, and WezTerm windows start in that folder. Newly opened VS Code, Code OSS, VSCodium, Lia Files and Dolphin windows open the folder. Existing windows keep their current location. Clear the field on update to remove it.

Choose **Open** or enter the workspace name in **Super+Space** to return to a task. Penumbra reuses matching windows, launches missing apps through their desktop entries, restores the selected tags’ tiling layouts, and returns to their saved views. If a display is disconnected, its tags move to the built-in display or, on a desktop, the focused display. Penumbra shows any remapped tags and apps it could not reopen. **Update…** captures the current arrangement again. **Delete** removes the saved workspace and leaves its apps running.

Saved workspaces record each window’s position and size relative to its display. Penumbra restores floating windows to those bounds and puts tiled windows back in their saved slots. On a dedicated dwindle tag it can also rebuild the saved splits. If the current layout cannot reproduce a position, the result names the affected app. For a workspace saved before position capture, arrange the windows and choose **Update…** once. Reopened apps handle their own documents, browser tabs and terminal contents. Pinned, scratchpad, overlay and minimized windows are excluded from capture. Workspaces are stored locally in `$XDG_CONFIG_HOME/penumbra/workspaces.json` (normally `~/.config/penumbra/workspaces.json`).

**Tray**: nm-applet and Blueman keep running in the background for password and pairing prompts, but their tray icons are hidden since the control center covers them.

## Launcher and clipboard

Press **Super+Space** to search apps, their actions, settings and saved workspaces. Searching for *Text size* and pressing Enter takes you to the control. A saved workspace preview lists its apps by display and tag. On a wide screen, use the preview to adjust text size, choose a night light schedule or launch an app’s desktop actions. **F1** shows the command prefixes. For example, “private” finds Firefox’s New Private Window. Recent, frequent launches rank higher. The details pane appears on wider screens.

| Type in the launcher | Result |
|---|---|
| `>command` | Run a command. Shift+Enter runs it in your terminal. |
| `?query` | Search DuckDuckGo in your browser. |
| `/name` | Find a file or folder in your home directory. Enter opens it. Shift+Enter opens its folder. |
| `2*pi`, `10 km in mi`, or `100 usd in eur` | Calculate or convert. Enter copies the result. Currency conversions fetch ECB rates from frankfurter.dev and cache them for 12 hours. |

Press **Tab** to cycle through the launcher’s other modes.

- **Windows** (`Alt+Tab`) searches open windows by title or app. Enter focuses the match.
- **Clipboard** (`Super+Shift+V`) shows text, thumbnails, and colour swatches. Enter copies an entry, Shift+Delete removes it, and Alt+P pins text across history clears. Passwords marked as sensitive are excluded. Settings lets you expire entries after 1, 7, or 30 days.
- **Emoji and symbols** (`Super+;`) lets you search by name. Enter types the character into the focused window. Shift+Enter copies it.

## Control Center

**Control center** (Super+A, or click the status capsule): Tab and Shift+Tab move between controls. Enter or Space activates a focused button. A tile and its details chevron are separate stops. The panel includes Wi-Fi and Bluetooth toggles, Do not disturb (its chevron opens the Notifications page), Stay awake (pauses idle locking), Night light (wlsunset; its chevron opens a page for the warmth and a schedule, by fixed times or from sunset to sunrise where you are), Screenshot and Cast screen, volume, microphone and brightness sliders, and notification history grouped by app with Clear all. Shortcuts for settings, the wallpaper picker, lock and the session overlay sit in its header. Escape or a click outside closes it.

**Sound page** opens from the chevron beside the volume slider (or `ipc call panel mixer`): pick the output and input device, and set each app's own volume and mute. Turn on **Volume boost** to raise the output limit from 100% to 150% for the slider, volume keys and bar scrolling. Turning it off brings boosted output back to 100%. A laptop's HDMI and DisplayPort outputs are listed only while an external screen is connected.

**Wi-Fi and Bluetooth pages** open from the chevron on each tile (or `ipc call panel wifi|bluetooth`). Wi-Fi lists nearby networks while the page is open: click a saved or open network to connect, type the password inline for a new secured one, and expand the connected or saved network to Disconnect or Forget it. Bluetooth lists your devices (one click connects; expand to Disconnect or Forget) and discovers new ones while open; click one to pair, trust and connect it. "Advanced settings" links still reach nm-connection-editor and Blueman for anything else (static IPs, enterprise Wi-Fi).

**Volume and brightness**: the hardware keys (including Fn+F2/F3/F6/F7 when those keys emit the corresponding media events) show a popup at the bottom center with the current percentage and a progress bar; it disappears after 1.5 seconds, and holding a key updates the same popup. The shell changes the value itself (`ipc call osd adjust volume up`), so held keys respond at once; `penumbra-osd` does it with wpctl and brightnessctl, and a plain notification, when the shell is not running. Mute and microphone mute show their status too. Brightness stays above zero. The bar shows an automatically detected battery immediately before the power button, with its percentage, charging state, and low-battery colors; machines without a battery omit it. On battery, a notification warns at 10%, and a critical one that stays until dismissed at 5%.

## Calendar and weather

Click a day to see its events or click **Wk** to toggle week numbers. Import exported `.ics` files into `~/.local/share/penumbra/calendars`. The calendar also reads `~/.calendars` and `~/.local/share/vdirsyncer` for synced CalDAV calendars.

**Settings → Look → Show weather** enables [Open-Meteo](https://open-meteo.com/en/docs) in the calendar. **Choose location** opens the Weather menu: choose a city from the
local time-zone database or explicit `latitude, longitude`, and toggle weather beside the clock.
The previous Night Light location is kept until you choose a weather location; choosing one
does not change Night Light. An empty location uses the
time zone's representative city, which can be far from your actual location. Coordinates
are sent to Open-Meteo every 30 minutes while enabled. Temperatures use Celsius and wind
uses km/h. Cached readings are labeled when stale and discarded after 24 hours. The lunar
phase is calculated locally with a low-order astronomical model and is approximate.

## Media and lyrics

The **Wallpaper music player** shows the track, artist and album cover. On Night and
Eclipse it sits to the left of the planet. Dawn mirrors the layout. Click the progress
bar to seek when the player supports it. [Preview all four wallpapers](../previews/wallpaper-music.webp)

On Moonwake, the cover and track title sit together on the near shore. A small diamond
marks the elapsed time on a moonlit seek line. Click anywhere along the line to seek.
Lyrics appear in the middle of the lake in italic serif type, with a rippled reflection beneath them.
[See the Moonwake player](../previews/moonwake-music.webp)

Each monitor keeps its bar capsule while a media player is available, including when playback
is paused. The wallpaper player stays on the desktop behind menus and floating windows. It hides
when a window is maximized, fullscreen, or covers that entire monitor.
**Settings → Look → Bar, dock & desktop** lets you turn off the
wallpaper player or enable **Look up missing lyrics**. Lyrics provided by the player appear
automatically. The optional LRCLIB lookup runs while the widget is visible. Timed lyrics
follow playback and seeking. Plain lyrics show their opening lines.

Click the bar capsule to open the mini-player. Click again or use × to dismiss it.
Middle-click the capsule to toggle playback, or scroll to skip. Its spectrum takes
an accent from the cover artwork. Mini-player lyrics remain opt-in through the **Lyrics**
button and use the same cached LRCLIB lookup.

Online lookups send the title, artist, album and duration to [LRCLIB](https://lrclib.net/docs). The mini-player shows three lines of timed lyrics, follows seeks, and offers scrolling for
plain lyrics. Instrumental tracks are labeled. Results are cached for 30 days, missing tracks
for one day, under `$XDG_CACHE_HOME/penumbra/lyrics` (normally `~/.cache/penumbra/lyrics`).
Offline and rate-limited requests offer a retry; service cooldowns are respected.

## Floating dock

**Settings → Look → Floating dock** offers Off (default), Auto-hide, and Empty workspace
(stays visible on empty workspaces and reveals at the bottom edge elsewhere). Each monitor
shows pinned apps and its running apps. Click to launch or cycle windows, middle-click to
launch another instance, and right-click to pin/unpin. Hover a running app for clickable live
window previews; horizontally scroll when there are more apps or previews than fit. The dock
hides for fullscreen windows, locking, and shell overlays. Pins are desktop entry IDs in
`dockPins` in `~/.config/penumbra/shell.json`.

## Settings and displays

Open **Settings** with **Super+,** or the gear in the Control Center. Search for a setting by name, or open its page.

- **Look** controls dark, light, or automatic mode, accent colours, corners, wallpaper motion, and the top-right hot corner. Automatic mode uses sunrise and sunset at your Night Light location. See [Appearance and app themes](appearance.md).
- **Displays** lets you drag monitors into place and change resolution, refresh rate, scale, and rotation. To try a custom resolution, choose **Custom mode**, enter a value such as `1280x720@60`, then choose **Set → Apply**. Choose **Keep** within 15 seconds to save the layout to `~/.config/mango/monitors.conf`.
- **Keyboard**, **Idle and sleep**, and **Default apps** control input layouts, idle timers and exceptions, and your browser, file manager, and terminal. These choices use the [installer settings file](installation.md#installer-settings).
- **Reduced motion** disables shell and window animations and keeps wallpapers still. **Text size** offers four sizes. **Battery care** sets a 60%, 80%, or 90% charging limit on supported laptops.

**Export settings** saves portable preferences to `~/penumbra-settings-DATE.json`. Clipboard pins, weather and Night Light locations, and monitor layouts each require a separate opt-in. **Import settings** previews the changes. Choose **Apply import** to save them. Replaced files get a `.bak` backup.

From the terminal, use `penumbra-settings export [FILE]` or `penumbra-settings import FILE`. Add `--clipboard-pins`, `--location`, or `--monitors` as needed. Repeat the import with `--apply` after reviewing the preview.

**Settings → Quick notes** opens a local scratchpad. Drafts save after a short typing pause to `~/.local/state/penumbra/notes.txt`, even if the page
closes. A failed save keeps the draft in memory and shows a retry action; no AI or cloud service
is involved.

## Notifications, locking and logout

**Notifications** pop in at the top right and move to the history when they time out (hovering pauses that). Each shows how long ago it arrived. Critical notifications stay until dismissed and still show during Do not disturb. **Do not disturb** comes on by hand, on a schedule, and by itself while you record or cast the screen (so nothing private shows) and, if you choose, while a window is fullscreen; turning it off by hand holds until the next change. The bell beside each app in the history sets its rule, one click at a time: **Quiet** (history only, no popups), **Mute** (dropped), **Keep** (never expires), or normal; the Notifications page lists every rule. Sounds are optional (the freedesktop sound theme, a different one for critical notifications, never for low urgency), and the lock screen can show how many came in while locked, never what they say. Notifications an app marks as transient (volume changes, "copied" toasts) disappear when their popup does instead of filling the history, which keeps the newest 50. Clicking a notification runs its default action. Screenshots and photos show as a preview; chat apps that support it get a reply field.

**Lock screen** (Super+L, after ten idle minutes and before suspend; the backlight dims half a minute before, the screens turn off a minute after, and on battery the machine suspends after half an hour, all handled by swayidle and `bin/penumbra-idle`; fullscreen windows and Stay awake hold all of it off): the clock over the current wallpaper without its wordmark, still animating, your `~/.face` (or initial), and the password field; it warns about Caps Lock, shows the keyboard layout when you have several (click to switch), and shows what's playing. The shell authenticates through the PAM `login` stack. If the shell repeatedly crashes while locked, systemd starts swaylock as a fallback (`penumbra-lock-fallback.service`); unlock there, then Super+Shift+R starts the shell again. swayidle, the wallpaper daemon and the clipboard watchers are user services as well (`penumbra-idle`, `penumbra-awww`, `penumbra-cliphist@text`/`@image`), restarted if they die.

**Polkit**: when an app asks for administrator rights, a password card appears over the dimmed screen in place of the KDE dialog.

**Session overlay** (Super+M): arrow keys and Enter, or the mouse. Log out, Restart and Shut down ask for a second press, then ask every window to close first, so apps can save or ask about unsaved work; if some are still open after ten seconds, a notification names them and offers to go ahead anyway (`penumbra-exit`).

## Screenshots and recordings

**Screenshots and recordings** (Print, or Ctrl+Print to start in Video): the screen freezes; drag a region, click a window, or click for the whole screen (R, W and S switch, E toggles annotating in Satty, Escape cancels). With several screens, **All screens** (D) takes every screen in one picture, and Tab moves the overlay to the next screen. **Video** (V) records the area instead, **Sound** (A) adds what the computer plays, **Microphone** (M) your voice (both mix into one track), and **Timer** (T) waits 3, 5 or 10 seconds first, counting down in the bar (click the countdown to cancel). While recording, a red capsule in the bar shows the time; click it or press Ctrl+Print to stop, right-click it to pause and go on (each stretch is joined into one file at the end). Recordings are H.264 MP4 files in `~/Videos/Screencasts`, copied to the clipboard as a file when they finish (paste into a chat or a file manager), with a notification that plays it and, for a clip of a minute or less, makes a GIF of it (`penumbra-record gif FILE`). `bin/penumbra-record` does the recording, so it carries on if the shell restarts; without the shell, Ctrl+Print asks for a region with slurp.

## Cast to a TV

**Cast screen** (the Cast screen tile in the control center, or `ipc call panel cast`): shows this screen on a TV on the same network. The page lists the Chromecasts, Google TVs and DLNA TVs (most Samsung, LG, Sony and Philips sets) it finds, looking again every 20 seconds while it is open; click one and it shows the screen in a few seconds. **Sound on the TV** sends what the computer plays along with it, with several screens you pick which one to show, and **Port** fixes the port the TV connects to (any free one by default), so a firewall rule can allow it. While casting, a capsule in the bar names the TV (click it for the page), and the tile or **Stop casting** ends it; it also ends when the TV stops playing. `bin/penumbra-cast` does it: wf-recorder records the screen in H.264 at 30 frames a second (no wider than 1920 pixels), this computer serves it over HTTP, and the TV is told to play it, through Cast (`python-pychromecast`) or UPnP. The cast carries on if the shell restarts. The TV buffers a few seconds, so it suits films, videos and slides, not games. Both need to be on the same network, and a firewall on this computer must let the TV connect to it. The stream is plain HTTP on every network interface, hidden only behind a random address, which suits a home network but not a shared one. Miracast-only TVs and sticks (some Fire TV and Roku models) are not supported.

## Download video or audio

**Downloads** (Super+D, the Download button in the control center, **Settings → Download video or audio**, or paste an address in the launcher): download a video or only its sound with yt-dlp. If an address is on the clipboard when the panel opens, it is filled in and looked up (title, channel, duration, thumbnail and available resolutions); for a video inside a playlist, **Whole playlist** downloads all of it into a subfolder. Pick **Video** (`mp4`, `mkv`, `webm`, at **Best**, **4K**, **1440p**, **1080p**, **720p** or **480p**) or **Audio only** (`mp3`, `m4a`, `opus`, `flac`, `wav`, at **Best**, **320k**, **192k** or **128k**), and where to save it (by default `~/Videos` for video and `~/Music` for audio, or **Browse…** for the portal's folder chooser); your choices are remembered for next time. Closed, the panel is not loaded (`LazyLoader`), so it uses no memory or CPU when unused; `bin/penumbra-download` runs only while a download is in progress, keeping progress in `$XDG_RUNTIME_DIR/penumbra/downloads` and sending a notification when it finishes.

## Updates and installed packages

**Updates**: the update capsule appears when updates are available, a check fails, or a restart is due. It checks the distribution's packages (on Arch: official packages, and AUR packages through Paru or Yay, whichever is installed; see `distro/arch/share/penumbra/updates.py`) and user/system Flatpak apps and runtimes every 15 minutes. The panel also shows the latest Arch news, lit when it came out after your last upgrade (some upgrades need a step by hand, so read those first), and says when a restart is due: a new kernel, or glibc, systemd, Mesa, NVIDIA's driver, MangoWM and other core packages upgraded since the computer started; the capsule then shows a restart glyph even with nothing to update. Click it for the list of pending packages by source, with Check again and Update now, which opens your terminal: password, package review and confirmation prompts stay interactive, the terminal closes on success or waits for Enter after a failure, and repeated clicks do not start parallel updates. Repository checks use `checkupdates` and a separate database, so they never refresh the live pacman database; the panel names unavailable sources and shows the last successful check for each source. The helper is `bin/penumbra-updates`.

Open **Settings → Installed packages** (or `penumbra-ipc panel page packages`) to
search installed software and filter by pacman, AUR / foreign, Flatpak or AppImage.
Expand a package for its **Dependencies** (what it needs), **Required by** (what
needs it), details and management actions. Pacman and AUR/foreign packages also show
optional dependencies and the packages that optionally use them. Version constraints
are preserved. Flatpak shows primary runtime relationships, matched by branch,
architecture and installation; runtime extensions and bundled libraries are not included.
AppImages explicitly show dependency information as unavailable because it is not tracked.
These are direct relationships, not a recursive dependency tree or a safe-to-remove check. Lists include dependencies
and Flatpak runtimes, with each Flatpak installation and branch kept separate.

Uninstall and update actions open your configured terminal, where the package manager
shows the transaction, asks for confirmation and handles authentication. Pacman removal
uses `-R`, retaining dependency checks and configuration backups. Arch updates are full
system upgrades, using paru or yay when available. The AUR filter includes **all foreign
packages**; locally built packages may need their original build source. **Update all**
opens the existing system/AUR and user/system Flatpak update flow. Refresh the list after
finishing; named Flatpak installations can be updated from their individual rows.

AppImages are discovered recursively by `.AppImage` filename (case-insensitive) in
`~/Applications`, `~/AppImages`, `~/Downloads`, `~/Desktop`, `~/.local/bin`,
`~/.local/share/AppImage`, `/opt` and `/usr/local/bin`. The AppImage filter offers an
additional folder for the current visit; press Refresh after entering it. Hidden
subdirectories and symlinked directories are skipped. Files elsewhere or without the
extension require moving them into a scanned folder or renaming them appropriately.
AppImage actions open the containing folder or move the selected file to the trash;
app data and desktop launchers stay in place. Download replacement versions from the
publisher. Scanning never executes AppImages.

The read-only inventory is also available as JSON with `penumbra-packages list`.
Command behavior follows the [pacman manual](https://man.archlinux.org/man/pacman.8.en)
and [Flatpak command reference](https://docs.flatpak.org/en/latest/flatpak-command-reference.html).
