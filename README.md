# NOCTURNE

An original black-and-violet Arch Linux desktop, installed for **lia** on **21 October 2026**. Targets **Hyprland 0.56.2 with Lua configuration**, SDDM 0.21, Kitty 0.49, and Fish 4.9. The French keyboard layout was preserved.

## Reinstall

Copy this whole folder to the target machine, open a terminal in it, and run:

```bash
chmod +x install.sh
./install.sh
```

Run as your regular desktop user. Sudo prompts normally; no password is stored in the bundle. The installer uses the current pacman databases, official Arch packages, timestamped backups, and user-scoped configuration. It does not install anything from the AUR. On a substantially older Arch installation, perform a normal full system upgrade yourself first. Never use `pacman -Sy` alone. This installer does not update repositories or configure the bootloader.

Log out through **Super+M → Log out → Confirm**, then sign in again when convenient. The running desktop has already been configured; a fresh login applies the environment to every application and displays the new greeter. Existing applications may need reopening to pick up fonts, colors, and icons. Applications that enforce their own theme still use their own appearance setting.

## Included

| Component | Design / behavior |
|---|---|
| Hyprland | Lua, violet gradient borders, rounded windows, blur, soft window/workspace animations |
| Waybar | Separate rounded capsules: launcher and clock on the left; occupied workspaces and focused window title in the center; CPU, RAM, tray, network, Bluetooth, audio and power on the right |
| Rofi | Application launcher, run command, window switcher, matching session menu |
| Kitty + Fish | Violet ANSI palette, animated cursor trail, Starship prompt, custom Arch logo and grouped Fastfetch greeting |
| Dolphin / Qt | Nocturne KDE and Qt palettes, Breeze widgets, Papirus violet folder overlay |
| GTK | Breeze Dark, near-black surfaces, violet selection/accent overrides |
| SDDM | Original animated QML greeter, orbital wallpaper, editable username, password, session selector, restart/shutdown confirmation |
| Hyprlock | Matching wallpaper, clock and password field; locks after ten idle minutes and before suspend |
| Notifications | Mako with violet borders and critical-notification persistence |
| Wallpaper | Original scalable SVG artwork plus pre-rendered PNG, no external image downloads |

Near-black `#0d0a12`, surface `#100d18`, violet `#b69af7`, text `#e4dced`, muted `#8f809f`. Fonts: Inter and JetBrainsMono Nerd Font.

## Controls

| Shortcut | Action |
|---|---|
| Super+Enter / Super+Q | Kitty with Fish |
| Super+Space / Super+R | App launcher |
| Super+E | Dolphin |
| Super+C | Close focused window |
| Super+V | Toggle floating |
| Super+F | Fullscreen |
| Super+arrow | Focus adjacent window |
| Super+physical number-row key | Workspace 1–10, AZERTY compatible |
| Super+Shift+physical number-row key | Move window to workspace |
| Super+left/right mouse drag | Move / resize |
| Super+J | Toggle split direction |
| Super+M | Session / power menu |
| Super+L | Lock |
| Super+N | Clear notifications |
| Super+Shift+R | Restart bar and wallpaper, reload notifications |
| Print | Select screenshot region; save to `~/Pictures/Screenshots` |
| Audio / media / brightness keys | Volume, mute, playback, brightness where hardware supports it |

Bar: click time to change date/time display; hover for calendar. CPU/RAM open htop. Click network for settings, right-click for the connection editor. Wi-Fi machines open nmtui for connecting to networks. Bluetooth opens Blueman when an adapter exists. Audio click opens pavucontrol; right-click mutes; scroll adjusts volume. Destructive session actions require confirmation.

## Files and destinations

- `config/` → `~/.config/` (all authored user configuration files).
- `bin/` → `~/.local/bin/` (session, power, network, Bluetooth, screenshot scripts).
- `share/` → `~/.local/share/` (KDE color scheme and violet icon overlay).
- `assets/wallpaper.png` → `~/.local/share/nocturne/wallpaper.png`.
- `system/` mirrors absolute system paths: SDDM configuration and complete theme.
- `CONFIGURATION.md` contains the full installer, helper scripts, every authored configuration, and wallpaper SVG in Markdown.
- `previews/` contains real screenshots of the installed desktop, launcher, power menu, lock screen, and greeter test mode.
- `validation/` contains package versions and validation logs.

