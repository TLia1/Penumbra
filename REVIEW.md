# Penumbra — code review and analysis

*Reviewed on 2026-11-01, at commit `50aede7` ("added screen cast to tv in the control center").*

This document is a detailed review of the whole theme: the Quickshell shell, the helper scripts, the installer, the theme engine, the Hyprland configuration and the tooling. It covers what works well, bugs, performance problems, security and robustness, code quality, documentation drift, and features worth adding. Every finding points to a file and line so it can be acted on directly.

---

## Contents

1. [Overview](#1-overview)
2. [How it fits together](#2-how-it-fits-together)
3. [Strengths](#3-strengths)
4. [Bugs](#4-bugs)
5. [Performance](#5-performance)
6. [Security and robustness](#6-security-and-robustness)
7. [Code quality and maintainability](#7-code-quality-and-maintainability)
8. [Documentation drift](#8-documentation-drift)
9. [Features worth adding](#9-features-worth-adding)
10. [Suggested order of work](#10-suggested-order-of-work)
11. [How this review was done](#11-how-this-review-was-done)

---

## 1. Overview

Penumbra is a complete desktop for Arch Linux: Hyprland 0.56 with its Lua configuration, a Quickshell 0.3 shell that replaces Waybar, Mako, Rofi, Hyprlock and the KDE polkit agent, an SDDM greeter, boot themes (GRUB, Limine, Plymouth), original cursors and wallpapers, and a palette that is rendered into about 40 apps.

| Part | Size | Notes |
|---|---|---|
| Shell (`config/quickshell/penumbra/`) | 78 QML/JS files, ~11,300 lines | bar, control center with 11 pages, launcher, lock screen, polkit, notifications, OSD, overview, screenshots, animated wallpapers |
| Helper scripts (`bin/`) | 16 scripts (bash and Python) | theme engine, wallpaper, casting, recording, updates, settings |
| Installer (`install.sh`) | 1,095 lines of bash | backups, uninstall, per-distro layer, app colours |
| Boot installer (`tools/install-boot.py`) | 747 lines | transactional, with rollback |
| Tests (`tests/`) | 62 tests | **all pass** (run during this review, 8.5 s) |

**Overall verdict:** this is a well-engineered project, far above the usual dotfiles repository. It has a single source of truth for colours, real backups and an uninstaller, careful boot handling, consistent comments that explain *why*, and tests. The problems found are mostly of three kinds:

- a recurring QML pattern (Repeaters fed with freshly built JavaScript arrays) that causes both visible bugs and wasted work;
- a few features that drifted apart from each other or from the README as the project grew quickly (htop and btop, kitty hard-coded next to a terminal setting, the README describing removed or missing things);
- background helpers that are not supervised the way the shell is.

---

## 2. How it fits together

```
Hyprland (hyprland.lua) ──on start──▶ penumbra-session
                                         ├─ systemctl --user restart penumbra-shell.service ─▶ quickshell -c penumbra
                                         ├─ awww-daemon, hypridle, wl-paste|cliphist   (nohup, unsupervised)
                                         └─ penumbra-wallpaper restore

Quickshell shell
  singletons: Theme (palette.json, corners) · Ui (open surfaces, spawn) · Settings (shell.json)
              Config (settings.conf via penumbra-settings) · Look (theme.json via penumbra-theme)
              Devices · Sys · Usage · Media · Notifs · NightLight · Displays · Cast · Recorder · Clock
  surfaces:   Bar ×screens · Panels (control center, calendar, monitor, updates, wallpapers)
              Overlays (launcher, session, overview, screenshot, polkit) · LockScreen · Wallpaper ×screens

State on disk
  ~/.config/penumbra/settings.conf   installer settings (keyboard, scale, apps, idle)
  ~/.config/penumbra/shell.json      shell preferences
  ~/.config/penumbra/monitors.lua    Settings → Displays
  ~/.local/state/penumbra/           theme.json, palette.json, corners, wallpaper, launcher.json…
  $XDG_RUNTIME_DIR/penumbra*         lock marker, recording and cast state

Scripts ⇄ shell: `quickshell -c penumbra ipc call TARGET FUNCTION`, with rofi/slurp/hyprlock fallbacks.
```

The design choice of keeping long-running work (recording, casting, updates) in scripts that write state to `$XDG_RUNTIME_DIR` and having the shell only *display* it is a good one: those features survive a shell restart.

---

## 3. Strengths

Worth keeping in mind before changing anything, because these are the things that make the project solid:

- **One palette, many apps.** `palette/palette.toml` → `share/penumbra/palette.py` → templates. The same renderer is used at build time and at run time, with OKLCH hue rotation, gamut clamping and WCAG contrast guards (`palette.py:214`). `tests/test_generated.py` keeps generated files honest.
- **Backups and a real uninstaller.** Every run records new files and copies replaced ones (`install.sh:297`), and `--uninstall` replays them newest first.
- **Boot theming done carefully.** Opt-in, detection before action, staged builds, verification of UKI command lines, transactional restore, and isolated tests.
- **Shell resilience.** The shell is a systemd service with restart limits; the lock state is kept outside the process (`LockScreen.qml:149`) so a crash while locked relocks immediately; `allow_session_lock_restore` lets the new instance take over.
- **Apps outlive the shell.** `Ui.spawn` runs everything in its own systemd scope (`Ui.qml:178`).
- **Thoughtful details.** Physical keycodes for workspace keys (AZERTY works), the DST-proof `Clock.qml`, GPU sampling that never wakes a sleeping dGPU (`penumbra-gpus`), jemalloc tuning for the shell, the calculator that refuses to run anything that is not arithmetic, `>` required to run commands so a typo cannot reboot.
- **Comments explain intent.** Almost every non-obvious line says why it exists.

---

## 4. Bugs

Ranked by how much a user would notice. "Verified" means reproduced or certain from the code; "likely" means strongly suggested by the code but not reproduced.

### 4.1 High

#### B1. Notification popups restart their timers and animations whenever another one arrives or leaves — verified (code)

[`NotificationPopups.qml:33`](config/quickshell/penumbra/NotificationPopups.qml#L33) feeds the Repeater with `Notifs.popups`, a plain JavaScript array that [`Notifs.qml:87`](config/quickshell/penumbra/Notifs.qml#L87) and `hidePopup` replace with a new array each time. A Repeater cannot tell that the new array contains the same objects, so it **destroys and recreates every card**. Consequences:

- every visible popup's timeout `Timer` restarts, so during a burst of notifications the older ones never time out;
- every card replays its slide-in animation;
- hover state is lost (a hovered card can suddenly start timing out);
- text typed into an **inline reply field is lost** when another notification arrives.

**Fix:** use Quickshell's `ScriptModel` (`model: ScriptModel { values: Notifs.popups }`), which diffs arrays and keeps existing delegates, or a `ListModel` updated with `insert`/`remove`. The same pattern causes P1 and P2 below.

#### B2. On the lock screen, pausing music makes the media controls disappear — verified (code)

[`LockContent.qml:16`](config/quickshell/penumbra/LockContent.qml#L16) picks the player with `find(p => p.isPlaying) ?? null`, and the card is `visible: !!surface.player` ([line 276](config/quickshell/penumbra/LockContent.qml#L276)). Pressing pause sets `isPlaying` to false, the player becomes `null`, and the card vanishes, so the user cannot resume without unlocking.

**Fix:** use `Media.player`, which already keeps the last player that played ([`Media.qml:12-15`](config/quickshell/penumbra/Media.qml#L12)).

#### B3. Right-clicking the CPU/RAM capsule opens `htop`, which Penumbra does not install — verified

[`Bar.qml:233`](config/quickshell/penumbra/Bar.qml#L233) runs `kitty --class penumbra-monitor htop`. The package list installs `btop` ([`distro/arch/distro.sh:15`](distro/arch/distro.sh#L15)), and the "Advanced view" button of the monitor panel already uses btop ([`MonitorPanel.qml:743`](config/quickshell/penumbra/MonitorPanel.qml#L743)). The commit "using btop instead of htop" missed the bar. Without htop, kitty opens and closes immediately.

**Fix:** use btop here too, ideally through the terminal setting (see Q1), and update the README ([line 145](README.md#L145)).

### 4.2 Medium

#### B4. Uninstall leaves the Lia Files Flatpak theme files behind — verified (code)

`install_app_colors` writes into `~/.var/app/io.github.lia.Files/…` through `install_tree` ([`install.sh:642-645`](install.sh#L642)), which records those paths in the backup. But `uninstall_user` only replays paths under `.config .local .gitconfig .mozilla` ([`install.sh:943`](install.sh#L943)); `undo_runs` skips everything else ([line 908](install.sh#L908)). The Flatpak copies of `penumbra.css`, the GtkSourceView schemes and the actions folder stay. `penumbra-corners` also writes `corners.css` there without any backup.

**Fix:** add `.var` to the list of top-level folders in `uninstall_user`, and have `penumbra-corners` files tracked (or removed explicitly on uninstall).

#### B5. Transient notifications pushed out of the popup stack stay in the history forever — verified (code)

Popups are capped at four with `.slice(0, 4)` ([`Notifs.qml:87`](config/quickshell/penumbra/Notifs.qml#L87)). The ones dropped from the stack are never passed to `retire()`, so a transient notification (volume toasts, "copied" messages) that gets pushed out is not expired and ends up in the history, which is exactly what `retire()` exists to prevent.

**Fix:** compute the dropped popups and call `retire()` on them.

#### B6. "End" in the system monitor kills every process with the same executable name — verified (code)

Processes are grouped by the basename of their command ([`MonitorPanel.qml:78`](config/quickshell/penumbra/MonitorPanel.qml#L78)) and "End" / "Force quit" send the signal to all PIDs in the group ([line 155](config/quickshell/penumbra/MonitorPanel.qml#L155)). Ending a `python3` row also kills `penumbra-cast`, `penumbra-updates` and any script you are running; ending `bash` kills `penumbra-record` mid-recording and every interactive shell; ending `quickshell` kills the shell itself. There is no confirmation for "End".

**Fix:** group by systemd scope/cgroup instead (apps started by the shell already each have their own scope under `app.slice`, so `/proc/PID/cgroup` gives a precise "app" identity), refuse or confirm for generic interpreters, and exclude the shell's own PID.

#### B7. `ipc call osd adjust brightness <anything>` lowers the brightness — verified (reproduced)

[`Sys.qml:51`](config/quickshell/penumbra/Sys.qml#L51) treats any action that is not `"up"` as `"down"`. During this review, `quickshell -c penumbra ipc call osd adjust brightness nonsense` returned `true` and lowered the backlight by 5% (it was put back immediately). Volume handles unknown actions correctly.

**Fix:** return `false` for anything other than `up`, `down` and `current`.

#### B8. Night light switched on by hand turns off whenever the shell restarts — verified (code)

`NightLight.on` starts as `false` ([`NightLight.qml:15`](config/quickshell/penumbra/NightLight.qml#L15)) and hyprsunset is a child of the shell, so Super+Shift+R, a crash, an install or a new login turns a manual night light off. Scheduled modes recover; manual mode does not.

**Fix:** persist `on` in `shell.json` (it already has the other night light settings) for the manual schedule.

### 4.3 Low

#### B9. The colour picker's notification shows no colour — likely

`penumbra-picker` sends Pango markup `<span foreground='#hex'>██████</span>` ([`bin/penumbra-picker:6`](bin/penumbra-picker#L6)). The shell is the only notification daemon (Dunst is masked) and renders bodies as Qt `StyledText` ([`NotificationCard.qml:143`](config/quickshell/penumbra/NotificationCard.qml#L143)), which supports `<font color>` but not `<span>`, so the swatch shows in the normal text colour. **Fix:** `<font color='$color'>██████</font>`, or pass a generated swatch image as the notification icon.

#### B10. The control center may show a different player than the bar

[`ControlCenter.qml:20`](config/quickshell/penumbra/ControlCenter.qml#L20) uses `find(isPlaying) ?? players[0]`, while the bar uses `Media.player` (playing, else the last one that played). With two players open and nothing playing, the control center shows the first one rather than the one just paused. **Fix:** use `Media.player` everywhere (see Q2).

#### B11. Display changes become permanent if the shell restarts during the 15-second "Keep?" window

[`Displays.qml:152-162`](config/quickshell/penumbra/Displays.qml#L152) writes `monitors.lua` *before* the user confirms, then relies on the shell's timer to revert. If the shell crashes (a monitor change is exactly when that is most likely), the untested layout stays for good, including after reboot. **Fix:** apply the trial with `hyprctl eval` only, and write the file only in `keep()`.

#### B12. Smaller robustness issues

- [`ScreenshotOverlay.qml:35`](config/quickshell/penumbra/ScreenshotOverlay.qml#L35): `t.lastIpcObject.size` throws if a new window has no IPC object yet, which breaks the whole `windows` binding (window mode). Use `t.lastIpcObject?.size`.
- [`Bar.qml:96-97`](config/quickshell/penumbra/Bar.qml#L96): the media capsule stays clickable while it fades out, when `Media.player` can already be `null`.
- [`Notifs.qml:15`](config/quickshell/penumbra/Notifs.qml#L15): `received` (arrival times by id) is never pruned and is copied in full on every notification; it grows for the whole session. Delete the entry when a notification closes.
- `penumbra-shot` and `penumbra-record` name files to the second, so two captures in the same second overwrite each other.
- `penumbra-session` only starts the image clipboard watcher if the text watcher is not running ([`bin/penumbra-session:37`](bin/penumbra-session#L37)); if only the image watcher died, it is never restarted.

---

## 5. Performance

The shell is generally careful (polling only while panels are open, `asynchronous` images with `sourceSize`, pausing wallpapers under fullscreen). The items below are where real CPU/GPU time goes.

#### P1. The audio spectrum rebuilds the bar 30 times a second — verified (code)

cava prints 30 frames a second; each one creates a new array ([`Media.qml:52`](config/quickshell/penumbra/Media.qml#L52)), and the bar's Repeater uses that array as its model ([`Bar.qml:104`](config/quickshell/penumbra/Bar.qml#L104)). So, on every bar (one per screen), 8 rectangles are destroyed and recreated 30 times a second while music plays. It also means the `Behavior on height` never animates, because each rectangle is brand new.

**Fix:** `model: Media.count` and `height: 5 + (Media.bars[index] ?? 0) * 13`. The delegates then stay alive and the height Behavior actually smooths the motion.

Because the bar window repaints at 30 fps during playback, its other costs (P3) are paid 30 times a second as well.

#### P2. The same JS-array-as-model pattern elsewhere

Each of these rebuilds all of its delegates on every change, rather than only the changed one:

| Where | Model | Changes when |
|---|---|---|
| [`Bar.qml:68`](config/quickshell/penumbra/Bar.qml#L68) | workspaces, filtered and sorted | any workspace or window event |
| [`Bar.qml:236`](config/quickshell/penumbra/Bar.qml#L236) | CPU/RAM pair | every 2 s |
| [`ControlCenter.qml:511`](config/quickshell/penumbra/ControlCenter.qml#L511) | notification groups (a `ListView`, whose `displaced` transition therefore never runs) | every notification |
| [`ControlCenter.qml:564`](config/quickshell/penumbra/ControlCenter.qml#L564) | items in a group | every notification |

`ScriptModel` is the drop-in fix. The monitor panel already does this right with a `ListModel` updated in place ([`MonitorPanel.qml:106`](config/quickshell/penumbra/MonitorPanel.qml#L106)).

#### P3. `GlassEdge` costs an offscreen layer and a shader pass per surface

[`GlassEdge.qml`](config/quickshell/penumbra/GlassEdge.qml) uses a `layer.enabled` rectangle as a mask for a `MultiEffect`. It is used in every bar capsule ([`Capsule.qml:73`](config/quickshell/penumbra/Capsule.qml#L73)), so a bar has around ten offscreen textures plus effect passes, multiplied by the number of screens, and repainted whenever anything in the bar changes. The tray adds one `MultiEffect` per icon.

**Fix:** draw the lit edge without an effect, for example a gradient-filled rounded `Rectangle` with an inset rounded `Rectangle` of the surface colour on top (1 px smaller), or a single `ShaderEffect` shared by all capsules. Keep the MultiEffect version for the big panels if the look differs.

#### P4. Animated wallpapers keep rendering behind windows

[`Wallpaper.qml:72`](config/quickshell/penumbra/Wallpaper.qml#L72) pauses only for fullscreen windows and the lock screen. The far more common case, a workspace full of tiled windows that hide the wallpaper entirely, still runs the scene at 30 fps (eclipse: about 15 transformed full-size layers, two `Shape`s and a full-width shader). On a laptop this is a constant drain.

**Fix ideas:** pause when the active workspace has tiled windows (or when their area covers most of the monitor), pause on battery or in power-saver profile (both are already known to the shell through UPower and PowerProfiles), and expose these as settings next to "animated wallpapers".

The lock screen's scenes also keep ticking after hypridle turns the screens off; they could stop when DPMS is off.

#### P5. All control center pages exist all the time

[`ControlCenter.qml:53-110`](config/quickshell/penumbra/ControlCenter.qml#L53) declares eleven pages (LookPage alone is 545 lines) and only toggles `visible`. They are all built at startup and kept in memory even though the control center is closed most of the time. **Fix:** wrap each page in a `Loader { active: Ui.controlPage === "…" }` (state that must survive belongs in the singletons already).

#### P6. Work done at startup that could wait

- The emoji list (~5,000 lines of `emoji-test.txt`, one regex per line) is parsed when the shell starts ([`Launcher.qml:282`](config/quickshell/penumbra/Launcher.qml#L282)); the symbol list is flattened eagerly too ([line 32](config/quickshell/penumbra/Launcher.qml#L32)). Load them the first time emoji or symbols open.
- `zone1970.tab` is parsed at startup for night light ([`NightLight.qml:30`](config/quickshell/penumbra/NightLight.qml#L30)) even when the schedule is manual.

#### P7. Theme fades fight with colour Behaviors

During a palette fade every colour property in `Theme` changes every frame, so every component with `Behavior on color { ColorAnimation … }` (capsules, cards, launcher modes, session tiles…) restarts its animation every frame and trails behind the fade. `Theme.fading` was added for exactly this ([`Theme.qml:56-57`](config/quickshell/penumbra/Theme.qml#L56)) but **no component uses it**. **Fix:** `Behavior on color { enabled: !Theme.fading; ColorAnimation { … } }`.

#### P8. Minor

- `penumbra-updates status` runs its sources one after another with 180 s timeouts each ([`bin/penumbra-updates:53`](bin/penumbra-updates#L53)); running them in parallel (threads) would make "Check again" faster.
- Seeking in the control center sends a seek for every mouse move while dragging ([`ControlCenter.qml:468`](config/quickshell/penumbra/ControlCenter.qml#L468)); seeking on release (and showing the position locally while dragging) is kinder to players.
- The wallpaper scenes advance on a 33 ms `Timer`, which is not aligned with the display's refresh, so motion can look slightly uneven. A `FrameAnimation` that only updates every other frame would keep the 30 fps cost with smoother pacing.

---

## 6. Security and robustness

#### S1. Clipboard history stores passwords in plain text

`wl-paste --watch cliphist store` ([`bin/penumbra-session:38`](bin/penumbra-session#L38)) records everything, including passwords copied from KeePassXC, Bitwarden and similar, into `~/.cache/cliphist/db`, and the launcher shows them. Password managers mark such copies with the `x-kde-passwordManagerHint` MIME type, which recent wl-clipboard exposes as `CLIPBOARD_STATE=sensitive` to the watch command. Check that your cliphist version honours it; if not, wrap the store command so sensitive copies are skipped. An option to expire history after N days, or clear it at logout, would also help.

#### S2. Fingerprint is made sufficient for administrator prompts without asking

When `fprintd` is installed, `enable_fingerprint_polkit` silently inserts `pam_fprintd.so` as **sufficient** in polkit's PAM stack ([`install.sh:483-493`](install.sh#L483)). Many people consider a fingerprint acceptable for unlocking but not for root actions. It also copies the vendor file from `/usr/lib/pam.d` into `/etc/pam.d`, which then shadows future package updates of that file. **Fix:** ask first (default no), like the boot themes, and mention the vendor-file shadowing in the prompt.

#### S3. Background helpers are not supervised

`awww-daemon`, `hypridle` and the clipboard watchers are started with `nohup` ([`bin/penumbra-session:21-40`](bin/penumbra-session#L21)). If **hypridle** dies, the screen silently stops locking when idle and before sleep, which is a security problem, and nothing brings it back until the next login. **Fix:** give them systemd user units with `Restart=on-failure`, `PartOf=graphical-session.target`, like `penumbra-shell.service`.

#### S4. A crash loop while locked leaves the session with no lock UI

After five crashes in 60 s systemd gives up ([`penumbra-shell.service`](config/systemd/user/penumbra-shell.service)), and the user is told to recover from a TTY. **Fix:** an `OnFailure=` unit that starts `hyprlock` when `$XDG_RUNTIME_DIR/penumbra-locked` exists, so the fallback is automatic.

#### S5. The machine can suspend before the lock screen is drawn

hypridle's `before_sleep_cmd = loginctl lock-session` ([`bin/penumbra-settings:135`](bin/penumbra-settings#L135)) only *starts* locking; the system may sleep before the lock surface is on screen, so the desktop can flash on resume. Recent hypridle versions have `inhibit_sleep = 3` (wait until the session is locked); add it to the generated `general` block if your version supports it.

#### S6. The lock IPC can report success when no lock happened

`lock()` returns nothing ([`LockScreen.qml:29-44`](config/quickshell/penumbra/LockScreen.qml#L29)). If the compositor refuses the lock, `quickshell ipc call lock lock` still exits 0, so hypridle's `lock_cmd` never falls back to hyprlock. (When the shell is not running at all the exit code is 255 and the fallback works; this was checked.) **Fix:** return `bool` and have `lock_cmd` test the printed result, as `penumbra-osd` already does.

#### S7. `quickshell ipc call` exits 0 for unknown targets

Verified: with the shell running, `ipc call nosuchtarget foo` prints "Target not found." and exits 0. Every script that does `quickshell … ipc call … && exit` (launcher, power, shot, clipboard, record) would silently do nothing after an IPC rename or a version mismatch between scripts and shell. A tiny shared helper (`penumbra-ipc TARGET FUNC…`) that checks the output would make all fallbacks reliable (see Q7).

#### S8. Smaller items

- `penumbra-settings` validates values given on the command line but not values read back from `settings.conf` ([`bin/penumbra-settings:88`](bin/penumbra-settings#L88)) before putting them into Lua for `hyprctl eval` ([line 160](bin/penumbra-settings#L160)). `install.sh` does validate loaded settings. Only the user can edit that file, so this is robustness rather than a vulnerability; calling `problem()` in `load()` closes it.
- `penumbra-cast` fetches whatever `LOCATION` URL any device on the LAN answers SSDP with, and parses the XML ([`bin/penumbra-cast:99`](bin/penumbra-cast#L99)). Modern expat protects against entity bombs, so the risk is low, but a size limit on the response is cheap. The stream itself is plain HTTP on every interface, protected by a random path (fine for a home network; worth a line in the README).
- Idle timings are not checked for order (dim < lock < screens off). Setting "lock after 3 min" leaves the dim at 9.5 min, after the lock.

---

## 7. Code quality and maintainability

The code is consistent and readable, with a strong house style. These are the places where duplication or leftovers will cause the next bug.

#### Q1. `kitty` is hard-coded next to a "terminal" setting

The user can choose their terminal (Settings → Default apps, `terminal=` in `settings.conf`), and Super+Enter honours it, but these do not:

- [`Launcher.qml:199`](config/quickshell/penumbra/Launcher.qml#L199) (`>` command with Shift+Enter) and [line 217](config/quickshell/penumbra/Launcher.qml#L217) (apps with `Terminal=true`);
- [`Bar.qml:233`](config/quickshell/penumbra/Bar.qml#L233) and [`MonitorPanel.qml:743`](config/quickshell/penumbra/MonitorPanel.qml#L743);
- [`bin/penumbra-updates:122`](bin/penumbra-updates#L122).

Add one `Ui.terminal(command)` helper (and the equivalent in Python) that uses `Config.values.terminal`, with `xdg-terminal-exec` as an option.

#### Q2. Three different "current player" rules

`Media.qml:12-15`, `ControlCenter.qml:20` and `LockContent.qml:16` each decide which MPRIS player to show, differently; two of them are bugs (B2, B10). Keep only `Media.player`.

#### Q3. Repetition in `Ui.qml`

`toggleCalendar`, `toggleMonitor`, `toggleUpdates`, `toggleWallpapers` and `toggleControl` are the same function five times ([`Ui.qml:54-85`](config/quickshell/penumbra/Ui.qml#L54)), and `close()` must be kept in sync by hand (EXTENDING.md even documents copying it). A single `openPanel` string property (`"control"`, `"calendar"`…) with one `toggle(name)` would remove that whole class of mistakes.

#### Q4. Dead code

- `Theme.fading` is never read (see P7).
- `Look.endPreview()` is never called ([`Look.qml:72`](config/quickshell/penumbra/Look.qml#L72)).

#### Q5. Two readers of the same state file

The wallpaper choice is read by `Ui.qml:149` (watched) and by `Wallpaper.qml:45` (read once, then updated through IPC). If the IPC call from `penumbra-wallpaper` is missed, the two disagree until restart. `Wallpaper.qml` could follow `Ui.wallpaper` and only take the transition delay from IPC.

#### Q6. Waybar-era leftovers

`penumbra-updates status` still prints Waybar's `text`/`tooltip`/`class` fields with HTML escaping ([`bin/penumbra-updates:62-66`](bin/penumbra-updates#L62)), which `Sys.qml` parses back with a regex and partly un-escapes ([`Sys.qml:72-73`](config/quickshell/penumbra/Sys.qml#L72)); `html.escape` also produces `&quot;` and `&#x27;`, which are not un-escaped. Return plain JSON (`count`, `notes`, `sources`) instead.

#### Q7. IPC calls repeated across scripts

`quickshell -c penumbra ipc call …` appears in about ten scripts with slightly different success checks. A shared helper would fix S6/S7 in one place.

#### Q8. Settings defaults live in three places

`install.sh` (`detect_settings`), `bin/penumbra-settings` (`DEFAULTS`) and `hyprland.lua` (`settings()`) each have their own copy. The comments acknowledge it, and a test compares one key (`file_manager`). A test that compares all keys and defaults would stop them drifting.

#### Q9. Small things

- [`install.sh:642`](install.sh#L642): `then            found=1` is a formatting slip (a missing newline).
- [`tools/build-configuration.py:5`](tools/build-configuration.py#L5) mentions `tests/test_configuration.py`; the test is in `tests/test_generated.py`.
- The `osd adjust` IPC accepts any action string (B7); IPC entry points in general would benefit from validating their arguments.

#### Q10. Repository hygiene

- `CONFIGURATION.md` is a generated 884 KB, 21,500-line file that includes the wallpaper SVGs. Every change to any file changes it too, which doubles diffs and inflates history. Consider generating it only for releases, or leaving the SVGs out.
- `validation/` holds logs "from the original build" (including `waybar.log`), which no longer describe the project. Either regenerate them or remove them.
- `previews/desktop.png` and `terminal.png` still show the old name, Nocturne (the README says so).

#### Q11. Testing and CI

The Python test suite is good (62 tests, all passing, properly isolated with stub commands and temporary homes). Gaps:

- **No tests for the shell's logic.** Several pure functions would be easy to test: the launcher calculator and fuzzy scoring, `sun.js`, `oklch.js` (compare with `palette.py`), `Displays.place()` and `scales()`, `Notifs.age()`. They could run with `qmltestrunner` or, for the `.js` libraries, under Node.
- **No CI.** A GitHub Actions workflow running the unit tests, `build-configuration.py --check`, `shellcheck` on `install.sh` and `bin/*`, and `qmllint` with Quickshell's import path would catch regressions like B3 before they land.

---

## 8. Documentation drift

The README is detailed and mostly accurate, but the project has moved faster than it in a few places:

| README says | Reality |
|---|---|
| "Each workspace pill shows the icons of the apps open there" ([line 145](README.md#L145), [line 220](README.md#L220)) | The icons were removed in `4ced91b`; pills show the workspace name only. |
| "right-click for htop" ([line 145](README.md#L145)) | htop is not installed; btop is (B3). |
| "`ROADMAP.md` lists ideas" ([line 162](README.md#L162)) | There is no `ROADMAP.md`. |
| Settings page = Look, wallpaper, animations, hot corner ([line 223](README.md#L223)) | There are also Displays, Keyboard, Idle and sleep, Default apps and a Night light page with schedules. |
| "Change the monitor rule in `~/.config/hypr/user.lua`" ([line 212](README.md#L212)) | Settings → Displays now writes `~/.config/penumbra/monitors.lua`. |
| Night light "(hyprsunset, 4500 K)" ([line 222](README.md#L222)) | Temperature is adjustable; schedules by time or sunset/sunrise exist. |
| (not mentioned) | The **Overview** (Super+\` or a four-finger swipe up): live window previews, drag to move, type to search. |
| IPC list ([line 239](README.md#L239)) | Missing `panel overview`, `panel monitor`, `panel page NAME`, `nightlight toggle/isOn`, `lock isLocked`, `wallpaper set`, `osd capsLock`, `recorder refresh`, `cast refresh`. |

Running `quickshell -c penumbra ipc show` and pasting its output into the README (or generating that section) would keep the IPC list right.

---

## 9. Features worth adding

Grouped by theme and roughly ordered by value for effort within each group. Items marked ★ are the ones I would do first.

### Reliability and power

- ★ **Supervised helpers** (S3): systemd user units for hypridle, awww-daemon and the clipboard watchers.
- ★ **Automatic hyprlock fallback** (S4) when the shell can no longer be restarted while locked.
- ★ **Pause animated wallpapers when covered, on battery or in power saver** (P4), as settings.
- **Graceful log out / restart / shut down**: ask windows to close first (so apps can save or ask about unsaved work), wait a few seconds, then exit. Today `hl.dsp.exit()` and `systemctl poweroff` end apps abruptly ([`SessionMenu.qml:18-24`](config/quickshell/penumbra/SessionMenu.qml#L18)).
- **Battery care**: a charge limit toggle where the laptop supports `charge_control_end_threshold`.

### Notifications

- **Per-app rules**: mute, never pop up, or always keep, set from the history's group header.
- **Do not disturb on a schedule** (reuse night light's schedule code) and **automatically while recording, casting or fullscreen**, which avoids leaking notifications into a screen share or a presentation.
- **Notification sounds** (optional, per urgency).

### Launcher

- **Frecency** instead of a capped launch count ([`Launcher.qml:127`](config/quickshell/penumbra/Launcher.qml#L127)): after 15 launches every frequently used app ties today; a decaying score keeps "recent" meaningful.
- **Desktop actions** ("New private window", "New document"), which Quickshell's `DesktopEntry` exposes.
- **A window switcher mode** (jump to an open window), reusing the Overview's search.
- **More quick answers**: unit and currency conversion, a `?` prefix for a web search in the default browser, and file search (e.g. through `plocate` or `fd`).

### Clipboard

- ★ **Skip sensitive copies** (S1).
- **Pinned entries** that survive "Clear history", and an optional expiry.

### Screenshots, recording, casting

- **Capture across monitors** or choose the monitor; today the overlay only covers the focused screen ([`ScreenshotOverlay.qml:12`](config/quickshell/penumbra/ScreenshotOverlay.qml#L12)).
- **Recording options**: microphone audio, pause/resume, GIF export for short clips.
- **A fixed cast port option**, so a firewall rule can allow it.

### Lock screen and session

- Lock-screen **notification count** (without content, for privacy).
- **Idle inhibit rules** per app (video calls, presentations) in Settings → Idle.

### Settings and accessibility

- ★ **Reduced motion**: one switch that sets animation timings to 0, stops wallpaper motion and Hyprland animations. All timings already come from `Theme`, so this is cheap.
- **Text size**: scale the type scale in `Theme.qml` (every size already comes from there).
- **Export / import settings**: `settings.conf`, `shell.json`, `theme.json` and `monitors.lua` in one file, for moving to a new machine.
- **Search in Settings** as the number of pages grows.

### Updates

- **Arch news before upgrading**: show recent items from the Arch news feed in the updates panel, since some upgrades need manual intervention.
- **"Restart needed"** hint after a kernel or core library update.

### Calendar and bar

- **Week numbers** and an optional events source (iCal file, khal, or a CalDAV calendar through vdirsyncer).
- **Bluetooth device batteries** (UPower reports headsets, mice, controllers) in the Bluetooth page and the bar tooltip.

### Project

- ★ **CI** and **shell logic tests** (Q11).
- **Write the missing `ROADMAP.md`**, perhaps seeded from this section.

---

## 10. Suggested order of work

**Quick fixes (minutes each):**

1. B3: btop instead of htop in `Bar.qml`, and the README line.
2. B2 and B10: use `Media.player` in `LockContent.qml` and `ControlCenter.qml`.
3. B7: validate the brightness action.
4. B4: add `.var` to the uninstall's top-level folders.
5. B9: `<font color>` in `penumbra-picker`.
6. P1: `model: Media.count` for the spectrum.
7. P7: use `Theme.fading` to disable colour Behaviors during fades.
8. B12: the `?.` in `ScreenshotOverlay.qml`.

**Short tasks (an hour or two each):**

9. B1 and P2: move the JS-array models to `ScriptModel`.
10. B5: retire popups dropped from the stack; prune `Notifs.received`.
11. B8: persist manual night light.
12. Q1: one terminal helper used everywhere.
13. S2: ask before enabling fingerprint for polkit.
14. Documentation drift (section 8).

**Larger work:**

15. S3 and S4: systemd units for the helpers and the automatic lock fallback.
16. P3: a cheaper `GlassEdge`.
17. P4: smarter wallpaper pausing, with settings.
18. B6: cgroup-based app grouping in the monitor.
19. Q11: CI and shell logic tests.

---

## 11. How this review was done

- Read every QML and JavaScript file of the shell, every script in `bin/`, `install.sh`, `share/penumbra/palette.py`, the Hyprland, hyprlock and systemd configuration, `distro/arch/`, the README and EXTENDING.md, and skimmed the tests and tools. Cursor files, images, generated templates and the boot installer's internals were not reviewed line by line.
- Ran the test suite: `python -m unittest discover -s tests`, **62 tests, all passing**.
- Checked that generated files are current: `tools/build-configuration.py --check` and `tools/build-palette.py` produced no changes.
- Checked Quickshell 0.3.2's IPC exit codes on this machine: 255 when no instance is running, 0 for an unknown target, 0 when the function runs. This confirmed S7 and showed that hyprlock fallbacks do work when the shell is not running.
- Reproduced B7 by accident while testing IPC (the brightness was put back right away).
- Not verified at run time: the visual effects of B1, B2, B9 and P1–P4 were inferred from Qt's documented behaviour (a `Repeater` regenerates its delegates when its model is replaced; `StyledText` has no `<span>`), not watched on screen. `qmllint` was available but reported nothing without Quickshell's import paths, so no lint findings are included.
