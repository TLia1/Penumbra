# Appearance and application themes

## Curated palettes

**Settings → Look → Curated palettes** applies a complete palette and a paired built-in
wallpaper scene. The six presets tune background and surface lightness as well as the accent;
the palette engine checks text contrast in both modes. Custom colour edits leave the preset.

| Preset | CLI ID | Paired scene |
|---|---|---|
| Penumbra | `penumbra` | Moonwake |
| Solar Corona | `solar-corona` | Amber Dawn |
| Aurora Borealis | `aurora-borealis` | Polar curtain |
| Event Horizon | `event-horizon` | Rose-red Eclipse |
| Nebula Rose | `nebula-rose` | Rose Night |
| Starlight | `starlight` | Pearl Dawn |

```bash
penumbra-theme set preset=solar-corona
penumbra-theme set colors=default mode=dark
```

The second command restores the default palette while keeping the selected wallpaper.
Aurora Borealis adds a folded mint curtain across the sky, visible in the [tiled workspace capture](../previews/aurora-workspace.png).
Each preset now pairs its palette with coordinated artwork. `tools/build-wallpapers.py`
recolours the original SVG sources before rendering the still, wordmark-free lock image and
animated layers. Stars, moonlets and the eclipse aurora use the scene's matching tint. The
original Night, Dawn and Eclipse remain available in the wallpaper picker. Custom wallpaper
images keep their own colours.

## Bar layout and motion

Look also offers **Capsules / Island / Framed** bar layouts, **Numbers / Numbers + icons /
Dots** workspace styles, a **Bottom / Top island** OSD, and a **Glass frost** slider.
**Compact system monitor** replaces CPU and RAM readings with one icon that opens the same graphs.
The signature layout keeps floating capsules and uses numbered workspaces; existing saved
preferences remain in effect. **Apply signature layout** also turns off the frame, desktop
clock/aura, bar weather and dock, and restores the bottom OSD and neutral frost. Weather service,
accessibility and palette choices stay yours. Weather beside the clock uses the calendar's
opt-in weather service and hides stale readings. Body text defaults to 14 px, secondary labels to 12 px and metadata to 11 px. Panels use a
readable, nearly opaque surface; quiet separators and solid accent selections establish hierarchy.
The bar retains its glass treatment. Controls grow with their labels, panel widths fit the output,
and the launcher and wallpaper gallery scroll on small screens. System controls use the shared
Nerd Font family, lunar phases use a palette-aware illustration, and app logos share one resolver
for icon names, absolute files and image URLs. Spring feedback, slider value bubbles, card wash
and cursor lighting remain available. Reduced motion and sharp
corners still apply.

**Panel motion**: calendar, control center, system monitor, updates and wallpaper sheets spring open from their bar capsule on the active monitor. Control-center sections, system-monitor cards and launcher results enter with an 18 ms stagger. Reduced motion makes these transitions immediate.

## Wallpapers

**Moonwake** is the default Penumbra scene. A full moon lights a violet alpine lake. Thin clouds drift over the peaks and the reflection ripples between the banks. Enable **Depth clock** in Settings → Bar, dock & desktop to place the date and time in the mountain saddle. **Audio aura** places fourteen separate bars of light along the far shore, from bass on the left to treble on the right. Each bar rises with its own frequency band and casts a short reflection on the lake. [Animated preview](../previews/moonwake.webp)

**Wallpaper picker** (Super+Shift+W, or the wallpaper button in the control center): Penumbra's built-in wallpapers, then the images, GIFs and videos in `~/Pictures/Wallpapers` (Open folder creates and opens it); click one to switch, or move with the arrow keys (Tab, Home and End too) and press Enter.

**Your own wallpapers**: any PNG, JPEG, WebP or BMP image, GIF, or MP4, WebM, MKV or MOV video. Put them in `~/Pictures/Wallpapers` to see them in the picker and in Super+W's cycle, right-click one in Lia Files or Dolphin and choose **Set as Wallpaper**, or run `penumbra-wallpaper PATH`. awww shows a GIF's or video's first frame with the usual transition, then the shell plays it over that frame on a loop, silently and without an audio stream, pausing under fullscreen windows and while locked, as it does for the built-in scenes; with animated wallpapers off in Settings it stays on that first frame. The lock screen shows the still image or first frame. Videos decode with Qt Multimedia's FFmpeg backend, which uses the GPU's video decoder when it has one; first frames are kept in `~/.cache/penumbra/wallpapers/`.

**Desktop depth and frame** (Settings → Look): optional clock and date behind the foreground planet in Dawn and Eclipse, plus an audio aura using the existing Cava stream: a radial spectrum in Dawn, and audio-driven curtains replacing the ambient drift in Eclipse’s foreground horizon aurora during playback. The curtains rise, brighten and fold with the frequency bands, settling to a faint rim during silence; the ambient aurora returns when the audio aura is inactive. The clock remains visible with wallpaper animations off or Reduced motion on; the aura pauses with wallpaper motion, including battery, covered-workspace and lock-screen pauses. These widgets stay off the lock screen. An optional thin screen frame adds concave joins under the bar on every monitor, follows sharp corners, accepts no input and hides for fullscreen windows. All three options default to off and persist in `~/.config/penumbra/shell.json`.

