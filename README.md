# PENUMBRA

An original black-and-violet Arch Linux desktop. Targets **Hyprland 0.56 with Lua configuration**, Quickshell 0.3, SDDM 0.21, Kitty 0.49 and Fish 4.

## Install

Copy this whole folder to the target machine, open a terminal in it, and run:

```bash
chmod +x install.sh
./install.sh
```

Run as your regular desktop user. Sudo prompts normally; no password is stored in the bundle. The installer uses the current pacman databases, official Arch packages, timestamped backups, and user-scoped configuration; pacman asks about conflicts and replacements as usual. It does not install anything from the AUR. On a substantially older Arch installation, perform a normal full system upgrade yourself first. Never use `pacman -Sy` alone. This installer does not update repositories. Optional GRUB, Limine and Plymouth theming asks separately before changing boot configuration; see Boot themes below.

### Your settings

Before changing anything, the installer shows the settings below and offers to change them. On the first run it detects the keyboard layout this machine already uses (`localectl status`, falling back to the console keymap, then `us`). Your answers are saved in `~/.config/penumbra/settings.conf` and reused by later runs; edit that file and run `./install.sh --user-only` to change them.

| Setting | Option | Default |
|---|---|---|
| Keyboard layout | `--layout fr` (several: `--layout us,fr`) | detected, else `us` |
| Layout variant | `--variant intl` | detected, else none |
| Keyboard options | `--kb-options caps:escape` | detected, else none |
| Display scale | `--scale 1.25` | `auto` |
| Num Lock at login | `--numlock off` | `on` |
| Login shell | `--shell keep` | `fish` |

Command-line options win over the saved file. `-y` uses the saved or detected settings without asking; `./install.sh --help` lists every option. The login screen gets the same keyboard layout as the desktop (through `localectl`, leaving the text console keymap alone).

In a virtual machine (`systemd-detect-virt --vm`), the installer also turns on software cursors in Hyprland and renders the login screen in software at scale 1 (`/etc/sddm.conf.d/91-penumbra-vm.conf`), since virtual GPUs often draw hardware cursors and accelerated QML wrongly. On real hardware both use the GPU, and the login screen follows the screen's scale.

Log out through **Super+M → Log out → Confirm**, then sign in again when convenient. The running desktop has already been configured; a fresh login applies the environment to every application and displays the new greeter. Existing applications may need reopening to pick up fonts, colors, and icons. Applications that enforce their own theme still use their own appearance setting.

The keyring unlocks with the password you sign in with, so it stays locked (and asks for its password the first time an app needs it) after an automatic login, or after you change your password some way other than `passwd`.

### Your own settings

`./install.sh` replaces Penumbra's configuration files on every run (keeping the old ones in a backup), so put your own changes in these files, which it creates once and never replaces:

| App | File | Read |
|---|---|---|
| Hyprland | `~/.config/hypr/user.lua` | after `hyprland.lua`, so it can change or add anything |
| Kitty | `~/.config/kitty/user.conf` | after `kitty.conf` |
| Neovim | `~/.config/nvim/lua/user.lua` | at the end of `init.lua` |
| Fish | any file in `~/.config/fish/conf.d/` | before `config.fish` (Penumbra only owns `penumbra-colors.fish` there) |

### Uninstall

```bash
./install.sh --uninstall
```

This undoes every install run, newest first, from the backups the runs left: files Penumbra added are removed and files it replaced come back, in your account and in the system (login screen, cursors). It also restores your previous login shell, login-screen keyboard layout, GSettings and Dunst. What is there just before uninstalling is kept in an `uninstall-TIMESTAMP` backup, in case you changed something since. Installed packages stay installed, SDDM stays enabled unless you switch to another display manager, and boot themes have their own undo (see Boot themes). `--uninstall --user-only` only touches your account.

## Included

