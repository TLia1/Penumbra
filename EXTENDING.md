# Extending Penumbra

How the bundle is put together, and where to make each kind of change: a new distribution, an installer setting, a shell feature, a colour. For changing your own desktop without touching the bundle, use the files in "Your own settings" in the README instead; `./install.sh` never replaces them.

## The layers

| Layer | Where | Installed to |
|---|---|---|
| Common files, the same everywhere | `config/`, `bin/`, `share/`, `system/` | `~/.config`, `~/.local/bin`, `~/.local/share`, `/` |
| One distribution's differences | `distro/NAME/` | the same places, over the common files |
| Colours | `palette/palette.toml` → `palette/templates/` | rendered into the common files and `apps/` by `tools/build-palette.py`; installed to `~/.local/share/penumbra/palette/`, where `penumbra-theme` renders them again for the chosen theme |
| Other apps' colours | `apps/NAME/` | the same places, only when the command `NAME` exists |
| Per-user values | `@@PLACEHOLDERS@@` in any text file | filled in by `install.sh` as it copies |
| Boot themes | `boot/` | only through `tools/install-boot.py`, after asking |

`install.sh` copies the common folders, then `distro/NAME/config`, `bin`, `share` and `system` on top, so a distribution can add a file or replace a common one with the same path. Keep everything that is the same on every distribution in the common folders; a distribution folder should hold only what really differs.

## Porting to another distribution

`install.sh` reads `ID` then `ID_LIKE` from `/etc/os-release` and uses the first that has a `distro/ID/distro.sh`: EndeavourOS (`ID=endeavouros`, `ID_LIKE=arch`) gets `distro/arch/`. `--distro NAME` overrides it. A new distribution is a new folder:

```
distro/fedora/
├── distro.sh                         # required: packages and package manager
├── share/penumbra/updates.py         # update checks for the bar (optional)
└── config/fastfetch/penumbra-logo.png  # the terminal greeting's logo (optional)
```

### `distro.sh`

`install.sh` sources it, as the user and as root. It must set:

| Name | What |
|---|---|
| `DISTRO_NAME` | Shown in messages, e.g. `'Fedora'`. |
| `DISTRO_GLYPH` | The bar's launcher button: a JetBrainsMono Nerd Font glyph (e.g. `` Fedora, `` Debian, `` Ubuntu, `` openSUSE; Arch's is `󰣇`). |
| `DISTRO_UPDATE_COMMAND` | What fish's `update` abbreviation runs. |
| `PACKAGES` | This distribution's names for everything in `distro/arch/distro.sh`'s list. |
| `pkg_install PKG...` | Install what is missing; ask as usual on a terminal, don't when `interactive` is false. |
| `pkg_installed PKG...` | Print the installed ones, one per line; print nothing for the rest, never fail. |
| `pkg_versions PKG...` | Print `name version` per line (kept in the backup). |
| `pkg_remove PKG...` | Remove them without asking. |

and may set `LEGACY_PACKAGES` (packages an earlier Penumbra replaced, offered for removal; empty by default), `PLYMOUTH_PACKAGES` (default `(plymouth)`) and `SERVICES` (system units enabled besides SDDM; default `(bluetooth NetworkManager)`). `tests/test_install.py` checks every folder sets them all.

A sketch for Fedora, untested, to show the shape:

```bash
DISTRO_NAME='Fedora'
DISTRO_GLYPH=''
DISTRO_UPDATE_COMMAND='sudo dnf upgrade'
PACKAGES=(hyprland quickshell sddm kitty fish ...)

pkg_install() {
    local confirm=()
    interactive || confirm=(-y)
    dnf install "${confirm[@]}" "$@"
}
pkg_installed() { rpm -q --qf '%{NAME}\n' "$@" 2>/dev/null | grep -v ' ' || true; }
pkg_versions() { rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$@"; }
pkg_remove() { dnf remove -y "$@"; }
```

### `share/penumbra/updates.py`

