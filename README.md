# NOCTURNE

An original black-and-violet Arch Linux desktop. Targets **Hyprland 0.56.2 with Lua configuration**, SDDM 0.21, Kitty 0.49, and Fish 4.9.

## Install

Copy this whole folder to the target machine, open a terminal in it, and run:

```bash
chmod +x install.sh
./install.sh
```

Run as your regular desktop user. Sudo prompts normally; no password is stored in the bundle. The installer uses the current pacman databases, official Arch packages, timestamped backups, and user-scoped configuration. It does not install anything from the AUR. On a substantially older Arch installation, perform a normal full system upgrade yourself first. Never use `pacman -Sy` alone. This installer does not update repositories. Optional GRUB and Plymouth theming asks separately before changing boot configuration; see Boot themes below.

### Your settings

Before changing anything, the installer shows the settings below and offers to change them. On the first run it detects the keyboard layout this machine already uses (`localectl status`, falling back to the console keymap, then `us`). Your answers are saved in `~/.config/nocturne/settings.conf` and reused by later runs; edit that file and run `./install.sh --user-only` to change them.

| Setting | Option | Default |
|---|---|---|
| Keyboard layout | `--layout fr` (several: `--layout us,fr`) | detected, else `us` |
| Layout variant | `--variant intl` | detected, else none |
| Keyboard options | `--kb-options caps:escape` | detected, else none |
| Display scale | `--scale 1.25` | `auto` |
| Num Lock at login | `--numlock off` | `on` |
| Login shell | `--shell keep` | `fish` |

Command-line options win over the saved file. `-y` uses the saved or detected settings without asking; `./install.sh --help` lists every option. The login screen gets the same keyboard layout as the desktop (through `localectl`, leaving the text console keymap alone).

Log out through **Super+M → Log out → Confirm**, then sign in again when convenient. The running desktop has already been configured; a fresh login applies the environment to every application and displays the new greeter. Existing applications may need reopening to pick up fonts, colors, and icons. Applications that enforce their own theme still use their own appearance setting.

## Included

