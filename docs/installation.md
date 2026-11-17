# Installer settings and recovery

For package and source installation commands, see the [quick start](../README.md#install). The examples here use `./install.sh` from a source checkout. With the release packages, use `penumbra-install` with the same options.

## Before you install

Penumbra targets MangoWM, Quickshell 0.3, SDDM 0.21, Kitty 0.49, and Fish 4.

Run the installer as your regular desktop user. It selects the distribution using `/etc/os-release`. Use `--distro NAME` to override it. On Arch it uses the current pacman databases and official packages. If the system is substantially out of date, perform a full system upgrade first. Never use `pacman -Sy` alone.

Run `./install.sh --plan` to preview managed file changes and the system and session phases. Add `--user-only` to preview just your account. Each backup contains `completed.txt`, which records finished operations if an install stops partway through.

## Installer settings

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

In a virtual machine, the installer renders the login screen in software at scale 1 (`/etc/sddm.conf.d/91-penumbra-vm.conf`). On real hardware the greeter uses the GPU and follows the screen’s scale.

Log out through **Super+M → Log out → Confirm**, then choose **Mango** on the login screen and sign in again. The running desktop has already been configured; a fresh login applies the environment to every application and displays the new greeter. Existing applications may need reopening to pick up fonts, colors, and icons. Applications that enforce their own theme still use their own appearance setting.

The keyring unlocks with the password you sign in with, so it stays locked (and asks for its password the first time an app needs it) after an automatic login, or after you change your password some way other than `passwd`.

## Personal configuration files

`./install.sh` updates Penumbra’s configuration files when their rendered contents change (keeping the old ones in a backup), so put your own changes in these files, which it creates once and never replaces:

| App | File | Read |
|---|---|---|
| MangoWM | `~/.config/mango/user.conf` | after `config.conf` and the generated settings |
| Kitty | `~/.config/kitty/user.conf` | after `kitty.conf` |
| Neovim | `~/.config/nvim/lua/user.lua` | at the end of `init.lua` |
| Fish | any file in `~/.config/fish/conf.d/` | before `config.fish` (Penumbra only owns `penumbra-colors.fish` there) |

## What the installer changes

1. Installs the packages listed explicitly in `distro/NAME/distro.sh`, with the distribution's package manager.
2. Backs up existing managed system files under `/var/lib/penumbra/backups/TIMESTAMP` and deploys SDDM and the cursors; in a virtual machine, adds the software-rendering greeter setting.
3. Sets the target user's login shell to fish (unless `--shell keep`) and the login screen's keyboard layout to yours. When fprintd is installed, asks whether administrator prompts should accept a fingerprint (default no).
4. Enables NetworkManager and Bluetooth, and enables SDDM without restarting it.
5. Backs up managed user files under `~/.local/state/penumbra/backups/TIMESTAMP` and copies this configuration. Files Penumbra no longer ships are removed from the folders it owns outright (`~/.config/quickshell/penumbra`, `~/.config/nvim/lua/penumbra`, `~/.local/bin/penumbra-*`), so a renamed shell component never lingers; they are in the backup too. Creates the starter files for your own settings if they are missing.
6. Applies GTK dark preference, font, cursor, icon and title-bar button settings through GSettings. Sets up gnome-keyring: makes sure SDDM's PAM file unlocks it at sign-in (Arch's already does; the installer adds the two optional lines if they are missing), routes the Secret portal to it, and tells KWallet (which comes with KDE apps) not to claim the same Secret Service name. Makes the chosen file manager the default app for folders once it is installed, and restarts the desktop portal when its file chooser preference changed.
7. Masks Dunst if installed, avoiding competing notification daemons.
8. Retires the previous Waybar/Mako/swaybg setup: offers to remove those packages and the previous compositor and its helpers (`PENUMBRA_REMOVE_LEGACY=1` or `0` answers in advance; removed versions are listed in the system backup), stops Waybar, Mako and swaybg, and moves `~/.config/waybar` and `~/.config/mako` into the user backup.
9. Enables PipeWire sockets and WirePlumber; reloads MangoWM and restarts the desktop components.

## Backups and rollback

Every installer run creates a new pair of backups, `~/.local/state/penumbra/backups/TIMESTAMP` and `/var/lib/penumbra/backups/TIMESTAMP`. `new-files.txt` records paths that did not exist before that run, `previous-shell.txt` the login shell, and the `gsettings-*.txt` files the GSettings values from before it. `./install.sh --uninstall` undoes all runs (see [Uninstall](#uninstall)). To undo only the latest run by hand, copy its saved files back to their original locations and remove the files listed in its `new-files.txt` after reviewing that list. Do not restart SDDM from a session with unsaved work: that ends the session.

## Uninstall

```bash
./install.sh --uninstall
```

This undoes every install run, newest first, from the backups the runs left: files Penumbra added are removed and files it replaced come back, in your account and in the system (login screen, cursors). It also restores your previous login shell, login-screen keyboard layout, GSettings and Dunst. What is there just before uninstalling is kept in an `uninstall-TIMESTAMP` backup, in case you changed something since. Installed packages stay installed, SDDM stays enabled unless you switch to another display manager, and boot themes have their own undo (see [Boot themes](boot-themes.md#restore-a-boot-backup)). `--uninstall --user-only` only touches your account.