`@@HOME@@` in the two Qt configuration templates is replaced by the installer's Python step. All other paths are portable home-relative paths or fixed standard system paths. The default shell changes through `usermod`; the installer does not copy account/password databases.

## What the installer changes

1. Installs the packages listed explicitly in `install.sh`.
2. Backs up existing managed system files under `/var/lib/nocturne/backups/TIMESTAMP` and deploys SDDM.
3. Sets the target user's login shell to `/usr/bin/fish`.
4. Enables NetworkManager and Bluetooth, and enables SDDM without restarting it.
5. Backs up managed user files under `~/.local/state/nocturne/backups/TIMESTAMP` and copies this configuration.
6. Applies GTK dark preference, font, cursor, and icon settings through GSettings.
7. Masks Dunst if installed, avoiding competing notification daemons.
8. Enables PipeWire sockets and WirePlumber; reloads Hyprland and starts the desktop components.

## Backups and rollback

Initial backups on this VM:

```text
~/.local/state/nocturne/backups/20261021-200558
/var/lib/nocturne/backups/20261021-200558
```

Every subsequent installer run creates a new backup. `new-files.txt` records paths that did not exist before that run. To reverse one run, restore its copied files to their original locations and remove only its listed new files after reviewing that list. The original Hyprland and Dolphin files are also in `before/.config/`.

For a minimal return to the original Hyprland config and SDDM theme on this machine, from this folder:

```bash
cp before/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua
cp before/.config/dolphinrc ~/.config/dolphinrc
sudo rm /etc/sddm.conf.d/90-nocturne.conf
hyprctl reload
```

This leaves installed packages and other theme settings in place. To change the login shell back, read `/var/lib/nocturne/backups/20261021-200558/previous-shell.txt` and run `sudo usermod -s /path/from/that/file lia`. To use Dunst again: `systemctl --user unmask dunst.service`, stop Mako, then start Dunst. GSettings values before installation are in `before/gsettings-interface.txt`. Do not restart SDDM from a session with unsaved work: that ends the session.

## Maintenance

```bash
# Validate Hyprland and reload the shell components
hyprctl configerrors
~/.local/bin/nocturne-session restart

# Reapply just the user files, without sudo or package installation
./install.sh --user-only

# Regenerate the wallpaper PNG after editing the SVG
rsvg-convert assets/wallpaper.svg -o assets/wallpaper.png
cp assets/wallpaper.png system/usr/share/sddm/themes/nocturne/wallpaper.png
./install.sh

# Inspect session logs
journalctl --user -b
cat ~/.local/state/nocturne/waybar.log

# Preview SDDM without logging out; close preview when finished
QT_QUICK_BACKEND=software sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/nocturne
```

The greeter uses Qt Quick's software backend to be reliable on this VM. Kitty uses its native cursor trail, avoiding expensive always-running custom shaders. Change `input.kb_layout` in `config/hypr/hyprland.lua` for a different keyboard layout. Change the monitor rule there if you want a particular resolution; this setup keeps the monitor's preferred mode.

## Sources and licensing

The Nocturne QML, wallpaper, configurations, and helper scripts were created for this setup. The icon overlay redistributes unmodified violet Papirus folder SVGs from the installed package, under GPL-3.0; see `licenses/Papirus-GPL-3.0.txt` and the [Papirus source](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme). It inherits the remaining icons from the installed Papirus theme.