`penumbra-updates` (the bar's update capsule and its Update now button) loads it from `~/.local/share/penumbra/updates.py`. It checks Flatpak itself; the module covers the system packages with three functions:

- `sources()`: a list of checks, `{"name": "Fedora", "command": [...], "empty": (codes,), "empty_if_silent": (codes,)}`. The command prints one pending update per line, without touching the live package database; `empty` lists exit codes that mean nothing to update, `empty_if_silent` the ones that do when nothing is printed.
- `notes()`: extra tooltip lines, e.g. how to enable a source; usually `[]`.
- `upgrades()`: `[(name, command), ...]`, run in order in Kitty, interactively.

Without the module the capsule only counts Flatpak updates. Copy `distro/arch/share/penumbra/updates.py` as a start.

### What else to check

Penumbra's common files assume a few things every mainstream distribution provides; check these on the new one:

- **Packages that may not be packaged**: Hyprland 0.56 with Lua configuration, Quickshell 0.3 and awww are new; some distributions need a third-party repository (Fedora COPR, an Ubuntu PPA) or a build. Say so in the README rather than adding repositories silently.
- **Paths**: fish at `/usr/bin/fish` (`config/kitty/kitty.conf`), Quickshell at `/usr/bin/quickshell` (`config/systemd/user/penumbra-shell.service`), the emoji list at `/usr/share/unicode/emoji/emoji-test.txt` (`Launcher.qml`). If one differs, put a replacement for that file in `distro/NAME/config/`, or turn the path into a placeholder (below).
- **SDDM's PAM file** `/etc/pam.d/sddm`: `install.sh` adds the two gnome-keyring lines when they are missing.
- **Boot themes** (`tools/install-boot.py`): the GRUB theme needs `grub-mkconfig` and `/boot/grub` (Fedora and openSUSE use `grub2-*` and `/boot/grub2`, so it is skipped there); the Plymouth integration rebuilds the initramfs with mkinitcpio and stops safely anywhere else. Supporting dracut or initramfs-tools means a second branch in `apply_plymouth()`, with tests next to the mkinitcpio ones in `tests/test_boot.py`. Until then the themes in `boot/` can be installed by hand.

Then run the tests and an install in a virtual machine of that distribution.

## Adding an installer setting

Settings are what `install.sh` asks before installing and remembers in `~/.config/penumbra/settings.conf`. For a new one, in `install.sh`:

1. Add its key to `SETTING_KEYS`, its option to `SETTING_OPTIONS` and its question to `SETTING_LABELS`.
2. Give it a default in `detect_settings` (`set_default key value`) and a check in `valid_setting`.
3. Use it as `@@KEY@@` (upper case) in any configuration file.

The option parsing, saving and loading, and handing it to the system part follow from the tables. Describe it in `usage` (the `--help` text) and in the README's settings table.

A value that is not a setting (worked out by the installer, or from `distro.sh`) goes in `set_placeholders` instead. `install.sh` warns about a placeholder it doesn't know, and `tests/test_install.py` fails on one.

## Adding to the shell

The shell is `config/quickshell/penumbra/`. `shell.qml` lists the top-level surfaces; `Ui.qml` holds which ones are open; `Theme.qml` holds colours, fonts, sizes and timings. Quickshell reloads edits live; restart it with Super+Shift+R after adding a file. Use `Theme` for every colour, size and radius (`Theme.corner(px)` for radii, so sharp corners keep working).

- **A bar capsule**: add a `Capsule { … }` to the left, centre or right row in `Bar.qml`. Set `shown` rather than `visible` so it fades in and out, `tip` for its tooltip, and handle `onClicked` / `onScrolled`. State that has to be polled belongs in a singleton (like `Sys.qml` or `Usage.qml`) rather than in the bar, since the bar exists once per screen.
- **A panel**: a file like `CalendarPanel.qml`; add an `xOpen` flag and a `toggleX()` to `Ui.qml` (copy `toggleCalendar`), include it in `Ui.close()`, instantiate it in `shell.qml`, and add a function to the `panel` `IpcHandler` there so scripts and keybindings can open it.
- **A control center page**: a page file like `WifiPage.qml`, shown by `ControlCenter.qml` when `Ui.controlPage` is its name; open it with `Ui.openControl("name")`.
- **A settings switch**: add a `property bool` to the `JsonAdapter` in `Settings.qml` (an alias next to the others, and a default), and a `SwitchRow` in `SettingsPage.qml`. It is saved in `~/.config/penumbra/shell.json`.
- **A keybinding**: `config/hypr/hyprland.lua`; call the shell with `quickshell -c penumbra ipc call TARGET FUNCTION`. List them in the README's Controls table.
- **A helper script**: `bin/penumbra-NAME`. It is installed to `~/.local/bin` and removed again when it leaves the bundle. Start programs from QML with `Ui.spawn([...])` so they outlive shell restarts.
- **An optional tool**: detect it the way `Ui.qml` detects hyprsunset and cava, and hide what needs it when it is missing.

## Adding a colour

Add it to `palette/palette.toml` twice: in `[colors]` (dark mode) and in `[light]`, which must have the same keys. Use it as `{{name}}` (or `{{name:hex}}`, `{{name:rgb}}`, `{{name:sgr}}` for terminal codes) in a file under `palette/templates/`, and run `python tools/build-palette.py`. `{{mode}}` is `dark` or `light`, for settings that aren't colours (delta's `dark = true`), and `{{dark.name}}` or `{{light.name}}` take one mode's colour whatever the theme, for a file that holds both (VS Code's two themes). In the shell, expose it in `Theme.qml` as `mix("name")`. A new app's colour file is a new template at the path the file has in the bundle.

The renderer is `share/penumbra/palette.py`, shared by `tools/build-palette.py` (the bundle's files, always dark and default) and `bin/penumbra-theme` (your installed files, in the theme you choose). For a custom accent, `palette.py` turns every key in `HUE_KEYS` to the new hue and scales its chroma, keeping its lightness; signal and diff colours keep theirs. If the new colour is a surface, text or accent shade, add it to `HUE_KEYS`. `penumbra-theme` rewrites only files that are already installed, skips the shell's `palette.js` (the shell reads `~/.local/state/penumbra/palette.json`) and the login screen's, and tells running apps to reload in `reload_apps`; add your app there if it can. `tests/test_theme.py` checks both modes render and that every accent keeps its contrast.

For an app Penumbra doesn't install, put the template under `palette/templates/apps/NAME/config/` (or `share/`), where `NAME` is the app's command; `install.sh` copies `apps/NAME/` only when that command exists (`APP_COMMANDS` maps a folder to other commands, as for VS Code). If the app needs its settings file told about the colours, add a `color_NAME` function next to the others in `install.sh`: use `add_line` and `install_file`, which keep what they change in the backup, and leave a theme the user chose alone. `tests/test_install.py` runs them all against stand-in commands; add your app's checks there.

## Before committing

```bash
python tools/build-palette.py
python tools/build-configuration.py
python -m unittest discover -s tests -v
./install.sh --user-only
```