For custom desktop depth, put `mountains.jpg` and a matching transparent `mountains-fg.png`
in `~/Pictures/Wallpapers`, select the base image and enable **Depth clock**. Use the same
image dimensions and alignment for both files; foreground masks are omitted from the picker
and wallpaper cycling. A missing mask leaves the normal wallpaper alone. The lock screen
continues to use the unmodified wallpaper.

## Theme commands

**Corners**: `penumbra-corners rounded|sharp|toggle` switches the whole desktop at once: every shell surface, MangoWM's windows, the rofi fallback, Satty and the Fastfetch box. The choice is kept in `~/.local/state/penumbra/corners`; MangoWM reads it on every load and `./install.sh` puts it back after copying the (rounded) configs. The SDDM greeter stays rounded.

**Theme**: `penumbra-theme set mode=dark|light` switches between dark and light (`mode=auto` follows `auto=dark|light`, which the shell sets at sunrise and sunset), and `penumbra-theme set colors=custom hue=190 vividness=0.9` moves the accent (and the faint tint of surfaces and text) to another hue (`colors=default` for Penumbra's violet; vividness 0 is grey), and `penumbra-theme set colors=wallpaper` takes it from the wallpaper (`pick=0`–`3` for its other accents; `penumbra-theme get` lists them); `harmonize=true` turns red, green, amber and the others up to 15° toward a custom or wallpaper accent. Wallpaper colours follow the wallpaper: `penumbra-wallpaper` hands each new one to `penumbra-theme`, and the shell fades to its strongest accent while it grows in. A GIF or video gives the colours of its most typical frame, found once and kept in `~/.cache/penumbra/theme/`; Penumbra's own wallpapers have hand-picked ones in `share/penumbra/wallpaper-colors.json`. The shell fades to the new colours and MangoWM applies the new border colours; Kitty, fish, Neovim, KDE apps and open VS Code windows follow at once, the folder icons take the accent (apps show them when they next start), GTK and libadwaita switch dark/light at once, and other apps show the new colours when they next start. The choice is kept in `~/.local/state/penumbra/theme.json`, and `./install.sh` puts it back after copying the (dark) configs. VS Code has *Penumbra* and *Penumbra Light*, rewritten in the installed extension for your accent; the SDDM greeter stays dark.

## Edit the source palette

Every colour is defined once, in [`palette/palette.toml`](../palette/palette.toml): near-black `#0d0a12`, surface `#100d18`, violet `#b69af7`, text `#e9e1f5`, muted `#8f809f`, plus the signal and terminal colours. `python tools/build-palette.py` renders the templates in `palette/templates/` into the colour files each app reads: Kitty's `penumbra-colors.conf`, the GTK 3/4 stylesheets, the Qt6ct and KDE colour schemes, rofi's `colors.rasi`, MangoWM's `colors.conf`, Fish's `conf.d/penumbra-colors.fish`, Starship, Satty, Fastfetch, Neovim's `lua/penumbra/palette.lua`, the shell's `palette.js` and the greeter's. Change a colour there, run the script, then `./install.sh --user-only` (or `./install.sh` for the greeter). Generated files say so in their first line; `tests/test_generated.py` checks they are current.

## Application themes

Lia Files can be installed separately from its [Arch PKGBUILD or Flatpak](https://github.com/TLia1/Lia-s-file-linux#install). The ArchISO installer installs Lia Files. On an existing system, Penumbra keeps your saved file manager or the one you specify with `--file-manager`. On a first install it keeps a launchable default for folders, then looks for Lia Files and Dolphin. If both are missing, the full installer offers to install Dolphin from the Arch repositories (`--yes` accepts). The native Lia Files build supplies the **Open**, **Select Folder** and **Save** dialog of apps that use the file chooser portal, such as choosing where a download goes (`config/xdg-desktop-portal/portals.conf` prefers `lia`, then `gtk`). GTK apps (`GTK_USE_PORTAL=1`) and Firefox (a `user.js` preference) are set to use the portal; Chromium-based and Electron apps already do. Without Lia Files the portal uses GTK's dialogs. Run `./install.sh --user-only` after installing Lia Files to add its theme. This needs the Lia Files build with user stylesheet support. The native CSS goes in `~/.config/lia-files/`; Flatpak also gets a copy in `~/.var/app/io.github.lia.Files/config/lia-files/`. Both reload while the app is open. `penumbra-corners` controls its radii, while file surfaces stay almost opaque for readability. The installer selects the Penumbra preview schemes when the current scheme is Adwaita, and sets the desktop monospace font to JetBrainsMono Nerd Font 10. GtkSourceView schemes are shared under `~/.local/share/gtksourceview-5/styles/` and copied to the sandbox for Flatpak.

Apps Penumbra doesn't install get their colours from `apps/NAME/`, also rendered from the palette. The installer uses a folder only when the app's command is there, so the package list stays the same; installing the app later and running `./install.sh --user-only` again picks it up. Each app's own settings file is only added to (and kept in the backup like everything else); if it already chooses a theme of its own, that choice stays.

| App | What the installer does |
|---|---|
| Lia Files | watched `~/.config/lia-files/penumbra.css`, desktop corner style, glass surfaces and Penumbra text previews; native and Flatpak installs |
| btop | `~/.config/btop/themes/penumbra.theme`, chosen as `color_theme` in `btop.conf` |
| cava | `~/.config/cava/themes/penumbra`, a four-stop accent gradient chosen unless its config already names a theme; preserves audio/output settings and the terminal background, and reloads colours with `penumbra-theme` |
| bat | `~/.config/bat/themes/Penumbra.tmTheme`, `--theme="Penumbra"` in bat's config unless it names a theme, then `bat cache --build` |
| delta | `~/.config/git/penumbra-delta.gitconfig`, included from your Git configuration, with `penumbra` added to `delta.features` (syntax colours from bat's theme when bat is installed) |
| fzf, ls, eza | `FZF_DEFAULT_OPTS`, `LS_COLORS` and `EZA_COLORS` in Fish's colours file, unless you set them yourself |
| lazygit | `~/.config/lazygit/penumbra.yml`, which Fish adds to `LG_CONFIG_FILE` after your own `config.yml` |
| yazi | the `penumbra` flavor in `~/.config/yazi/flavors/`, chosen in `theme.toml` unless it has a `[flavor]` section |
| zathura | `~/.config/zathura/penumbra-colors`, included from `zathurarc` (Ctrl+R recolours pages in the palette) |
| mpv | `~/.config/mpv/penumbra.conf` (OSD, on-screen controller, uosc), included at the top of `mpv.conf` |
| VS Code, Code - OSS, VSCodium | a Penumbra theme extension installed with `--install-extension`; choose it in Preferences: Color Theme |
| Vesktop | `~/.config/vesktop/themes/penumbra.theme.css`, turned on alongside transparent windows in its settings; restart Vesktop after installing |
| Firefox | The installer imports Penumbra styles into each profile’s `userChrome.css` and `userContent.css` for the toolbars, tabs, menus, home and new-tab pages. It sets Firefox to use the file chooser portal. Restart Firefox to apply the styles. |

`./install.sh --uninstall` puts those files back as they were and removes the editor extension. The animated wallpapers, boot artwork and cursors keep their own colours in their build tools.

Fonts: Inter, with Inter Display for large text (the lock and greeter clocks, panel headlines), and JetBrainsMono Nerd Font for the terminal, code and icons.

When Spicetify is installed, the installer copies the Penumbra theme without replacing your
selected theme. Activate it with the [Spicetify CLI](https://spicetify.app/docs/development/themes):

```bash
spicetify config current_theme Penumbra color_scheme Base inject_css 1 replace_colors 1
spicetify backup apply
```

`penumbra-theme` regenerates installed Spicetify files on palette changes; run `spicetify apply`
to refresh Spotify afterwards. Spotify and Spicetify are optional and are not installed by Penumbra.

## Terminal

Kitty uses 0.8 background opacity with the Penumbra palette and compositor blur. Fish opens with a faceted violet ASCII logo of the distribution (Arch's on Arch), system and hardware panels, and palette dots. The logo works in any terminal; terminals narrower than 95 columns omit it. The compact Starship prompt keeps the clock on the right.

## Cursors

Penumbra Cursors are original artwork drawn for this theme in a soft, rounded style: a sail-shaped arrow, chunky hands and split-arrowhead resize cursors with a moonlit lavender fill, midnight outlines and a light drop shadow. Violet badges mark copy/link/help/menu actions, a rose badge marks forbidden, and the busy cursor is a 24-frame violet arc that stretches as it circles a lavender ring. There are **22 original cursor designs**, **109 standard/legacy cursor names**, and sizes **24, 28, 32, 48, and 64 px**. The desktop (at 28 px), GTK applications, the user-level `share/icons/default/index.theme` fallback for Xcursor clients, and SDDM all select `Penumbra-Cursors`. Apps already open may retain their old cursor until reopened.

- Editable SVGs: `assets/cursors/`.
- Rebuild script: `tools/build-cursors.py`.
- Ready-to-install files: `system/usr/share/icons/Penumbra-Cursors/`.
- Visual catalogue: `previews/cursors.png` and `previews/cursors.svg`.

The installer installs the complete cursor theme with everything else. To rebuild the original vector designs and deploy:

```bash
sudo pacman -S --needed xorg-xcursorgen librsvg
python tools/build-cursors.py
./install.sh
```

The cursor artwork and builder are original to Penumbra. Unlike the Papirus folder overlay, they do not derive from another cursor theme. `breeze-cursors` is only a fallback for rare cursor names outside this set.