Technical references: [Hyprland's Lua example](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua), the locally installed `/usr/share/hypr/stubs/hl.meta.lua`, [Kitty configuration](https://sw.kovidgoyal.net/kitty/conf/), [Qt6ct palette implementation](https://github.com/trialuser02/qt6ct/blob/master/src/qt6ct-common/qt6ct.cpp), [KDE color scheme manager](https://github.com/KDE/kcolorscheme/blob/master/src/kcolorschememanager.cpp), and [Hyprlock configuration implementation](https://github.com/hyprwm/hyprlock/blob/main/src/config/ConfigManager.cpp).

## Cursor follow-up

The desktop now uses the original **Nocturne Cursors at 28 px**, with software cursor rendering for the QEMU virtual GPU. A user-level `share/icons/default/index.theme` fallback keeps Xcursor clients consistent. GTK and SDDM also use 28 px. The session startup script applies `hyprctl setcursor Nocturne-Cursors 28` at every login, and `breeze-cursors` is an explicit installer dependency. These settings are included in the installer and all configuration copies.

On physical hardware, the software-rendering override can be removed from the `cursor` table in `hyprland.lua` if desired.

## Original Nocturne cursor set

Custom artwork drawn for this theme: lavender fill, dark outlines, pale highlights, matching text/resize/drag/action cursors, and a twelve-frame orbital busy animation. There are **22 original cursor designs**, **109 standard/legacy cursor names**, and sizes **24, 28, 32, 48, and 64 px**. The desktop, GTK applications, fallback theme, and SDDM select `Nocturne-Cursors`. Apps already open may retain their old cursor until reopened.

- Editable SVGs: `assets/cursors/`.
- Rebuild script: `tools/build-cursors.py`.
- Ready-to-install files: `system/usr/share/icons/Nocturne-Cursors/`.
- Visual catalogue: `previews/cursors.png` and `previews/cursors.svg`.
- Binary validation report: `validation/cursors.json`.

The existing `install.sh` installs the complete cursor theme with everything else. To rebuild the original vector designs and deploy:

```bash
sudo pacman -S --needed xorg-xcursorgen librsvg
python tools/build-cursors.py
./install.sh
```

The cursor artwork and builder are original to Nocturne. Unlike the Papirus folder overlay, they do not derive from another cursor theme. Breeze is only a fallback for rare cursor names outside this set.

## Floating bar refinement

Every bar module now has its own fully rounded capsule, with transparent space between them and no continuous panel background. The clock sits beside the launcher on the left. Occupied workspaces sit in the center, followed immediately by the focused window title. Each workspace button is a separate capsule too. Empty workspaces are suppressed, including the currently focused workspace if it has no windows. All ten workspace keyboard shortcuts still work.

Window titles are limited to 22 characters to preserve space for the system controls on this 1280-pixel display; the native window module retains its tooltip. The title capsule disappears on an empty desktop. The tray is one capsule containing the application tray icons. New screenshots: `previews/floating-bar.png` and `previews/floating-bar-empty.png`. Earlier preview images show the original layout.

To reload the bar after editing its source files and copying them into `~/.config/waybar/`:

```bash
pkill -USR2 -x waybar
```

## Terminal refinement

Kitty now uses 0.8 background opacity with the existing Nocturne palette and compositor blur. Fish opens with a faceted violet Arch-style logo, system and hardware panels, and palette dots. The compact Arch prompt keeps the clock on the right. Terminals narrower than 95 columns omit the image.

Fastfetch configuration and editable logo: `config/fastfetch/`. Render logo changes with `rsvg-convert config/fastfetch/nocturne-arch.svg -o config/fastfetch/nocturne-arch.png`. Fastfetch is included in installer dependencies. The installed settings and bundle were both updated; the terminal preview is on workspace 3. Screenshot: `previews/terminal.png`.

Before-change backup: `~/.local/state/nocturne/backups/terminal-20261021-213128/` (installed files under `.config/`, source files under `bundle/`).

## Package updates

A violet update capsule appears on the right only when pending updates are found. It checks official Arch packages, AUR packages through Paru or Yay (whichever is installed), and user/system Flatpak apps and runtimes every 15 minutes. Hover for counts; click to open Kitty and update. Normal password, package review and confirmation prompts remain interactive. The terminal closes on success, or waits for Enter after a failure. Repeated clicks do not start parallel update sessions. The bar refreshes after the update exits.

The installer includes `pacman-contrib` for its safe `checkupdates` command and Flatpak. Install Yay or Paru separately for AUR support. Repository checks use a separate database; they never refresh the live pacman database on their own. Failed checks are logged to the Waybar log and do not count as available updates. The helper is `bin/nocturne-updates`.

## Brightness, volume and battery

Hardware brightness and volume keys (including Fn+F2/F3/F6/F7 when those keys emit the corresponding media events) now show a violet popup at the bottom center with the current percentage and a progress bar. It disappears after 1.5 seconds; holding a key updates the same popup. Mute and microphone mute show their status too. Brightness stays above zero.

The bar shows an automatically detected battery immediately before the power button, with its percentage, charging state, and low-battery colors. Machines without a battery omit this module. Scrolling the audio capsule also shows the volume popup. No new packages are required.