| Component | Design / behavior |
|---|---|
| Hyprland | Lua, slowly rotating violet gradient borders, violet glow on the focused window, rounded windows, frosted-glass blur behind every shell surface and the launcher, soft window/workspace animations |
| Nocturne shell | Quickshell (QML) bar of floating capsules, control center, notification popups and history, volume/brightness OSD, calendar, session overlay, app launcher, clipboard history, emoji and symbol picker, lock screen, polkit password dialog and screenshot overlay; see "Nocturne shell" below |
| Rofi | Fallback launcher, clipboard history and session menu when the shell is not running |
| Kitty + Fish | Violet ANSI palette, animated cursor trail, Starship prompt, custom Arch logo and grouped Fastfetch greeting |
| Dolphin / Qt | Nocturne KDE and Qt palettes, Breeze widgets, Papirus violet folder overlay |
| GTK | Breeze Dark, near-black surfaces, violet selection/accent overrides |
| GRUB | Optional orbital wallpaper, violet menu selection, keyboard hints and countdown |
| Plymouth | Optional animated violet orbit, native password dialogs and update progress |
| SDDM | Original animated QML greeter, wordmark-free orbital wallpaper, editable username, password, session selector, restart/shutdown confirmation |
| Lock screen | The shell's own: the current wallpaper without its wordmark (dawn and eclipse keep moving), clock, password field and media controls; locks after ten idle minutes and before suspend. Hyprlock takes over when the shell is not running |
| Wallpaper | Three original SVG scenes, night, dawn and eclipse, plus pre-rendered PNGs and wordmark-free variants for the lock screen and greeter (`tools/build-wallpapers.py`); awww switches them with a transition that grows out of the planet. The shell animates dawn (twinkling stars, a breathing glow and rim light, a moonlet riding the ring, the odd shooting star) and eclipse (a drifting nebula, glinting stars, a swaying corona and diamond-ring flare, two backlit moons that pass in front of and behind the eclipse, an aurora on the near world's horizon, a blinking satellite, shooting stars); both pause under fullscreen windows |
| Tools | Clipboard history (cliphist), color picker (hyprpicker), screenshot annotation (Satty), night light (hyprsunset), audio visualizer (cava) |

Near-black `#0d0a12`, surface `#100d18`, violet `#b69af7`, text `#e4dced`, muted `#8f809f`. Fonts: Inter and JetBrainsMono Nerd Font.

## Controls

| Shortcut | Action |
|---|---|
| Super+Enter / Super+Q | Kitty with Fish |
| Super+Space / Super+R | App launcher (`>` runs a command, a sum is worked out) |
| Super+E | Dolphin |
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
| Audio / media / brightness keys | Volume, mute, playback, brightness where hardware supports it |

Bar: click the Arch logo for the launcher (right-click for the clipboard) and the clock for a calendar. While something plays, a capsule shows it with a small spectrum: click for the control center, middle-click to pause, scroll to skip. CPU/RAM open the process monitor (right-click for htop). With several keyboard layouts, a capsule shows the current one; click it to switch. Click the network/Bluetooth/audio/battery capsule (or press Super+A) for the control center; right-click it for pavucontrol, scroll it for volume. Tray icons are tinted violet until hovered; right-click for their menu. Hover any capsule for details. Push the pointer into the top-right corner for the control center. Destructive session actions require a second press to confirm.

## Files and destinations

- `config/` → `~/.config/` (all authored user configuration files).
- `bin/` → `~/.local/bin/` (session, power, network, Bluetooth, screenshot, clipboard, color picker and wallpaper scripts).
- `config/quickshell/nocturne/` → the Nocturne shell (QML), started by `nocturne-session`.
- `share/` → `~/.local/share/` (KDE color scheme and violet icon overlay).
- `assets/wallpaper*.png` (night, dawn and eclipse, each with a wordmark-free variant) → `~/.local/share/nocturne/`; `lock.png` there links to the clean variant of the current scene. After editing a wallpaper SVG, run `tools/build-wallpapers.py` to re-render them and the SDDM copy; it also splits the dawn and eclipse scenes into the layers under `config/quickshell/nocturne/dawn/` and `eclipse/` that the animated wallpapers move, and compiles the aurora shader (needs `qt6-shadertools`).
- `system/` mirrors absolute system paths: SDDM configuration and complete theme.
- `CONFIGURATION.md` contains the full installer, helper scripts, every authored configuration, and wallpaper SVG in Markdown.
- `previews/` contains real screenshots of the installed desktop, launcher, power menu, lock screen, and greeter test mode.
- `validation/` contains package versions and validation logs.

`@@PLACEHOLDERS@@` in configuration files (your home folder in the two Qt configurations; keyboard, Num Lock and scale in `config/hypr/hyprland.lua`) are filled in by the installer as it copies them. All other paths are portable home-relative paths or fixed standard system paths. The default shell changes through `usermod`; the installer does not copy account/password databases.

## What the installer changes

1. Installs the packages listed explicitly in `install.sh`.
2. Backs up existing managed system files under `/var/lib/nocturne/backups/TIMESTAMP` and deploys SDDM.
3. Sets the target user's login shell to `/usr/bin/fish` (unless `--shell keep`) and the login screen's keyboard layout to yours.
4. Enables NetworkManager and Bluetooth, and enables SDDM without restarting it.
5. Backs up managed user files under `~/.local/state/nocturne/backups/TIMESTAMP` and copies this configuration.
6. Applies GTK dark preference, font, cursor, and icon settings through GSettings.
7. Masks Dunst if installed, avoiding competing notification daemons.
8. Retires the previous Waybar/Mako/swaybg setup: asks whether to remove those packages (`NOCTURNE_REMOVE_LEGACY=1` or `0` answers in advance; removed versions are listed in the system backup), stops them, and moves `~/.config/waybar` and `~/.config/mako` into the user backup.
9. Enables PipeWire sockets and WirePlumber; reloads Hyprland and starts the desktop components.

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

This leaves installed packages and other theme settings in place. To change the login shell back, read `/var/lib/nocturne/backups/20261021-200558/previous-shell.txt` and run `sudo usermod -s /path/from/that/file "$USER"`. To use Dunst again: `systemctl --user unmask dunst.service`, then start Dunst with the Nocturne shell stopped (it is the notification daemon). GSettings values before installation are in `before/gsettings-interface.txt`. Do not restart SDDM from a session with unsaved work: that ends the session.

## Maintenance

```bash
# Validate Hyprland and reload the shell components
hyprctl configerrors
~/.local/bin/nocturne-session restart

# Reapply just the user files, without sudo or package installation
./install.sh --user-only

# Regenerate the wallpaper PNGs, the SDDM copy and the animated layers after editing an SVG
python tools/build-wallpapers.py
./install.sh

# Inspect session logs
journalctl --user -b
cat ~/.local/state/nocturne/quickshell.log
quickshell -c nocturne ipc show   # list the shell's IPC commands

# Preview SDDM without logging out; close preview when finished
QT_QUICK_BACKEND=software sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/nocturne
```

The greeter uses Qt Quick's software backend to be reliable on this VM. Kitty uses its native cursor trail, avoiding expensive always-running custom shaders. Keyboard layout and display scale are installer settings (see Your settings). Change the monitor rule in `config/hypr/hyprland.lua` if you want a particular resolution; this setup keeps the monitor's preferred mode.

## Sources and licensing

The Nocturne QML, wallpaper, configurations, and helper scripts were created for this setup. The icon overlay redistributes unmodified violet Papirus folder SVGs from the installed package, under GPL-3.0; see `licenses/Papirus-GPL-3.0.txt` and the [Papirus source](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme). It inherits the remaining icons from the installed Papirus theme.

Technical references: [Hyprland's Lua example](https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua), the locally installed `/usr/share/hypr/stubs/hl.meta.lua`, [Kitty configuration](https://sw.kovidgoyal.net/kitty/conf/), [Qt6ct palette implementation](https://github.com/trialuser02/qt6ct/blob/master/src/qt6ct-common/qt6ct.cpp), [KDE color scheme manager](https://github.com/KDE/kcolorscheme/blob/master/src/kcolorschememanager.cpp), and [Hyprlock configuration implementation](https://github.com/hyprwm/hyprlock/blob/main/src/config/ConfigManager.cpp).

## Cursor follow-up

The desktop now uses the original **Nocturne Cursors at 28 px**, with software cursor rendering for the QEMU virtual GPU. A user-level `share/icons/default/index.theme` fallback keeps Xcursor clients consistent. GTK and SDDM also use 28 px. The session startup script applies `hyprctl setcursor Nocturne-Cursors 28` at every login, and `breeze-cursors` is an explicit installer dependency. These settings are included in the installer and all configuration copies.

On physical hardware, the software-rendering override can be removed from the `cursor` table in `hyprland.lua` if desired.

## Original Nocturne cursor set

Custom artwork drawn for this theme in a soft, rounded style: a sail-shaped arrow, chunky hands and split-arrowhead resize cursors with a moonlit lavender fill, midnight outlines and a light drop shadow. Violet badges mark copy/link/help/menu actions, a rose badge marks forbidden, and the busy cursor is a 24-frame violet arc that stretches as it circles a lavender ring. There are **22 original cursor designs**, **109 standard/legacy cursor names**, and sizes **24, 28, 32, 48, and 64 px**. The desktop, GTK applications, fallback theme, and SDDM select `Nocturne-Cursors`. Apps already open may retain their old cursor until reopened.

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

This Waybar layout has since been rebuilt in Quickshell; see "Nocturne shell".

## Terminal refinement

Kitty now uses 0.8 background opacity with the existing Nocturne palette and compositor blur. Fish opens with a faceted violet Arch-style logo, system and hardware panels, and palette dots. The compact Arch prompt keeps the clock on the right. Terminals narrower than 95 columns omit the image.

Fastfetch configuration and editable logo: `config/fastfetch/`. Render logo changes with `rsvg-convert config/fastfetch/nocturne-arch.svg -o config/fastfetch/nocturne-arch.png`. Fastfetch is included in installer dependencies. The installed settings and bundle were both updated; the terminal preview is on workspace 3. Screenshot: `previews/terminal.png`.

Before-change backup: `~/.local/state/nocturne/backups/terminal-20261021-213128/` (installed files under `.config/`, source files under `bundle/`).

## Package updates

A violet update capsule appears on the right only when pending updates are found. It checks official Arch packages, AUR packages through Paru or Yay (whichever is installed), and user/system Flatpak apps and runtimes every 15 minutes. Hover for counts; click to open Kitty and update. Normal password, package review and confirmation prompts remain interactive. The terminal closes on success, or waits for Enter after a failure. Repeated clicks do not start parallel update sessions. The bar refreshes after the update exits.

The installer includes `pacman-contrib` for its safe `checkupdates` command and Flatpak. Install Yay or Paru separately for AUR support. Repository checks use a separate database; they never refresh the live pacman database on their own. Failed checks are logged to the shell log and do not count as available updates. The helper is `bin/nocturne-updates`.

## Brightness, volume and battery

Hardware brightness and volume keys (including Fn+F2/F3/F6/F7 when those keys emit the corresponding media events) now show a violet popup at the bottom center with the current percentage and a progress bar. It disappears after 1.5 seconds; holding a key updates the same popup. Mute and microphone mute show their status too. Brightness stays above zero.

The bar shows an automatically detected battery immediately before the power button, with its percentage, charging state, and low-battery colors. Machines without a battery omit this module. Scrolling the audio capsule also shows the volume popup. No new packages are required.

## Nocturne shell

The bar, notifications, volume/brightness popup, control center, calendar, session overlay, launcher, lock screen, polkit agent and screenshot overlay are one Quickshell configuration in `config/quickshell/nocturne/`, replacing Waybar, Mako, Rofi, Hyprlock and the KDE polkit agent (Rofi and Hyprlock stay as fallbacks). Every surface is a translucent layer Hyprland blurs (namespaces `nocturne-*`).

- **Bar** keeps the floating-capsule layout. The active workspace pill widens; the title capsule shows the focused window only on the current workspace.
- **Launcher** (Super+Space): type to search applications; often-launched ones rise to the top. Start with `>` to run a command (Shift+Enter runs it in Kitty). A sum such as `2*pi` or `=sqrt(2)` shows its result; Enter copies it. Tab switches to the **clipboard history**, with image thumbnails and swatches for copied colors: Enter copies, Shift+Delete forgets an entry, Super+Shift+V opens it directly. Tab again for **emoji**, then **symbols** (accented capitals, typographic quotes and dashes, currency, math, Greek, arrows, keys, shapes); Super+; opens emoji directly. Search by name, move with the arrows; Enter types the character into the focused window (wtype), Shift+Enter copies it. Often-picked ones come first.
- **Control center** (Super+A, or click the status capsule): Wi-Fi and Bluetooth toggles, Do not disturb, Stay awake (pauses idle locking), Night light (hyprsunset, 4500 K) and Screenshot, volume, microphone and brightness sliders, the current media player with its cover art and a seek bar, and notification history grouped by app with Clear all. Shortcuts for the wallpaper picker, lock and the session overlay sit in its header. Escape or a click outside closes it.
- **Sound page** opens from the chevron beside the volume slider (or `ipc call panel mixer`): pick the output and input device, and set each app's own volume and mute.
- **Wi-Fi and Bluetooth pages** open from the chevron on each tile (or `ipc call panel wifi|bluetooth`). Wi-Fi lists nearby networks while the page is open: click a saved or open network to connect, type the password inline for a new secured one, and expand the connected or saved network to Disconnect or Forget it. Bluetooth lists your devices (one click connects; expand to Disconnect or Forget) and discovers new ones while open; click one to pair, trust and connect it. "Advanced settings" links still reach nm-connection-editor and Blueman for anything else (static IPs, enterprise Wi-Fi).
- **Tray**: nm-applet and Blueman keep running in the background for password and pairing prompts, but their tray icons are hidden since the control center covers them.
- **Notifications** pop in at the top right and move to the history when they time out (hovering pauses that). Critical notifications stay until dismissed and still show during Do not disturb. Clicking a notification runs its default action. Screenshots and photos show as a preview; chat apps that support it get a reply field.
- **Lock screen** (Super+L, after ten idle minutes and before suspend): the clock over the current wallpaper without its wordmark, still animating, your `~/.face` (or initial), and the password field; it warns about Caps Lock and shows what's playing. Passwords go through the same PAM `login` stack hyprlock uses. If the shell ever dies while locked, switch to a TTY (Ctrl+Alt+F3), log in and run `hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'`, then unlock there.
- **Polkit**: when an app asks for administrator rights, a password card appears over the dimmed screen in place of the KDE dialog.
- **Screenshots** (Print): the screen freezes; drag a region, click a window, or click for the whole screen (R, W and S switch, E toggles annotating in Satty, Escape cancels).
- **Updates**: the updates capsule opens a list of pending packages by source, with Check again and Update now.
- **Wallpaper picker** (Super+Shift+W, or the wallpaper button in the control center): the three wallpapers side by side; click one to switch.
- **Session overlay** (Super+M): arrow keys and Enter, or the mouse. Log out, Restart and Shut down ask for a second press.
- **Scripts** reach it through IPC: `quickshell -c nocturne ipc call panel control|wifi|bluetooth|mixer|calendar|session|updates|wallpapers|close`, `launcher apps|clipboard|emoji|symbols`, `lock lock`, `shot open false`, `osd flash volume 40 false`, `notifications clear|dnd`, `updates refresh`. `nocturne-osd`, `nocturne-power`, `nocturne-launcher`, `nocturne-clipboard`, `nocturne-shot` and hypridle fall back to a plain notification, rofi, slurp and hyprlock when the shell is not running.

Edit the QML and Quickshell reloads it live. `Theme.qml` holds the palette, fonts, radii and animation timings.

## Boot themes

Run the boot prompts alone, without reinstalling the desktop:

```bash
./install.sh --boot-only
```

The normal installer and `--system-only` also offer these prompts. `--user-only` never touches boot files. All boot questions default to **No**, and noninteractive runs skip them.

1. Check GRUB tools and existing configuration. On UEFI, verify that the current firmware entry names GRUB. For a generic disk/fallback entry, accept firmware `LoaderInfo` identifying GRUB and ask you to confirm that it uses `/boot/grub/grub.cfg`. On legacy BIOS, check installed GRUB core/configuration and ask you to confirm GRUB is actually used; files alone cannot prove which bootloader ran.
2. Ask whether to apply the GRUB theme. Preserve the existing `grub.cfg` byte-for-byte and append a managed graphics block, using filesystem-relative asset paths. Reapplying replaces only that final block. This avoids losing UKI entries that `grub-mkconfig` cannot rediscover.
3. Check whether the Plymouth package is installed. If missing, ask whether to install it with normal interactive `pacman -S --needed plymouth` prompts.
4. Ask separately whether to apply the Plymouth theme. This adds `splash` to existing GRUB arguments, inserts `plymouth` after `udev` or `systemd` while retaining keyboard/encryption hooks, and rebuilds supported initramfs images. For supported UKIs, rebuild the EFI image instead, preserving its existing arguments and GRUB chainload entries. The installer backs up `/etc/kernel/cmdline`, appends `splash` if missing, and verifies that the rebuilt UKI embeds exactly those arguments. Explicit Plymouth-disable arguments require manual review.

No GRUB installation, partition changes, EFI entry writes, boot-sector writes or automatic reboot are performed. Menu timeout, default entry and recovery settings remain yours. A hidden menu remains hidden. Plymouth uses its built-in `two-step` renderer, including native disk-unlock/password dialogs; Escape can show boot details. The assets are original Nocturne artwork, built with `python tools/build-boot-assets.py` (Pillow and the desktop's JetBrains Mono font required only for rebuilding artwork).

Automatic integration supports conventional Arch GRUB + mkinitcpio presets with existing `/boot/initramfs-*.img` and `/boot/vmlinuz-*` files. It also supports existing unsigned PE32+ UKIs in `/boot/EFI/Linux/*.efi` with Secure Boot disabled, a matching `/etc/kernel/cmdline`, and optional `--splash` bitmap / `-S autodetect` preset arguments. Disabled fallback preset assignments are allowed. UKI validation requires `objcopy` (binutils). It deliberately stops for unverified bootloaders, unconfirmed custom EFI chains, signed UKIs, custom UKI/signing settings, mixed UKI/initramfs outputs, dracut, custom preset options/config paths, mkinitcpio configuration drop-ins/post hooks, legacy Plymouth hooks, dynamic shell values and symlinked managed files. These layouts need manual integration using the included `boot/grub/` and `boot/plymouth/` assets. Installing the Plymouth package alone does not enable its splash. Existing package-manager hooks remain under pacman's control.

Boot changes have separate backups in `/var/lib/nocturne/boot-backups/`. Before replacement, the themed GRUB configuration must pass `grub-script-check`; its existing menu and discovery commands are retained. For conventional initramfs Plymouth integration only, menu regeneration must also contain a Linux or chainloader entry and preserve kernel/initrd/chainloader command lines apart from `splash`. Kernel updates not yet reflected in the current GRUB menu will therefore cause a safe refusal; reconcile those independently first. Initramfs images and UKIs are built to temporary files and checked for Plymouth/theme contents before replacing existing images. UKIs also have their embedded command line checked against the intended command line (the original plus `splash` if missing). Errors or handled interruptions restore the transaction's saved files; power loss cannot be made transactional across multiple boot files.

To undo a boot transaction, use the exact directory printed by the installer:

```bash
sudo python3 tools/install-boot.py --restore /var/lib/nocturne/boot-backups/EXACT-DIRECTORY
```

Restore newest first if undoing both Plymouth and GRUB. This restores saved configuration, theme files and initramfs images without regeneration; newly installed packages stay installed. Only restore backups matching your current kernels—do not restore an old initramfs after upgrading its kernel. Backups can also be recovered from Arch installation media after mounting the installed system. Keep the backups until you have verified a reboot.

Validation: `python -m unittest discover -s tests -v` exercises configuration preservation, opt-in behavior, unsupported layouts, staged builds and rollback using isolated temporary files. These tests do not modify the running machine's boot files. Live firmware/boot appearance still needs a reboot test on the target machine.

Format references: [GNU GRUB theme manual](https://www.gnu.org/software/grub/manual/grub/html_node/Theme-file-format.html), [Arch Plymouth guidance](https://wiki.archlinux.org/title/Plymouth), and the installed Arch Plymouth package's `two-step` theme and mkinitcpio hook.

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
Nocturne now removes this stock bitmap option from the UKI build and backs up
and updates its preset so kernel updates do not reintroduce it. Custom bitmap
paths are preserved. Rollback restores the preset alongside the original UKI.
Nocturne also explicitly disables Plymouth's firmware-background mode.

The machine's initial manufacturer/firmware logo can still appear before the
OS boots. These changes do not control that firmware screen. A logo that
reappears after Nocturne may need separate graphics-handoff investigation.

## Neovim coding workspace

Neovim now has an original Nocturne colorscheme, a left file explorer, clickable
open-file tabs, fuzzy file/text search, Git change markers, a status bar and
shortcut hints. Requires Neovim 0.11.3 or newer. Plugin versions are recorded in
`config/nvim/lazy-lock.json`. Initial plugin installation needs GitHub access.

Install only the editor setup (backs up any existing Neovim configuration):

```bash
./tools/install-neovim.sh
nvim /path/to/project
```

The full desktop installer also includes this configuration and the packages
`neovim git ripgrep wl-clipboard unzip nodejs npm`. For an editor-only installation,
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
Neovim's bundled syntax highlighting and commenting (`gcc`) are available without
extra language tooling. No automatic formatting on save is enabled.

Use `:Lazy restore` to return plugins to the recorded versions; `:Lazy update`
intentionally updates them. The standalone installer prints a backup directory;
to undo, move the installed `~/.config/nvim` aside and restore its saved `nvim`
directory, if one existed. Plugin downloads live separately in
`~/.local/share/nvim/lazy`.

Plugin references: [lazy.nvim installation](https://lazy.folke.io/installation),
[nvim-tree](https://github.com/nvim-tree/nvim-tree.lua), and
[which-key](https://github.com/folke/which-key.nvim).