| Component | Design / behavior |
|---|---|
| Hyprland | Lua, slowly rotating violet gradient borders, violet glow on the focused window, rounded or sharp windows, frosted-glass blur behind every shell surface and the launcher, soft window/workspace animations |
| Penumbra shell | Quickshell (QML) bar of floating capsules, control center, notification popups and history, volume/brightness OSD, calendar, session overlay, app launcher, clipboard history, emoji and symbol picker, lock screen, polkit password dialog and screenshot overlay; see "Penumbra shell" below |
| Rofi | Fallback launcher, clipboard history and session menu when the shell is not running |
| Kitty + Fish | Violet ANSI palette, animated cursor trail, Starship prompt, custom Arch logo and grouped Fastfetch greeting |
| Dolphin / Qt | Penumbra KDE and Qt palettes, Breeze widgets, Papirus violet folder overlay |
| GTK | Breeze Dark for GTK 3, Penumbra colours for GTK 3, GTK 4 and libadwaita apps (and the file picker most apps use), close button only |
| GRUB | Optional orbital wallpaper, violet menu selection, keyboard hints and countdown |
| Limine | Optional ringed-planet wallpaper (never stretched), spaced PENUMBRA branding, lavender selection, violet key hints and countdown, Kitty's palette in the editor |
| Plymouth | Optional splash: the wallpaper's planet with a moonlet riding its ring and a breathing glow, PENUMBRA wordmark, frosted password card with keyboard layout and Caps Lock indicators, update progress |
| SDDM | Original animated QML greeter, wordmark-free orbital wallpaper, editable username, password, session selector, keyboard layout switch, Caps Lock warning, suspend and restart/shutdown confirmation; scales with the screen |
| Lock screen | The shell's own: the current wallpaper without its wordmark (dawn and eclipse keep moving), clock, password field with keyboard layout and Caps Lock indicators, and media controls; locks after ten idle minutes and before suspend. Hyprlock takes over when the shell is not running |
| Wallpaper | Three original SVG scenes, night, dawn and eclipse, plus pre-rendered PNGs and wordmark-free variants for the lock screen and greeter (`tools/build-wallpapers.py`); awww switches them with a transition that grows out of the planet. The shell animates dawn (twinkling stars, a breathing glow and rim light, a moonlet riding the ring, the odd shooting star) and eclipse (a drifting nebula, glinting stars, a swaying corona and diamond-ring flare, two backlit moons that pass in front of and behind the eclipse, an aurora on the near world's horizon, a blinking satellite, shooting stars); both pause under fullscreen windows |
| Neovim | Penumbra colour scheme with Treesitter highlighting, file tree, tabs, fuzzy search, Git markers; see "Neovim coding workspace" |
| Passwords | gnome-keyring keeps the passwords apps save (browsers, editors, Git credential helpers, Flatpak apps through the portal) and unlocks with your password when you sign in through SDDM; Seahorse ("Passwords and Keys") manages them |
| Tools | Screen recording (wf-recorder), clipboard history (cliphist), color picker (hyprpicker), screenshot annotation (Satty), night light (hyprsunset), audio visualizer (cava) |

### Palette

Every colour is defined once, in [`palette/palette.toml`](palette/palette.toml): near-black `#0d0a12`, surface `#100d18`, violet `#b69af7`, text `#e9e1f5`, muted `#8f809f`, plus the signal and terminal colours. `python tools/build-palette.py` renders the templates in `palette/templates/` into the colour files each app reads: Kitty's `penumbra-colors.conf`, the GTK 3/4 stylesheets, the Qt6ct and KDE colour schemes, rofi's `colors.rasi`, Hyprland's `colors.lua` and `hyprlock-colors.conf`, Fish's `conf.d/penumbra-colors.fish`, Starship, Satty, Fastfetch, Neovim's `lua/penumbra/palette.lua`, the shell's `palette.js` and the greeter's. Change a colour there, run the script, then `./install.sh --user-only` (or `./install.sh` for the greeter). Generated files say so in their first line; `tests/test_generated.py` checks they are current. The animated wallpapers, boot artwork and cursors keep their own colours in their build tools.

Fonts: Inter and JetBrainsMono Nerd Font.

## Controls

| Shortcut | Action |
|---|---|
| Super+Enter / Super+Q | Kitty with Fish |
| Super+Space / Super+R | App launcher (`>` runs a command, a sum is worked out) |
| Super+E | Dolphin |
| Super+B | Your default web browser (`xdg-settings set default-web-browser NAME.desktop` changes it) |
| Super+C | Close focused window |
| Super+V | Toggle floating |
| Super+F | Fullscreen |
| Super+arrow | Focus adjacent window |
| Super+physical number-row key | Workspace 1–10, on any keyboard layout (AZERTY included) |
| Super+Shift+physical number-row key | Move window to workspace |
| Super+left/right mouse drag | Move / resize |
| Super+J | Toggle split direction |
| Super+M | Session overlay |
| Super+A | Control center |
| Super+, | Settings (corner style, wallpaper, animations, hot corner) |
| Super+L | Lock |
| Super+N | Clear notifications |
| Super+Shift+V | Clipboard history |
| Super+; | Emoji and symbols (Tab switches between them) |
| Super+Shift+C | Pick a color on screen; copies its hex value |
| Super+W | Next wallpaper |
| Super+Shift+W | Wallpaper picker |
| Super+Shift+R | Restart the shell |
| Print | Screenshot a region, window or the whole screen; save to `~/Pictures/Screenshots` and copy it |
| Shift+Print | The same, then annotate it in Satty |
| Ctrl+Print | Record a region, window or the whole screen to `~/Videos/Screencasts`; press again to stop |
| Audio / media / brightness keys | Volume and brightness (repeat while held), mute, playback, where hardware supports it |

Bar: click the Arch logo for the launcher (right-click for the clipboard) and the clock for a calendar. Each workspace pill shows the icons of the apps open there. While something plays, a capsule shows it with a small spectrum: click for the control center, middle-click to pause, scroll to skip. CPU/RAM open the process monitor (right-click for htop). With several keyboard layouts, a capsule shows the current one; click it to switch. Click the network/Bluetooth/audio/battery capsule (or press Super+A) for the control center; right-click it for pavucontrol, scroll it for volume. Tray icons are tinted violet until hovered; right-click for their menu. Hover any capsule for details. Push the pointer into the top-right corner for the control center. Destructive session actions require a second press to confirm.

## Files and destinations

- `config/` → `~/.config/` (all authored user configuration files, including the shell's systemd unit in `config/systemd/user/`).
- `bin/` → `~/.local/bin/` (session, power, screenshot, screen recording, clipboard, color picker, OSD, update and wallpaper scripts).
- `config/quickshell/penumbra/` → the Penumbra shell (QML), run by `penumbra-shell.service`.
- `share/` → `~/.local/share/` (KDE color scheme and violet icon overlay).
- `assets/wallpaper*.png` (night, dawn and eclipse, each with a wordmark-free variant) → `~/.local/share/penumbra/`; `lock.png` there links to the clean variant of the current scene. After editing a wallpaper SVG, run `tools/build-wallpapers.py` to re-render them and the SDDM copy; it also splits the dawn and eclipse scenes into the layers under `config/quickshell/penumbra/dawn/` and `eclipse/` that the animated wallpapers move, and compiles the aurora shader (needs `qt6-shadertools`).
- `system/` mirrors absolute system paths: SDDM configuration and complete theme, and the cursor theme.
- `palette/` holds the palette and the templates of the generated colour files (see Palette).
- `CONFIGURATION.md` contains the installer, palette, tools, scripts, every authored configuration and the wallpaper SVGs in one Markdown document. It is generated by `python tools/build-configuration.py`; run that after changing a file.
- `previews/` contains screenshots of an earlier version, from before the theme was renamed: they still show the former name, Nocturne.
- `validation/` contains package versions and validation logs from the original build.

`@@PLACEHOLDERS@@` in configuration files (your home folder in the two Qt configurations; keyboard, Num Lock, scale and the cursor mode in `config/hypr/hyprland.lua`) are filled in by the installer as it copies them. All other paths are portable home-relative paths or fixed standard system paths. The default shell changes through `usermod`; the installer does not copy account/password databases.

## What the installer changes

1. Installs the packages listed explicitly in `install.sh`.
2. Backs up existing managed system files under `/var/lib/penumbra/backups/TIMESTAMP` and deploys SDDM and the cursors; in a virtual machine, adds the software-rendering greeter setting.
3. Sets the target user's login shell to `/usr/bin/fish` (unless `--shell keep`) and the login screen's keyboard layout to yours.
4. Enables NetworkManager and Bluetooth, and enables SDDM without restarting it.
5. Backs up managed user files under `~/.local/state/penumbra/backups/TIMESTAMP` and copies this configuration. Files Penumbra no longer ships are removed from the folders it owns outright (`~/.config/quickshell/penumbra`, `~/.config/nvim/lua/penumbra`, `~/.local/bin/penumbra-*`), so a renamed shell component never lingers; they are in the backup too. Creates the starter files for your own settings if they are missing.
6. Applies GTK dark preference, font, cursor, icon and title-bar button settings through GSettings. Sets up gnome-keyring: makes sure SDDM's PAM file unlocks it at sign-in (Arch's already does; the installer adds the two optional lines if they are missing), routes the Secret portal to it, and tells KWallet (which comes with Dolphin) not to claim the same Secret Service name.
7. Masks Dunst if installed, avoiding competing notification daemons.
8. Retires the previous Waybar/Mako/swaybg setup: asks whether to remove those packages (`PENUMBRA_REMOVE_LEGACY=1` or `0` answers in advance; removed versions are listed in the system backup), stops them, and moves `~/.config/waybar` and `~/.config/mako` into the user backup.
9. Enables PipeWire sockets and WirePlumber; reloads Hyprland and restarts the desktop components.

## Backups and rollback

Every installer run creates a new pair of backups, `~/.local/state/penumbra/backups/TIMESTAMP` and `/var/lib/penumbra/backups/TIMESTAMP`. `new-files.txt` records paths that did not exist before that run, `previous-shell.txt` the login shell, and the `gsettings-*.txt` files the GSettings values from before it. `./install.sh --uninstall` undoes all runs (see Uninstall). To undo only the latest run by hand, copy its saved files back to their original locations and remove the files listed in its `new-files.txt` after reviewing that list. Do not restart SDDM from a session with unsaved work: that ends the session.

## Maintenance

```bash
# Validate Hyprland and restart the shell
hyprctl configerrors
~/.local/bin/penumbra-session restart

# Reapply just the user files, without sudo or package installation
./install.sh --user-only

# After changing a colour in palette/palette.toml
python tools/build-palette.py
./install.sh --user-only

# Regenerate the wallpaper PNGs, the SDDM copy and the animated layers after editing an SVG
python tools/build-wallpapers.py
./install.sh

# Regenerate CONFIGURATION.md, and run the tests
python tools/build-configuration.py
python -m unittest discover -s tests -v

# Inspect logs
journalctl --user -u penumbra-shell -b
quickshell -c penumbra ipc show   # list the shell's IPC commands

# Preview SDDM without logging out; close preview when finished
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/penumbra
```

Kitty uses its native cursor trail, avoiding expensive always-running custom shaders. Keyboard layout and display scale are installer settings (see Your settings). Change the monitor rule in `~/.config/hypr/user.lua` if you want a particular resolution; Penumbra keeps the monitor's preferred mode.

## Penumbra shell

The bar, notifications, volume/brightness popup, control center, calendar, session overlay, launcher, lock screen, polkit agent and screenshot overlay are one Quickshell configuration in `config/quickshell/penumbra/`, replacing Waybar, Mako, Rofi, Hyprlock and the KDE polkit agent (Rofi and Hyprlock stay as fallbacks). Every surface is a translucent layer Hyprland blurs (namespaces `penumbra-*`).

It runs as the systemd user service `penumbra-shell.service`, which `penumbra-session` starts when Hyprland starts. If the shell crashes, systemd starts it again within a second; if the screen was locked, it locks again straight away (Hyprland keeps the session locked in between). Apps started from the shell run in their own systemd scopes, so restarting the shell (Super+Shift+R) never closes them.

- **Bar** keeps the floating-capsule layout. The active workspace pill widens, and each pill shows the icons of the apps open on it; the title capsule shows the focused window only on the current workspace. Scrolling a capsule steps once per wheel notch, touchpads included.
- **Launcher** (Super+Space): type to search applications; often-launched ones rise to the top. Start with `>` to run a command (Shift+Enter runs it in Kitty); nothing else ever runs as a command, so a search that matches no app does nothing. A sum such as `2*pi` or `=sqrt(2)` shows its result; Enter copies it. Tab switches to the **clipboard history**, with image thumbnails and swatches for copied colors: Enter copies, Shift+Delete forgets an entry, Super+Shift+V opens it directly. Tab again for **emoji**, then **symbols** (accented capitals, typographic quotes and dashes, currency, math, Greek, arrows, keys, shapes); Super+; opens emoji directly. Search by name, move with the arrows; Enter types the character into the focused window (wtype), Shift+Enter copies it. Often-picked ones come first.
- **Control center** (Super+A, or click the status capsule): Wi-Fi and Bluetooth toggles, Do not disturb, Stay awake (pauses idle locking), Night light (hyprsunset, 4500 K) and Screenshot, volume, microphone and brightness sliders, the current media player with its cover art and a seek bar, and notification history grouped by app with Clear all. Shortcuts for settings, the wallpaper picker, lock and the session overlay sit in its header. Escape or a click outside closes it.
- **Settings page** (Super+,, the gear in the control center header, or `ipc call panel settings`): rounded or sharp corners, the wallpaper, whether dawn and eclipse animate, and the top-right hot corner. The animation and hot corner choices are kept in `~/.config/penumbra/shell.json`.
- **Corners**: `penumbra-corners rounded|sharp|toggle` switches the whole desktop at once: every shell surface, Hyprland's windows, the rofi fallback, hyprlock, Satty and the Fastfetch box. The choice is kept in `~/.local/state/penumbra/corners`; Hyprland reads it on every load and `./install.sh` puts it back after copying the (rounded) configs. The SDDM greeter stays rounded.
- **Sound page** opens from the chevron beside the volume slider (or `ipc call panel mixer`): pick the output and input device, and set each app's own volume and mute.
- **Wi-Fi and Bluetooth pages** open from the chevron on each tile (or `ipc call panel wifi|bluetooth`). Wi-Fi lists nearby networks while the page is open: click a saved or open network to connect, type the password inline for a new secured one, and expand the connected or saved network to Disconnect or Forget it. Bluetooth lists your devices (one click connects; expand to Disconnect or Forget) and discovers new ones while open; click one to pair, trust and connect it. "Advanced settings" links still reach nm-connection-editor and Blueman for anything else (static IPs, enterprise Wi-Fi).
- **Tray**: nm-applet and Blueman keep running in the background for password and pairing prompts, but their tray icons are hidden since the control center covers them.
- **Notifications** pop in at the top right and move to the history when they time out (hovering pauses that). Each shows how long ago it arrived. Critical notifications stay until dismissed and still show during Do not disturb. Notifications an app marks as transient (volume changes, "copied" toasts) disappear when their popup does instead of filling the history, which keeps the newest 50. Clicking a notification runs its default action. Screenshots and photos show as a preview; chat apps that support it get a reply field.
- **Volume and brightness**: the hardware keys (including Fn+F2/F3/F6/F7 when those keys emit the corresponding media events) show a popup at the bottom center with the current percentage and a progress bar; it disappears after 1.5 seconds, and holding a key updates the same popup. The shell changes the value itself (`ipc call osd adjust volume up`), so held keys respond at once; `penumbra-osd` does it with wpctl and brightnessctl, and a plain notification, when the shell is not running. Mute and microphone mute show their status too. Brightness stays above zero. The bar shows an automatically detected battery immediately before the power button, with its percentage, charging state, and low-battery colors; machines without a battery omit it.
- **Lock screen** (Super+L, after ten idle minutes and before suspend): the clock over the current wallpaper without its wordmark, still animating, your `~/.face` (or initial), and the password field; it warns about Caps Lock, shows the keyboard layout when you have several (click to switch), and shows what's playing. Passwords go through the same PAM `login` stack hyprlock uses. If the shell cannot come back (it crashed five times within a minute), switch to a TTY (Ctrl+Alt+F3), log in and run `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`, then unlock there.
- **Polkit**: when an app asks for administrator rights, a password card appears over the dimmed screen in place of the KDE dialog.
- **Screenshots and recordings** (Print, or Ctrl+Print to start in Video): the screen freezes; drag a region, click a window, or click for the whole screen (R, W and S switch, E toggles annotating in Satty, Escape cancels). **Video** (V) records the area instead, **Sound** (A) adds what the computer plays, and **Timer** (T) waits 3, 5 or 10 seconds first, counting down in the bar (click the countdown to cancel). While recording, a red capsule in the bar shows the time; click it or press Ctrl+Print to stop. Recordings are H.264 MP4 files in `~/Videos/Screencasts`, copied to the clipboard as a file when they finish (paste into a chat or a file manager), with a notification that plays it. `bin/penumbra-record` does the recording, so it carries on if the shell restarts; without the shell, Ctrl+Print asks for a region with slurp.
- **Updates**: a violet update capsule appears on the right only when pending updates are found. It checks official Arch packages, AUR packages through Paru or Yay (whichever is installed), and user/system Flatpak apps and runtimes every 15 minutes. Click it for the list of pending packages by source, with Check again and Update now, which opens Kitty: password, package review and confirmation prompts stay interactive, the terminal closes on success or waits for Enter after a failure, and repeated clicks do not start parallel updates. Repository checks use `checkupdates` and a separate database, so they never refresh the live pacman database; failed checks are logged and do not count as available updates. The helper is `bin/penumbra-updates`.
- **Wallpaper picker** (Super+Shift+W, or the wallpaper button in the control center): the three wallpapers side by side; click one to switch.
- **Session overlay** (Super+M): arrow keys and Enter, or the mouse. Log out, Restart and Shut down ask for a second press.
- **Scripts** reach it through IPC: `quickshell -c penumbra ipc call panel control|wifi|bluetooth|mixer|settings|calendar|session|updates|wallpapers|close`, `launcher apps|clipboard|emoji|symbols`, `lock lock`, `shot open false`, `shot record`, `recorder stop`, `osd adjust volume|microphone|brightness up|down|mute|current`, `osd flash volume 40 false`, `notifications clear|dnd`, `updates refresh`. `penumbra-osd`, `penumbra-power`, `penumbra-launcher`, `penumbra-clipboard`, `penumbra-shot` and hypridle fall back to wpctl/brightnessctl, rofi, slurp and hyprlock when the shell is not running.

Edit the QML and Quickshell reloads it live. `Theme.qml` holds the fonts, radii and animation timings, and turns the palette into the shell's colour names.

## Cursors

Penumbra Cursors are original artwork drawn for this theme in a soft, rounded style: a sail-shaped arrow, chunky hands and split-arrowhead resize cursors with a moonlit lavender fill, midnight outlines and a light drop shadow. Violet badges mark copy/link/help/menu actions, a rose badge marks forbidden, and the busy cursor is a 24-frame violet arc that stretches as it circles a lavender ring. There are **22 original cursor designs**, **109 standard/legacy cursor names**, and sizes **24, 28, 32, 48, and 64 px**. The desktop (at 28 px), GTK applications, the user-level `share/icons/default/index.theme` fallback for Xcursor clients, and SDDM all select `Penumbra-Cursors`; the session startup applies `hyprctl setcursor Penumbra-Cursors 28` at every login. Apps already open may retain their old cursor until reopened.

- Editable SVGs: `assets/cursors/`.
- Rebuild script: `tools/build-cursors.py`.
- Ready-to-install files: `system/usr/share/icons/Penumbra-Cursors/`.
- Visual catalogue: `previews/cursors.png` and `previews/cursors.svg`.
- Binary validation report: `validation/cursors.json`.

The installer installs the complete cursor theme with everything else. To rebuild the original vector designs and deploy:

```bash
sudo pacman -S --needed xorg-xcursorgen librsvg
python tools/build-cursors.py
./install.sh
```

The cursor artwork and builder are original to Penumbra. Unlike the Papirus folder overlay, they do not derive from another cursor theme. `breeze-cursors` is only a fallback for rare cursor names outside this set.

## Terminal

Kitty uses 0.8 background opacity with the Penumbra palette and compositor blur. Fish opens with a faceted violet Arch-style logo, system and hardware panels, and palette dots; terminals narrower than 95 columns omit the image. The compact Starship prompt keeps the clock on the right.

Fastfetch configuration and editable logo: `config/fastfetch/` (its colours come from the palette template `palette/templates/config/fastfetch/config.jsonc`). Render logo changes with `rsvg-convert config/fastfetch/penumbra-arch.svg -o config/fastfetch/penumbra-arch.png`.

## Boot themes

Run the boot prompts alone, without reinstalling the desktop:

```bash
./install.sh --boot-only
```

The normal installer and `--system-only` also offer these prompts. `--user-only` never touches boot files. All boot questions default to **No**, and noninteractive runs skip them.

1. Look for Limine 12 or newer: on UEFI, firmware `LoaderInfo` must name Limine; on BIOS, `limine-bios.sys` gives the deployed version. Exactly one `limine.conf` must exist on the mounted FAT boot volumes (`/boot`, `/efi`, `/boot/efi`), in the places Limine searches, and you confirm that Limine reads it. A confirmed Limine boot skips the GRUB check.
2. Ask whether to apply the Limine theme. Put a managed appearance block at the top of `limine.conf` and copy the wallpaper next to it (`penumbra/background.png`). Entries, timeout, default entry and every other line stay as they were; your own copies of the options the block sets are commented out with a `#penumbra-off#` prefix, because Limine reads the first copy of an option and picks a random wallpaper when several are given. Reapplying replaces only that block.
3. Check GRUB tools and existing configuration. On UEFI, verify that the current firmware entry names GRUB. For a generic disk/fallback entry, accept firmware `LoaderInfo` identifying GRUB and ask you to confirm that it uses `/boot/grub/grub.cfg`. On legacy BIOS, check installed GRUB core/configuration and ask you to confirm GRUB is actually used; files alone cannot prove which bootloader ran.
4. Ask whether to apply the GRUB theme. Preserve the existing `grub.cfg` byte-for-byte and append a managed graphics block, using filesystem-relative asset paths. Reapplying replaces only that final block. This avoids losing UKI entries that `grub-mkconfig` cannot rediscover.
5. Check whether the Plymouth package is installed. If missing, ask whether to install it with normal interactive `pacman -S --needed plymouth` prompts.
6. Ask separately whether to apply the Plymouth theme. This adds `splash` to existing GRUB arguments, or to each Linux entry's `cmdline` in `limine.conf`, inserts `plymouth` after `udev` or `systemd` while retaining keyboard/encryption hooks, and rebuilds supported initramfs images. For supported UKIs, rebuild the EFI image instead, preserving its existing arguments and GRUB chainload or Limine entries. The installer backs up `/etc/kernel/cmdline`, appends `splash` if missing, and verifies that the rebuilt UKI embeds exactly those arguments. Explicit Plymouth-disable arguments require manual review.

No GRUB or Limine installation, partition changes, EFI entry writes, boot-sector writes or automatic reboot are performed. Menu timeout, default entry and recovery settings remain yours. A hidden menu remains hidden. Plymouth uses its built-in `two-step` renderer, including native disk-unlock/password dialogs; Escape can show boot details. Its labels use Inter, which Arch's hook copies into the initramfs, and the keyboard layout name comes from Plymouth's own packaged image, whose layout table is compiled into Plymouth. The Limine wallpaper is centred on a matching backdrop rather than stretched, so the planet stays round on any screen; smaller screens see its centre. The assets are original Penumbra artwork, built with `python tools/build-boot-assets.py` (Pillow, `rsvg-convert` and the Inter font required only for rebuilding artwork).

Automatic integration supports conventional Arch GRUB or Limine + mkinitcpio presets with existing `/boot/initramfs-*.img` and `/boot/vmlinuz-*` files. It also supports existing unsigned PE32+ UKIs in `/boot/EFI/Linux/*.efi` with Secure Boot disabled, a matching `/etc/kernel/cmdline`, and optional `--splash` bitmap / `-S autodetect` preset arguments. Disabled fallback preset assignments are allowed. UKI validation requires `objcopy` (binutils). It deliberately stops for unverified bootloaders, unconfirmed custom EFI chains, signed UKIs, custom UKI/signing settings, mixed UKI/initramfs outputs, dracut, custom preset options/config paths, mkinitcpio configuration drop-ins/post hooks, legacy Plymouth hooks, dynamic shell values and symlinked managed files. Limine setups whose entries are generated by limine-entry-tool (limine-mkinitcpio-hook, limine-snapper-sync) get the theme, but `splash` belongs in `KERNEL_CMDLINE` in `/etc/default/limine`; the installer stops and says so if it is missing. Limine command lines built from macros, several candidate `limine.conf` files and Limine releases before 12 also stop. These layouts need manual integration using the included `boot/grub/`, `boot/limine/` and `boot/plymouth/` assets. Installing the Plymouth package alone does not enable its splash. Existing package-manager hooks remain under pacman's control.

Boot changes have separate backups in `/var/lib/penumbra/boot-backups/`. Before replacement, the themed GRUB configuration must pass `grub-script-check`; its existing menu and discovery commands are retained. For conventional initramfs Plymouth integration only, menu regeneration must also contain a Linux or chainloader entry and preserve kernel/initrd/chainloader command lines apart from `splash`. Kernel updates not yet reflected in the current GRUB menu will therefore cause a safe refusal; reconcile those independently first. Initramfs images and UKIs are built to temporary files and checked for Plymouth/theme contents before replacing existing images. UKIs also have their embedded command line checked against the intended command line (the original plus `splash` if missing). Errors or handled interruptions restore the transaction's saved files; power loss cannot be made transactional across multiple boot files.

To undo a boot transaction, use the exact directory printed by the installer:

```bash
sudo python3 tools/install-boot.py --restore /var/lib/penumbra/boot-backups/EXACT-DIRECTORY
```

Restore newest first if undoing Plymouth and a boot-menu theme. This restores saved configuration, theme files and initramfs images without regeneration; newly installed packages stay installed. Only restore backups matching your current kernels—do not restore an old initramfs after upgrading its kernel. Backups can also be recovered from Arch installation media after mounting the installed system. Keep the backups until you have verified a reboot.

Validation: `python -m unittest discover -s tests -v` exercises configuration preservation, opt-in behavior, unsupported layouts, staged builds and rollback using isolated temporary files. These tests do not modify the running machine's boot files. Live firmware/boot appearance still needs a reboot test on the target machine.

Format references: [GNU GRUB theme manual](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html), [Limine configuration](https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md) (also `/usr/share/doc/limine/CONFIG.md`), [Arch Plymouth guidance](https://wiki.archlinux.org/title/Plymouth), [Plymouth's two-step plugin](https://gitlab.freedesktop.org/plymouth/plymouth/-/blob/main/src/plugins/splash/two-step/plugin.c), and the installed Arch Plymouth package's `two-step` themes and mkinitcpio hook.

### Generic EFI disk entries and UKIs

If `--boot-only` previously printed `Active EFI entry is not clearly GRUB`, the
installer skipped both themes. This can happen when firmware boots GRUB through
its fallback path and labels the entry “Solid State Disk”. It does not indicate
an artwork or graphics-driver failure. The updated detection uses GRUB's
firmware identity as additional evidence and still asks you to confirm its
configuration path before applying anything.

A machine booting `/EFI/Linux/arch-linux.efi` also needs the Plymouth theme in
that UKI's embedded initramfs. Rebuilding a separate `initramfs-linux.img` will
not update that splash. The installer now handles the supported unsigned UKI
layout described above. These changes are tested with isolated fixtures; a
successful real installation and reboot are still needed to verify appearance.

References: [GRUB theme selection](https://www.gnu.org/software/grub/manual/grub/html_node/Simple-configuration.html)
and [systemd UKI resources](https://www.freedesktop.org/software/systemd/man/devel/systemd-stub.html).

### A logo appears around the Plymouth animation

The mkinitcpio preset option `--splash /usr/share/systemd/bootctl/splash-arch.bmp`
adds a separate static Arch logo to the UKI, displayed by systemd-stub before
Plymouth runs. It is independent of the selected Plymouth theme. Applying
Penumbra now removes this stock bitmap option from the UKI build and backs up
and updates its preset so kernel updates do not reintroduce it. Custom bitmap
paths are preserved. Rollback restores the preset alongside the original UKI.
Penumbra also explicitly disables Plymouth's firmware-background mode.

The machine's initial manufacturer/firmware logo can still appear before the
OS boots. These changes do not control that firmware screen. A logo that
reappears after Penumbra may need separate graphics-handoff investigation.

## Neovim coding workspace

Neovim has an original Penumbra colorscheme with Treesitter highlighting, a left
file explorer, clickable open-file tabs, fuzzy file/text search, Git change
markers, a status bar and shortcut hints. Requires Neovim 0.12 or newer. Plugin versions are recorded in
`config/nvim/lazy-lock.json`. Initial plugin installation needs GitHub access.

Install only the editor setup (backs up any existing Neovim configuration):

```bash
./tools/install-neovim.sh
nvim /path/to/project
```

The full desktop installer also includes this configuration and the packages
`neovim git ripgrep wl-clipboard unzip nodejs npm tree-sitter-cli gcc`. For an editor-only installation,
install missing dependencies with `sudo pacman -S --needed` followed by those
package names. Open Neovim from your project's root, or pass its directory.
The file tree opens automatically for a directory or an empty launch.

Press `i` to type, then `Esc` to return to normal mode. In normal mode, press
**Space and wait** for shortcut hints. Press `Space ?` for the full menu.

| Shortcut (normal mode) | Action |
|---|---|
| Space e | Toggle the left file tree |
| Space o | Reveal current file in the tree |
| Ctrl+p / Space Space | Find a project file |
| Space f g | Search text across the project |
| Space f b | Choose an open file |
| Shift+h / Shift+l | Previous / next open file |
| Space b d | Close current file, protecting unsaved changes |
| Ctrl+s / Space s | Save |
| Space w h/j/k/l | Move between editor panes and the tree |
| Space w v / Space w s | Vertical / horizontal split |
| Space g p | Preview the Git change under the cursor |
| Space c m | Install language tools with Mason |
| gd / K | Definition / documentation (requires a language server) |
| Space c r / Space c a | Rename symbol / code action |
| Space c f | Format using an attached server that supports formatting |
| Space t | Open a terminal; double-Esc returns to normal mode |
| Space p | Plugin manager |
| Space q | Quit, asking about unsaved files |

In the tree, Enter opens files or expands folders; `a` creates, `r` renames,
and `g?` shows tree-specific help. Dotfiles are shown; `.git` is hidden.

Language tools are chosen per project: open Mason with `Space c m`, select a
server and press `i`, then restart Neovim. This setup automatically enables
installed `lua-language-server`, `pyright`, `typescript-language-server`,
`bash-language-server`, `clangd`, `rust-analyzer` and `gopls`. Servers can also be
installed with your system package manager. Node-based servers require Node/npm;
other servers may require their language runtime. No language servers are bundled.
With a server attached, completion appears as you type; Ctrl+n / Ctrl+p select
suggestions and Ctrl+y accepts. Without one, Ctrl+n still offers buffer words.
Code is coloured by Treesitter: parsers for Bash, C, CSS, Go, HTML, JavaScript,
JSON, Lua, Markdown, Python, QML, Rust, TOML, TypeScript and YAML are compiled
in the background on the first start (this needs `tree-sitter-cli` and a C
compiler); `:TSInstall LANGUAGE` adds others, and other files fall back to
Vim's syntax highlighting. Commenting (`gcc`) works everywhere. No automatic
formatting on save is enabled. Put your own settings in
`~/.config/nvim/lua/user.lua`, which the installers never replace.

Use `:Lazy restore` to return plugins to the recorded versions; `:Lazy update`
intentionally updates them. The standalone installer prints a backup directory;
to undo, move the installed `~/.config/nvim` aside and restore its saved `nvim`
directory, if one existed. Plugin downloads live separately in
`~/.local/share/nvim/lazy`.

Plugin references: [lazy.nvim installation](https://lazy.folke.io/installation),
[nvim-tree](https://github.com/nvim-tree/nvim-tree.lua),
[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter), and
[which-key](https://github.com/folke/which-key.nvim).

## Sources and licensing

The Penumbra QML, wallpaper, configurations, and helper scripts were created for this setup. The icon overlay redistributes unmodified violet Papirus folder SVGs from the installed package, under GPL-3.0; see `licenses/Papirus-GPL-3.0.txt` and the [Papirus source](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme). It inherits the remaining icons from the installed Papirus theme.

Technical references: [Hyprland's Lua example](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua), the locally installed `/usr/share/hypr/stubs/hl.meta.lua`, [Kitty configuration](https://sw.kovidgoyal.net/kitty/conf/), [Qt6ct palette implementation](https://github.com/trialuser02/qt6ct/blob/master/src/qt6ct-common/qt6ct.cpp), [KDE color scheme manager](https://github.com/KDE/kcolorscheme/blob/master/src/kcolorschememanager.cpp), and [Hyprlock configuration implementation](https://github.com/hyprwm/hyprlock/blob/main/src/config/ConfigManager.cpp).
