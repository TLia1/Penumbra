# Penumbra project review and improvement roadmap

Reviewed on 17 November 2026 at commit `e855dbe`.

I’d make the next Penumbra release about three things: a reversible upgrade, a desktop session tested from login onward, and a Control Center you can operate entirely from the keyboard. Penumbra already has a distinctive visual identity. Its palette reaches from the boot screen into individual apps, and the 15-second display rollback gives people a chance to recover when a monitor setting goes wrong. The biggest gains now are in making that experience dependable across installs, upgrades, and different machines.

All **126 repository tests passed locally**, including the Quickshell tests. I also checked installer and export behavior in temporary directories. This was a source and test review. A fresh boot, physical multi-monitor behavior, and battery consumption remain unverified.

## What I’d fix first

### 1. Make settings exports portable and keep personal data opt-in

A settings export can omit active preferences and include personal clipboard text. I reproduced both behaviors. With a custom `XDG_CONFIG_HOME`, `penumbra-settings get` read the active terminal choice, while `export` produced an empty `files` object. With the default paths, exporting copied pinned clipboard text alongside appearance settings.

Resolve paths consistently across the CLI and shell. Make the default export a portable preferences file, with separate choices for clipboard pins, location, and machine-specific monitor layouts. Show what an import will change before applying it. [Export implementation](bin/penumbra-settings#L236) · [Export UI](config/quickshell/penumbra/SettingsPage.qml#L458)

### 2. Start the installer backup before the first change

The main installer writes `settings.conf` before the system phase and before creating the user backup. A failed system install can therefore leave changed preferences. I also verified that `install_tree` backs up and recopies a byte-identical file on a repeat run.

Record the original settings before the first write. Compare rendered output before copying, add a `--plan` preview, and record which changes completed. A second identical install should produce an empty file-change plan. [Install order](install.sh#L1194) · [Tree copying](install.sh#L333)

### 3. Make sure Super+E opens a file manager after installation

An existing-system install can choose Lia Files when neither it nor Dolphin is installed. It also offers to remove Dolphin as a legacy package, even when Dolphin was the detected choice. The separate ArchISO installer does install Lia Files.

Preserve an explicitly chosen file manager. Before removing one, verify that the replacement desktop entry launches. If neither is available, offer an install choice. Test both installation paths through to opening a folder. [Default selection](install.sh#L230) · [Arch package list](distro/arch/distro.sh#L40) · [File manager shortcut](config/mango/keybinds.conf#L6)

### 4. Distinguish a failed update check from an up-to-date system

An unavailable update check can look like “0 updates.” The helper records failures in its detail text, but failed sources contribute zero to the total and disappear from the source list. The panel uses that total as its headline.

Give each source a status and a last-successful-check time. Show “Couldn’t check Arch” or “2 updates · Flatpak unavailable” directly in the panel. [Update aggregation](bin/penumbra-updates#L58) · [Panel headline](config/quickshell/penumbra/UpdatesPanel.qml#L38)

## Larger projects worth doing

### 1. Test a real desktop session in CI

This is the highest-return infrastructure project. The current Arch CI job installs Qt tooling but omits Quickshell, so tests guarded by `skipUnless(quickshell)` can silently skip. Even locally, the component-load test substitutes a floating window for the Wayland panel. [CI workflow](.github/workflows/ci.yml#L10) · [QML test harness](tests/test_qml_load.py#L1)

First, require the existing Quickshell tests to run in CI. Then add a disposable MangoWM session that opens the launcher, changes a setting, restarts the shell, and checks focus on two outputs. A slower VM release test should cover installation, login, an upgrade with a user override, and uninstall.

### 2. Build keyboard and screen-reader support into the shared controls

Penumbra already offers reduced motion and larger text. Its shared pill button, switch, and list row are drawn as rectangles with mouse handlers, without corresponding keyboard activation or accessible roles in those components. Improving those three controls would benefit many pages at once while preserving their appearance. [Pill button](config/quickshell/penumbra/PillButton.qml#L4) · [Switch](config/quickshell/penumbra/Switch.qml#L4) · [List row](config/quickshell/penumbra/ListRow.qml#L5) · [Qt accessibility API](https://doc.qt.io/qt-6/qml-qtquick-accessible.html)

Use an end-to-end release criterion. A user can open Settings by shortcut, find an option, change it, hear its new state announced, and return to the previous page using only the keyboard.

### 3. Ship Penumbra as a versioned Arch desktop

Penumbra 0.1.0 packages the shell, helpers and stock artwork as `penumbra-desktop`. Application integrations, Neovim configuration and boot artwork are optional packages tied to the same version. ArchISO builds the package set from the selected release and applies it with the same installer used on an existing Arch system.

Existing source installs can move to the packages or keep upgrading directly from a checkout with `./install.sh`. Both paths retain saved preferences and user overrides. To roll back, reinstall the previous package set or select the previous source revision, then reapply it. [Release, migration and rollback guide](docs/releases.md) · [Arch package recipe](packaging/arch/PKGBUILD.in) · [VM upgrade test](tests/arch-release-smoke.sh)

The 0.1.0 archives passed an offline system-and-account upgrade and downgrade in an Arch VM. A synthetic 0.0.9 package set supplied the previous release for this first run. The test preserved display scale, reduced motion, and Mango and Kitty overrides, and restored the previous keybindings and shell file list. A separate source install check upgraded an unversioned checkout to 0.1.0 with its settings intact.

### 4. Bring desktop actions into the launcher

This is the user-facing feature I’d build first. Someone who types “night light,” “switch output,” or “reduce motion” should reach that action immediately and see its current state.

Settings already has a hand-written search index, the launcher has search and ranking, and the shell exposes panel navigation over IPC. A shared list of actions, labels, synonyms, and destinations would make features easier to discover and reduce the number of places a contributor edits when adding one. [Settings search index](config/quickshell/penumbra/SettingsPage.qml#L139) · [Launcher](config/quickshell/penumbra/Launcher.qml#L11) · [Panel IPC](config/quickshell/penumbra/shell.qml#L117)

### 5. Give performance work a reproducible baseline

The shell already lazy-loads several panels, pauses wallpaper animation under defined conditions, and limits expensive hardware reads to the open monitor. Measure login-to-usable time, idle memory, CPU wakeups, and memory after repeatedly opening and closing large panels. [Panel loading](config/quickshell/penumbra/shell.qml#L62) · [Resource sampling](config/quickshell/penumbra/Usage.qml#L67) · [Wallpaper animation](config/quickshell/penumbra/Wallpaper.qml#L122)

Run the same scenarios on one display, two mixed-scale displays, and a laptop on battery. That would show whether the next optimization belongs in wallpaper rendering, a panel, or a background service, and catch regressions as features are added.

## Suggested release order

1. **Next patch.** Fix export and installer behavior, and make Quickshell mandatory in CI alongside those fixes.
2. **Next feature release.** Pair accessible shared controls with launcher actions so users can find and change desktop settings from the keyboard.
3. **Arch release check.** Test each candidate against the previous release in a disposable VM. Verify that the system and account return to the previous release with the user’s overrides intact.
