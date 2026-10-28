#!/usr/bin/env bash
# Penumbra installer. Run it as your regular desktop user: ./install.sh
# Run ./install.sh --help for the options.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
SETTINGS_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/penumbra/settings.conf
XKB_RULES=/usr/share/X11/xkb/rules/base.lst

# Configuration folders of the desktop Penumbra replaced (Waybar and Mako); the packages are in the
# distribution's LEGACY_PACKAGES.
LEGACY_CONFIGS=(waybar mako)

usage() {
    cat <<EOF
Usage: ./install.sh [part] [options]

Parts (default: all of them):
  --user-only          Only copy your configuration; no sudo, no packages.
  --system-only        Only the system part: packages, login screen, services.
                       Needs root; normally started by the full install.
  --boot-only          Only the optional GRUB, Limine and Plymouth themes.
  --uninstall          Undo every Penumbra install: put back the files each run
                       replaced and remove the ones it added. Packages stay.
                       With --user-only, only your account's files.

Distribution (detected from /etc/os-release; supported: $(supported_distros)):
  --distro NAME        Use distro/NAME/ instead of the detected one.

Settings (detected on the first run, then remembered in $SETTINGS_FILE):
  --layout LAYOUT      Keyboard layout, e.g. us, gb, fr, de, or "us,fr" for several.
  --variant VARIANT    Layout variant, e.g. intl, dvorak, colemak. Empty for none.
  --kb-options OPTS    XKB options, e.g. caps:escape,grp:alt_shift_toggle.
  --scale SCALE        Display scale: auto, 1, 1.25, 1.5, 2...
  --numlock on|off     Turn Num Lock on when you log in.
  --shell fish|keep    Make fish your login shell, or keep the current one.
  --terminal APP       Terminal for Super+Enter, by its desktop file: kitty, foot...
  --file-manager APP   File manager for Super+E, by its desktop file: org.kde.dolphin...
  --idle-dim MIN       Minutes idle before the screen dims, or never.
  --idle-lock MIN      Minutes idle before the screen locks, or never.
  --idle-screen-off MIN
                       Minutes idle before the screens turn off, or never.
  --idle-suspend MIN   Minutes idle before suspending on battery, or never.
The shell's Settings pages (Super+,) change all but the login shell, at once.

Other options:
  -y, --yes            Don't ask about the settings; use the saved or detected ones.
  --skip-packages      Don't install packages (or PENUMBRA_SKIP_PACKAGES=1).
  --remove-legacy yes|no|ask
                       Whether to remove the packages Penumbra replaced (Waybar,
                       Mako, swaybg) if they are installed (or
                       PENUMBRA_REMOVE_LEGACY=1/0). Default: ask.
  --user NAME          Desktop user for --system-only (default: \$SUDO_USER).
  -h, --help           Show this help.
EOF
}

# ─── Output and questions ────────────────────────────────────────────────────

step() { printf '\n\033[1;35m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

interactive() { [[ -t 0 ]]; }

# ask "Question?" → true on yes. Defaults to no, and to no without a terminal.
ask() {
    if ! interactive; then
        printf '%s [y/N] skipped (noninteractive)\n' "$1"
        return 1
    fi
    local answer
    read -r -p "$1 [y/N] " answer
    [[ ${answer,,} == y || ${answer,,} == yes ]]
}

# ─── Distribution ────────────────────────────────────────────────────────────
# Everything that differs between distributions (package names, the package manager, the logo,
# update checks) lives in distro/NAME/. distro.sh is sourced here; its config/, bin/, share/ and
# system/ folders are installed over the common ones. See EXTENDING.md.

supported_distros() {
    local dir names=()
    for dir in "$ROOT"/distro/*/distro.sh; do names+=("$(basename "$(dirname "$dir")")"); done
    local IFS=,
    echo "${names[*]}"
}

# Pick DISTRO: --distro, else the first of /etc/os-release's ID and ID_LIKE (e.g. "endeavouros"
# then "arch") that has a folder.
detect_distro() {
    local id
    if [[ -z $DISTRO ]]; then
        for id in $( . /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}"); do
            [[ -r $ROOT/distro/$id/distro.sh ]] && { DISTRO=$id; break; }
        done
        [[ -n $DISTRO ]] || die "Penumbra has no support for this distribution yet (supported: $(supported_distros)). See EXTENDING.md."
    fi
    [[ $DISTRO =~ ^[a-z0-9_-]+$ && -r $ROOT/distro/$DISTRO/distro.sh ]] \
        || die "No distro/$DISTRO/distro.sh (supported: $(supported_distros))."
}

load_distro() {
    detect_distro
    DISTRO_DIR=$ROOT/distro/$DISTRO
    LEGACY_PACKAGES=() PLYMOUTH_PACKAGES=(plymouth)
    # shellcheck source=distro/arch/distro.sh
    source "$DISTRO_DIR/distro.sh"
    local name
    for name in pkg_install pkg_installed pkg_versions pkg_remove; do
        declare -F "$name" >/dev/null || die "distro/$DISTRO/distro.sh does not define $name."
    done
    for name in DISTRO_NAME DISTRO_GLYPH DISTRO_UPDATE_COMMAND PACKAGES; do
        [[ -v $name ]] || die "distro/$DISTRO/distro.sh does not set $name."
    done
}

# ─── Settings ────────────────────────────────────────────────────────────────
# Each setting comes from, in order: a command-line option, the saved settings
# file, then what this machine already uses. Templates get each one as @@KEY@@ (kb_layout →
# @@KB_LAYOUT@@). A new setting needs a line in SETTING_KEYS, SETTING_OPTIONS and SETTING_LABELS,
# a default in detect_settings and a check in valid_setting, and the same in bin/penumbra-settings,
# which the shell's Settings pages use to change them later.

declare -A settings=()
SETTING_KEYS=(kb_layout kb_variant kb_options scale numlock shell terminal file_manager idle_dim idle_lock idle_screen_off idle_suspend)
declare -A SETTING_OPTIONS=(
    [kb_layout]=--layout
    [kb_variant]=--variant
    [kb_options]=--kb-options
    [scale]=--scale
    [numlock]=--numlock
    [shell]=--shell
    [terminal]=--terminal
    [file_manager]=--file-manager
    [idle_dim]=--idle-dim
    [idle_lock]=--idle-lock
    [idle_screen_off]=--idle-screen-off
    [idle_suspend]=--idle-suspend
)
declare -A SETTING_LABELS=(
    [kb_layout]='Keyboard layout'
    [kb_variant]='Layout variant'
    [kb_options]='Keyboard options'
    [scale]='Display scale'
    [numlock]='Num Lock at login (on/off)'
    [shell]='Login shell (fish/keep)'
    [terminal]='Terminal (desktop file)'
    [file_manager]='File manager (desktop file)'
    [idle_dim]='Dim after (minutes/never)'
    [idle_lock]='Lock after (minutes/never)'
    [idle_screen_off]='Screens off after (min/never)'
    [idle_suspend]='Suspend on battery after (min)'
)

# option_setting --layout → kb_layout; false for any other option.
option_setting() {
    local key
    for key in "${SETTING_KEYS[@]}"; do
        [[ $1 == "${SETTING_OPTIONS[$key]}" ]] && { echo "$key"; return 0; }
    done
    return 1
}

# Set a setting unless something with higher priority already did.
set_default() { [[ -v settings[$1] ]] || settings[$1]=$2; }

load_saved_settings() {
    [[ -r $SETTINGS_FILE ]] || return 0
    local key value
    while IFS='=' read -r key value; do
        if [[ $key =~ ^[a-z_]+$ && -v SETTING_LABELS[$key] ]]; then set_default "$key" "$value"; fi
    done < "$SETTINGS_FILE"
}

save_settings() {
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    {
        echo "# Penumbra settings, written by install.sh and the shell's Settings pages."
        echo '# Edit them, then run ./install.sh --user-only (or penumbra-settings apply) to apply.'
        local key
        for key in "${SETTING_KEYS[@]}"; do printf '%s=%s\n' "$key" "${settings[$key]}"; done
    } > "$SETTINGS_FILE"
}

# localectl_field "X11 Layout" → that line's value from `localectl status`.
localectl_field() {
    command -v localectl >/dev/null || return 0
    localectl status 2>/dev/null | sed -n "s/^ *$1: //p"
}

known_layout() {
    [[ -r $XKB_RULES ]] || return 0  # Can't check; trust the user.
    awk -v want="$1" '/^!/ { section = $2 } section == "layout" && $1 == want { found = 1 } END { exit !found }' "$XKB_RULES"
}

# Default to the keyboard this machine already uses.
detect_settings() {
    local layout variant='' options='' keymap
    layout=$(localectl_field 'X11 Layout')
    if [[ -n $layout ]]; then
        variant=$(localectl_field 'X11 Variant')
        options=$(localectl_field 'X11 Options')
    else
        # No X11 layout configured: derive one from the console keymap, e.g. "de-latin1" → "de".
        keymap=$(localectl_field 'VC Keymap')
        keymap=${keymap%%-*}
        case $keymap in uk) keymap=gb ;; sv) keymap=se ;; esac
        [[ $keymap =~ ^[a-z]+$ ]] && known_layout "$keymap" && layout=$keymap
    fi
    set_default kb_layout "${layout:-us}"
    set_default kb_variant "$variant"
    set_default kb_options "$options"
    set_default scale auto
    set_default numlock on
    set_default shell fish
    set_default terminal kitty
    set_default file_manager org.kde.dolphin
    set_default idle_dim 9.5
    set_default idle_lock 10
    set_default idle_screen_off 11
    set_default idle_suspend 30
}

# valid_setting KEY VALUE → true if VALUE is acceptable, otherwise explains why.
valid_setting() {
    local key=$1 value=$2 layout
    case $key in
        kb_layout)
            [[ $value =~ ^[a-z0-9_]+(,[a-z0-9_]+)*$ ]] || { warn "Layout should look like 'us' or 'us,fr'."; return 1; }
            for layout in ${value//,/ }; do
                known_layout "$layout" || { warn "Unknown keyboard layout '$layout' (see $XKB_RULES)."; return 1; }
            done ;;
        kb_variant) [[ $value =~ ^[A-Za-z0-9_,-]*$ ]] || { warn "Invalid layout variant '$value'."; return 1; } ;;
        kb_options) [[ $value =~ ^[A-Za-z0-9_,:+-]*$ ]] || { warn "Invalid keyboard options '$value'."; return 1; } ;;
        scale) [[ $value =~ ^(auto|[0-9]+(\.[0-9]+)?)$ ]] || { warn "Scale should be 'auto' or a number such as 1.25."; return 1; } ;;
        numlock) [[ $value == on || $value == off ]] || { warn "Num Lock should be 'on' or 'off'."; return 1; } ;;
        shell) [[ $value == fish || $value == keep ]] || { warn "Login shell should be 'fish' or 'keep'."; return 1; } ;;
        terminal|file_manager) [[ $value =~ ^[A-Za-z0-9._-]+$ ]] || { warn "Apps are named by their desktop file, such as kitty or org.kde.dolphin."; return 1; } ;;
        idle_*) [[ $value == never || ( $value =~ ^[0-9]+(\.[0-9]+)?$ && ! $value =~ ^0+(\.0+)?$ ) ]] \
            || { warn 'Idle timings are minutes, such as 10 or 2.5, or never.'; return 1; } ;;
    esac
}

show_settings() {
    local key
    for key in "${SETTING_KEYS[@]}"; do
        printf '  %-28s %s\n' "${SETTING_LABELS[$key]}" "${settings[$key]:-(none)}"
    done
}

# Show the settings and let the user change them before anything is installed.
confirm_settings() {
    local key value
    step 'Settings'
    show_settings
    interactive && [[ ${ASSUME_YES:-0} != 1 ]] || return 0
    ask 'Change any of these?' || return 0
    echo "Press Enter to keep a value, or type '-' to clear it."
    for key in "${SETTING_KEYS[@]}"; do
        while true; do
            read -r -p "  ${SETTING_LABELS[$key]} [${settings[$key]}]: " value
            case $value in
                '') value=${settings[$key]} ;;
                -) value='' ;;
            esac
            valid_setting "$key" "$value" && break
        done
        settings[$key]=$value
    done
}

# Virtual machines get software cursors and a software-rendered login screen; their virtual GPUs
# often draw hardware cursors and accelerated QML wrongly.
is_vm() { systemd-detect-virt --vm --quiet 2>/dev/null; }

# ─── Backups and copying ─────────────────────────────────────────────────────
# Every run keeps the files it replaces under $BACKUP, and lists the files it
# creates in $BACKUP/new-files.txt.

# backup_file PATH NAME: keep PATH as $BACKUP/NAME, or record it as new.
backup_file() {
    local path=$1 name=$2
    if [[ -e $path || -L $path ]]; then
        mkdir -p "$BACKUP/$(dirname "$name")"
        cp -a "$path" "$BACKUP/$name"
    else
        printf '%s\n' "$path" >> "$BACKUP/new-files.txt"
    fi
}

# The values templates can use besides the settings, as PLACEHOLDER=value.
declare -A placeholders=()
set_placeholders() {
    placeholders=(
        [HOME]=$HOME
        [DISTRO_GLYPH]=$DISTRO_GLYPH
        [DISTRO_UPDATE_COMMAND]=$DISTRO_UPDATE_COMMAND
        # Hyprland's no_hardware_cursors: 1 forces software cursors, 2 decides per GPU.
        [SOFTWARE_CURSOR]=$(is_vm && echo 1 || echo 2)
    )
    local key
    for key in "${SETTING_KEYS[@]}"; do placeholders[${key^^}]=${settings[$key]:-}; done
}

# Print a file with its @@PLACEHOLDERS@@ replaced by this user's values.
render_template() {
    local text name
    text=$(<"$1")
    for name in "${!placeholders[@]}"; do text=${text//@@$name@@/"${placeholders[$name]}"}; done
    [[ $text =~ @@[A-Z_]+@@ ]] && warn "${1#"$ROOT/"}: unknown placeholder ${BASH_REMATCH[0]}"
    printf '%s\n' "$text"
}

# install_tree FROM TO: copy every file under FROM into TO, filling in templates.
install_tree() {
    local from=$1 to=$2 source dest
    while IFS= read -r -d '' source; do
        dest=$to/${source#"$from/"}
        backup_file "$dest" "${dest#"$HOME/"}"
        mkdir -p "$(dirname "$dest")"
        if grep -Iq '@@[A-Z_]*@@' "$source"; then
            render_template "$source" > "$dest"
        else
            cp "$source" "$dest"
        fi
    done < <(find "$from" -type f -print0)
}

# prune_tree FROM TO: remove files under TO that FROM no longer has, keeping them in the backup.
# Only for folders Penumbra owns outright: Quickshell loads every .qml it finds, so a renamed or
# deleted component would otherwise linger.
prune_tree() {
    local from=$1 to=$2 dest
    [[ -d $to ]] || return 0
    while IFS= read -r -d '' dest; do
        [[ -e $from/${dest#"$to/"} ]] && continue
        backup_file "$dest" "${dest#"$HOME/"}"
        rm -f "$dest"
        echo "Removed ${dest/#"$HOME"/\~}; Penumbra no longer uses it."
    done < <(find "$to" \( -type f -o -type l \) -print0)
}

# Starter files for your own settings, created once and never replaced: Hyprland, Kitty and
# Neovim read them after Penumbra's configuration.
create_user_files() {
    local path
    declare -A starters=(
        [$HOME/.config/hypr/user.lua]='-- Your own Hyprland settings, read after Penumbra'"'"'s hyprland.lua. ./install.sh never replaces this file.
-- hl.config({ general = { gaps_out = 8 } })
-- hl.bind("SUPER + T", hl.dsp.exec_cmd("thunar"))'
        [$HOME/.config/kitty/user.conf]='# Your own Kitty settings, read after Penumbra'"'"'s kitty.conf. ./install.sh never replaces this file.
# font_size 12.0'
        [$HOME/.config/nvim/lua/user.lua]='-- Your own Neovim settings, run after Penumbra'"'"'s init.lua. ./install.sh never replaces this file.
-- vim.opt.relativenumber = false'
    )
    for path in "${!starters[@]}"; do
        [[ -e $path ]] && continue
        backup_file "$path" "${path#"$HOME/"}"
        mkdir -p "$(dirname "$path")"
        printf '%s\n' "${starters[$path]}" > "$path"
    done
}
# ─── System part (root) ──────────────────────────────────────────────────────

install_packages() {
    if [[ $SKIP_PACKAGES == 1 ]]; then
        echo 'Skipping packages.'
        return
    fi
    pkg_install "${PACKAGES[@]}"
}

remove_legacy_packages() {
    local installed
    (( ${#LEGACY_PACKAGES[@]} )) || return 0
    mapfile -t installed < <(pkg_installed "${LEGACY_PACKAGES[@]}")
    (( ${#installed[@]} )) || return 0
    case $REMOVE_LEGACY in
        yes) ;;
        ask) ask "Remove packages Penumbra no longer uses (${installed[*]})?" || return 0 ;;
        *) return 0 ;;
    esac
    pkg_versions "${installed[@]}" > "$BACKUP/removed-packages.txt"
    pkg_remove "${installed[@]}" \
        || warn "Could not remove ${installed[*]}; another package may still depend on them."
}

# The common system/ files, then the distribution's, which can replace them.
install_system_files() {
    local source rel from
    for from in "$ROOT/system" "$DISTRO_DIR/system"; do
        [[ -d $from ]] || continue
        while IFS= read -r -d '' source; do
            rel=${source#"$from/"}
            backup_file "/$rel" "$rel"
            install -Dm644 "$source" "/$rel"
        done < <(find "$from" -type f -print0)
    done
    configure_vm_greeter
}

# In a virtual machine the login screen renders in software at scale 1; elsewhere it uses the GPU
# and the screen's own scale.
configure_vm_greeter() {
    local conf=/etc/sddm.conf.d/91-penumbra-vm.conf
    if is_vm; then
        backup_file "$conf" "${conf#/}"
        printf '%s\n' '# Written by the Penumbra installer because this is a virtual machine.' '[General]' \
            'GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1,QT_QUICK_CONTROLS_STYLE=Basic,QT_QUICK_BACKEND=software' > "$conf"
    elif [[ -e $conf ]]; then
        backup_file "$conf" "${conf#/}"
        rm -f "$conf"
    fi
}

set_login_shell() {
    local user=$1 fish
    [[ ${settings[shell]:-fish} == fish ]] || return 0
    fish=$(command -v fish) || { warn 'fish is not installed; the login shell stays as it is.'; return 0; }
    getent passwd "$user" | cut -d: -f7 > "$BACKUP/previous-shell.txt"
    usermod -s "$fish" "$user"
}

# Give the login screen the same keyboard layout as the desktop.
set_login_keyboard() {
    [[ -v settings[kb_layout] ]] && command -v localectl >/dev/null || return 0
    local layout=${settings[kb_layout]} variant=${settings[kb_variant]:-} options=${settings[kb_options]:-}
    if [[ $(localectl_field 'X11 Layout') == "$layout" && $(localectl_field 'X11 Variant') == "$variant" ]]; then
        return 0
    fi
    localectl status > "$BACKUP/localectl-status.txt" 2>&1 || true
    # --no-convert leaves the text console keymap alone.
    if localectl --no-convert set-x11-keymap "$layout" "$(localectl_field 'X11 Model')" "$variant" "$options"; then
        echo "Login screen keyboard layout set to $layout${variant:+ ($variant)}."
    else
        warn 'Could not set the login screen keyboard layout.'
    fi
}

# The keyring unlocks with your password when you sign in through SDDM. Arch's SDDM PAM file
# already lists gnome-keyring (as optional, skipped while it isn't installed); other, older or
# edited files get the two lines added.
enable_keyring_unlock() {
    local pam=/etc/pam.d/sddm
    [[ -f $pam ]] || return 0
    grep -Eq '^-?auth[[:space:]].*pam_gnome_keyring\.so' "$pam" \
        && grep -Eq '^-?session[[:space:]].*pam_gnome_keyring\.so' "$pam" && return 0
    backup_file "$pam" "${pam#/}"
    grep -Eq '^-?auth[[:space:]].*pam_gnome_keyring\.so' "$pam" \
        || printf '%s\n' '-auth       optional    pam_gnome_keyring.so' >> "$pam"
    grep -Eq '^-?session[[:space:]].*pam_gnome_keyring\.so' "$pam" \
        || printf '%s\n' '-session    optional    pam_gnome_keyring.so    auto_start' >> "$pam"
    echo "Added gnome-keyring to $pam, so the keyring unlocks when you sign in."
}

# Administrator prompts take a fingerprint once fprintd is installed: pam_fprintd goes first in
# polkit's PAM stack, for one scan or ten seconds, then the password as before. It steps aside at
# once when no finger is enrolled, and "-" skips it if fprintd is removed. The lock screen has a
# stack of its own in the shell (config/quickshell/penumbra/pam/fingerprint).
enable_fingerprint_polkit() {
    local pam=/etc/pam.d/polkit-1 vendor=/usr/lib/pam.d/polkit-1 from
    command -v fprintd-list >/dev/null || return 0
    if [[ -f $pam ]]; then from=$pam; elif [[ -f $vendor ]]; then from=$vendor; else return 0; fi
    grep -Eq '^-?auth[[:space:]].*pam_fprintd\.so' "$from" && return 0
    backup_file "$pam" "${pam#/}"
    awk '!done && /^-?auth[[:space:]]/ { print "-auth      sufficient   pam_fprintd.so max-tries=1 timeout=10"; done = 1 } { print }' \
        "$from" > "$pam.penumbra" && mv "$pam.penumbra" "$pam"
    chmod 644 "$pam"
    echo "Added fingerprint sign-in to $pam, for administrator prompts."
}

enable_services() {
    local unit units=()
    for unit in "${SERVICES[@]}" sddm; do
        systemctl is-enabled "$unit" > "$BACKUP/$unit.enabled" 2>&1 || true
    done
    # Only units that are installed: --skip-packages may have left one out.
    for unit in "${SERVICES[@]}"; do
        if systemctl cat "$unit.service" >/dev/null 2>&1; then units+=("$unit"); else warn "$unit is not installed; not enabling it."; fi
    done
    (( ${#units[@]} == 0 )) || systemctl enable --now "${units[@]}"
    # Not started now: that would end the current session.
    systemctl enable sddm
}

run_system_part() {
    [[ $EUID == 0 ]] || die 'The system part needs root: sudo ./install.sh --system-only'
    local user=${TARGET_USER:-${SUDO_USER:-}}
    [[ -n $user && $user != root ]] || die 'Name the desktop user with --user NAME.'
    BACKUP=/var/lib/penumbra/backups/$STAMP
    mkdir -p "$BACKUP"

    step 'Installing packages'
    install_packages
    remove_legacy_packages

    step 'Installing the login screen, cursors and system files'
    install_system_files
    set_login_keyboard
    set_login_shell "$user"
    enable_keyring_unlock
    enable_fingerprint_polkit
    enable_services

    step 'Boot themes (optional)'
    run_boot_part || warn 'Optional boot theming did not complete; see the messages above.'

    echo "System backup: $BACKUP"
}

# Boot assets are deliberately outside system/: deploy only after opt-in. The package comes from
# the distribution; tools/install-boot.py does the rest.
run_boot_part() {
    if ! command -v plymouth-set-default-theme >/dev/null \
        && ask "Install Plymouth (${PLYMOUTH_PACKAGES[*]}) for the boot splash?"; then
        pkg_install "${PLYMOUTH_PACKAGES[@]}" || warn 'Plymouth was not installed.'
    fi
    python3 "$ROOT/tools/install-boot.py"
}

# ─── User part ───────────────────────────────────────────────────────────────

install_wallpapers() {
    local dir=$HOME/.local/share/penumbra wallpaper
    mkdir -p "$dir"
    for wallpaper in "$ROOT"/assets/wallpaper*.png; do
        backup_file "$dir/${wallpaper##*/}" ".local/share/penumbra/${wallpaper##*/}"
        cp "$wallpaper" "$dir/"
    done
    # The lock screen follows the chosen wallpaper; penumbra-wallpaper repoints this link.
    [[ -e $dir/lock.png ]] || ln -sfn "$dir/wallpaper-clean.png" "$dir/lock.png"
}

# Stop the previous bar, notification daemon and wallpaper setter, and move their configs into the backup.
retire_legacy_desktop() {
    local name
    for name in "${LEGACY_PACKAGES[@]}"; do pkill -u "$UID" -x "$name" 2>/dev/null || true; done
    for name in "${LEGACY_CONFIGS[@]}"; do
        [[ -e $HOME/.config/$name ]] || continue
        mkdir -p "$BACKUP/.config"
        mv "$HOME/.config/$name" "$BACKUP/.config/$name"
        echo "Moved ~/.config/$name to the backup; it is no longer used."
    done
}

apply_gtk_settings() {
    command -v gsettings >/dev/null || return 0
    gsettings list-recursively org.gnome.desktop.interface > "$BACKUP/gsettings-interface.txt"
    gsettings list-recursively org.gnome.desktop.wm.preferences > "$BACKUP/gsettings-wm.txt"
    # color-scheme and gtk-theme follow the theme's mode; penumbra-theme sets them.
    gsettings set org.gnome.desktop.interface icon-theme Penumbra
    gsettings set org.gnome.desktop.interface cursor-theme Penumbra-Cursors
    gsettings set org.gnome.desktop.interface cursor-size 28
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
    # Only a close button on title bars: Hyprland tiles, so minimize and maximize do nothing.
    gsettings set org.gnome.desktop.wm.preferences button-layout ':close'
}

# gnome-keyring keeps the passwords apps save (Secret Service). KWallet comes with Dolphin and can
# claim the same D-Bus name, so it is told not to; Dolphin's own KWallet use is unchanged.
configure_keyring() {
    local rc=$HOME/.config/kwalletrc
    if command -v kwriteconfig6 >/dev/null; then
        backup_file "$rc" .config/kwalletrc
        kwriteconfig6 --file "$rc" --group org.freedesktop.secrets --key apiEnabled false
    fi
    systemctl --user enable gnome-keyring-daemon.socket 2>/dev/null || true
}

# The Penumbra shell is the notification daemon; mask Dunst so it can't compete.
disable_dunst() {
    systemctl --user cat dunst.service >/dev/null 2>&1 || return 0
    systemctl --user is-enabled dunst.service > "$BACKUP/dunst.enabled" 2>&1 || true
    backup_file "$HOME/.config/systemd/user/dunst.service" .config/systemd/user/dunst.service
    systemctl --user mask --now dunst.service
    systemctl --user daemon-reload
}

# ─── Colours for other apps ──────────────────────────────────────────────────
# apps/NAME/ holds Penumbra's colours for an app Penumbra doesn't install. It is used only when one
# of the app's commands exists (NAME, unless APP_COMMANDS lists others): its config/ is copied to
# ~/.config and its share/ to ~/.local/share, then color_NAME, if there is one, turns the colours on.
# Your own settings files are only added to, and kept in the backup like everything else.
declare -A APP_COMMANDS=([vscode]='code codium')

install_app_colors() {
    local dir app command found
    for dir in "$ROOT"/apps/*/; do
        dir=${dir%/} app=${dir##*/} found=
        for command in ${APP_COMMANDS[$app]:-$app}; do
            command -v "$command" >/dev/null && found=1
        done
        [[ -n $found ]] || continue
        [[ ! -d $dir/config ]] || install_tree "$dir/config" "$HOME/.config"
        [[ ! -d $dir/share ]] || install_tree "$dir/share" "$HOME/.local/share"
        if declare -F "color_$app" >/dev/null; then "color_$app" "$dir"; fi
        echo "Penumbra colours for $app."
    done
}

# install_file FROM TO: copy one file, keeping what it replaces.
install_file() {
    backup_file "$2" "${2#"$HOME/"}"
    mkdir -p "$(dirname "$2")"
    cp "$1" "$2"
}

# add_line FILE LINE [top]: add LINE at the end of FILE, or at the top, unless FILE already has it.
# FILE is created if missing, and written in place so a symbolic link stays one.
add_line() {
    local file=$1 line=$2 text=''
    [[ -f $file ]] && grep -qxF -- "$line" "$file" && return 0
    backup_file "$file" "${file#"$HOME/"}"
    mkdir -p "$(dirname "$file")"
    [[ -f $file ]] && text=$(<"$file")
    if [[ ${3:-} == top ]]; then
        printf '%s\n%s' "$line" "${text:+$text$'\n'}" > "$file"
    else
        printf '%s%s\n' "${text:+$text$'\n'}" "$line" > "$file"
    fi
}

# btop: choose the theme in btop.conf (btop fills in the rest of a new file).
color_btop() {
    local conf=$HOME/.config/btop/btop.conf
    if [[ -f $conf ]] && grep -q '^color_theme *=' "$conf"; then
        grep -qx 'color_theme = "penumbra"' "$conf" && return 0
        backup_file "$conf" .config/btop/btop.conf
        sed --follow-symlinks -i 's/^color_theme *=.*/color_theme = "penumbra"/' "$conf"
    else
        add_line "$conf" 'color_theme = "penumbra"'
    fi
}

# bat: use the theme unless your bat config already picks one, and rebuild bat's theme cache, which
# delta reads too.
color_bat() {
    local conf
    conf=$(bat --config-file)
    [[ -f $conf ]] && grep -q '^--theme[= ]' "$conf" || add_line "$conf" '--theme="Penumbra"'
    bat cache --build >/dev/null
}

# delta: include the "penumbra" feature from your Git configuration and add it to delta.features,
# after the features you already use.
color_delta() {
    local conf=$HOME/.gitconfig features
    # shellcheck disable=SC2088  # Git expands the ~ itself.
    local include='~/.config/git/penumbra-delta.gitconfig'
    [[ -e $conf || ! -e $HOME/.config/git/config ]] || conf=$HOME/.config/git/config
    # Syntax highlighting in the Penumbra colours comes from bat's theme cache.
    if command -v bat >/dev/null; then
        git config --file "$HOME/.config/git/penumbra-delta.gitconfig" delta.penumbra.syntax-theme Penumbra
    fi
    features=$(git config --file "$conf" delta.features || true)
    if git config --file "$conf" --get-all include.path 2>/dev/null | grep -qxF "$include" \
        && [[ " $features " == *' penumbra '* ]]; then
        return 0
    fi
    backup_file "$conf" "${conf#"$HOME/"}"
    git config --file "$conf" --get-all include.path 2>/dev/null | grep -qxF "$include" \
        || git config --file "$conf" --add include.path "$include"
    [[ " $features " == *' penumbra '* ]] || git config --file "$conf" delta.features "${features:+$features }penumbra"
}

# yazi: the flavor's code previews use bat's theme; choose the flavor unless theme.toml has one.
color_yazi() {
    local theme=$HOME/.config/yazi/theme.toml
    install_file "$ROOT/apps/bat/config/bat/themes/Penumbra.tmTheme" \
        "$HOME/.config/yazi/flavors/penumbra.yazi/tmtheme.xml"
    if [[ -f $theme ]] && grep -q '^\[flavor\]' "$theme"; then
        grep -q '"penumbra"' "$theme" || echo 'yazi: your theme.toml chooses its own flavor; set dark = "penumbra" and light = "penumbra" there to use Penumbra.'
        return 0
    fi
    # The same flavor both ways: penumbra-theme rewrites it for dark or light mode.
    add_line "$theme" $'[flavor]\ndark = "penumbra"\nlight = "penumbra"'
}

color_zathura() { add_line "$HOME/.config/zathura/zathurarc" 'include penumbra-colors'; }

# mpv: at the top of mpv.conf, so it isn't read as part of a [profile].
color_mpv() { add_line "$HOME/.config/mpv/mpv.conf" 'include="~~/penumbra.conf"' top; }

# VS Code, Code - OSS and VSCodium: package the theme as an extension and install it with the editor's
# own command (a copied folder is ignored once the editor keeps a list of its extensions).
color_vscode() {
    local vsix=$BACKUP/penumbra-theme.vsix command
    (cd "$1/vsix" && python3 -m zipfile -c "$vsix" extension.vsixmanifest '[Content_Types].xml' extension)
    for command in ${APP_COMMANDS[vscode]}; do
        command -v "$command" >/dev/null || continue
        "$command" --install-extension "$vsix" --force >/dev/null 2>&1 \
            || warn "$command could not install the Penumbra theme ($vsix)."
    done
    echo 'VS Code: choose Penumbra or Penumbra Light in Preferences: Color Theme. To follow the theme'"'"'s mode, turn on'
    echo '"window.autoDetectColorScheme" with Penumbra and Penumbra Light as the preferred dark and light themes.'
}

# Vesktop: turn the theme on in its settings, which it writes on first start. A running Vesktop
# keeps its own copy, so this shows after a restart.
color_vesktop() {
    local settings=$HOME/.config/vesktop/settings/settings.json
    [[ -f $settings ]] || return 0
    python3 -c 'import json, sys; sys.exit("penumbra.theme.css" in json.load(open(sys.argv[1])).get("enabledThemes", []))' \
        "$settings" || return 0
    backup_file "$settings" .config/vesktop/settings/settings.json
    python3 - "$settings" <<'EOF'
import json, sys
with open(sys.argv[1]) as file:
    settings = json.load(file)
settings.setdefault('enabledThemes', []).append('penumbra.theme.css')
with open(sys.argv[1], 'w') as file:
    json.dump(settings, file, indent=4)
EOF
}

# Firefox: every profile imports the colours from its chrome/userChrome.css, which Firefox reads
# once user.js allows it (on its next start).
color_firefox() {
    local root profile
    for root in "$HOME/.mozilla/firefox" "$HOME/.config/mozilla/firefox"; do
        [[ -r $root/profiles.ini ]] || continue
        while IFS= read -r profile; do
            [[ $profile == /* ]] || profile=$root/$profile
            [[ -d $profile ]] || continue
            install_file "$1/chrome/penumbra.css" "$profile/chrome/penumbra.css"
            add_line "$profile/chrome/userChrome.css" '@import "penumbra.css";' top
            add_line "$profile/user.js" 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
        done < <(sed -n 's/^Path=//p' "$root/profiles.ini")
    done
}

run_user_part() {
    BACKUP=$HOME/.local/state/penumbra/backups/$STAMP
    mkdir -p "$BACKUP"

    step 'Installing your configuration'
    prune_tree "$ROOT/config/quickshell/penumbra" "$HOME/.config/quickshell/penumbra"
    prune_tree "$ROOT/config/nvim/lua/penumbra" "$HOME/.config/nvim/lua/penumbra"
    prune_tree "$ROOT/palette/templates" "$HOME/.local/share/penumbra/palette/templates"
    local script from
    for script in "$HOME"/.local/bin/penumbra-*; do
        [[ -e $script && ! -e $ROOT/bin/${script##*/} && ! -e $DISTRO_DIR/bin/${script##*/} ]] || continue
        backup_file "$script" "${script#"$HOME/"}"
        rm -f "$script"
        echo "Removed ~/.local/bin/${script##*/}; Penumbra no longer uses it."
    done
    set_placeholders
    # The common files, then the distribution's, which can add to or replace them.
    for from in "$ROOT" "$DISTRO_DIR"; do
        [[ ! -d $from/config ]] || install_tree "$from/config" "$HOME/.config"
        [[ ! -d $from/bin ]] || install_tree "$from/bin" "$HOME/.local/bin"
        [[ ! -d $from/share ]] || install_tree "$from/share" "$HOME/.local/share"
    done
    # The palette and colour templates, which penumbra-theme renders when you change the theme.
    install_tree "$ROOT/palette" "$HOME/.local/share/penumbra/palette"
    create_user_files
    chmod +x "$HOME"/.local/bin/penumbra-*
    # Dolphin only reads service menus in your account that are executable.
    chmod +x "$HOME/.local/share/kio/servicemenus/penumbra-wallpaper.desktop"
    # The configs above come rounded; put back sharp corners if that was the choice.
    "$HOME/.local/bin/penumbra-corners" restore
    # hypridle.conf comes from the idle settings; penumbra-settings writes it (and applies the rest).
    backup_file "$HOME/.config/hypr/hypridle.conf" .config/hypr/hypridle.conf
    "$HOME/.local/bin/penumbra-settings" apply
    install_wallpapers
    retire_legacy_desktop

    step 'Applying themes and starting services'
    apply_gtk_settings
    install_app_colors
    # Every colour file above comes in the default dark palette; render them again for the chosen
    # theme (and set the GTK theme for its mode).
    "$HOME/.local/bin/penumbra-theme" restore
    configure_keyring
    disable_dunst
    systemctl --user daemon-reload
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        hyprctl reload
        hyprctl dispatch "hl.dsp.exec_cmd('~/.local/bin/penumbra-session restart')"
    fi

    printf '\nPenumbra installed. User backup: %s\n' "$BACKUP"
    echo 'Log out when convenient to apply every environment setting.'
}

# ─── Uninstall ───────────────────────────────────────────────────────────────
# Every installer run left a backup; undo them newest first: remove the files a run added, then put
# back the ones it replaced. What is there now is kept in an uninstall-STAMP backup first, in case
# you changed something since.

# backup_runs DIR → the run backups in DIR (named YYYYmmdd-HHMMSS), newest first.
backup_runs() {
    find "$1" -mindepth 1 -maxdepth 1 -type d -regextype posix-extended -regex '.*/[0-9]{8}-[0-9]{6}' \
        -printf '%f\n' 2>/dev/null | sort -r
}

# keep_once PATH NAME: back PATH up unless an earlier step of this uninstall already did; the first
# copy is what you had before uninstalling.
keep_once() { [[ -e $BACKUP/$2 || -L $BACKUP/$2 ]] || backup_file "$1" "$2"; }

# undo_runs DIR TARGET TOPS...: undo every run in DIR. Saved files are TOPS or under them (e.g. ".config",
# ".gitconfig" or "etc"), relative to TARGET ($HOME or /); new-files.txt paths must be under TARGET.
undo_runs() {
    local dir=$1 target=$2 run path rel top
    shift 2
    local runs
    mapfile -t runs < <(backup_runs "$dir")
    for run in "${runs[@]}"; do
        if [[ -r $dir/$run/new-files.txt ]]; then
            while IFS= read -r path; do
                [[ $path == "${target%/}"/* ]] && [[ -e $path || -L $path ]] || continue
                rel=${path#"${target%/}/"}
                [[ " $* " == *" ${rel%%/*} "* ]] || continue  # Only under TOPS.
                keep_once "$path" "$rel"
                rm -f "$path"
            done < "$dir/$run/new-files.txt"
        fi
        for top in "$@"; do
            [[ -e $dir/$run/$top ]] || continue
            while IFS= read -r -d '' path; do
                rel=${path#"$dir/$run/"}
                keep_once "${target%/}/$rel" "$rel"
                mkdir -p "$(dirname "${target%/}/$rel")"
                rm -f "${target%/}/$rel"
                cp -a "$path" "${target%/}/$rel"
            done < <(find "$dir/$run/$top" \( -type f -o -type l \) -print0)
        done
        echo "Undid the install of $run."
    done
}

# oldest_backup DIR FILE → FILE from the oldest run that has it: the state before Penumbra.
oldest_backup() {
    local run
    while IFS= read -r run; do
        [[ -e $1/$run/$2 ]] && { printf '%s\n' "$1/$run/$2"; return 0; }
    done < <(backup_runs "$1" | sort)
    return 1
}

uninstall_user() {
    local dir=$HOME/.local/state/penumbra/backups file key value schema editor
    [[ -n $(backup_runs "$dir") ]] || die "No Penumbra backups in $dir; nothing to undo."
    BACKUP=$dir/uninstall-$STAMP
    mkdir -p "$BACKUP"
    step 'Removing Penumbra from your account'
    systemctl --user stop penumbra-shell.service 2>/dev/null || true
    undo_runs "$dir" "$HOME" .config .local .gitconfig .mozilla
    # The lock screen's link to the current wallpaper, the theme choice, its palette and the colours
    # found in wallpapers, and folders left empty.
    [[ -L $HOME/.local/share/penumbra/lock.png ]] && rm -f "$HOME/.local/share/penumbra/lock.png"
    rm -f "$HOME/.local/state/penumbra/theme.json" "$HOME/.local/state/penumbra/palette.json"
    rm -rf "$HOME/.cache/penumbra/theme"
    find "$HOME/.config/quickshell/penumbra" "$HOME/.local/share/penumbra" "$HOME/.config/nvim/lua/penumbra" \
        -depth -type d -empty -delete 2>/dev/null || true
    # The editor's theme extension, which the editor installed itself.
    for editor in ${APP_COMMANDS[vscode]}; do
        command -v "$editor" >/dev/null || continue
        "$editor" --uninstall-extension penumbra.penumbra-theme >/dev/null 2>&1 || true
    done
    systemctl --user daemon-reload
    # GSettings Penumbra changed, as they were before the first install.
    if command -v gsettings >/dev/null; then
        for file in gsettings-interface.txt gsettings-wm.txt; do
            file=$(oldest_backup "$dir" "$file") || continue
            while read -r schema key value; do
                case $key in
                    color-scheme|gtk-theme|icon-theme|cursor-theme|cursor-size|font-name|button-layout)
                        gsettings set "$schema" "$key" "$value" || true ;;
                esac
            done < "$file"
        done
    fi
    if file=$(oldest_backup "$dir" dunst.enabled); then
        systemctl --user unmask dunst.service 2>/dev/null || true
        [[ $(<"$file") == enabled ]] && systemctl --user enable dunst.service 2>/dev/null || true
    fi
    echo "Your files from before the uninstall are in $BACKUP."
}

uninstall_system() {
    [[ $EUID == 0 ]] || die 'The system part needs root: sudo ./install.sh --uninstall --system-only'
    local user=${TARGET_USER:-${SUDO_USER:-}} dir=/var/lib/penumbra/backups file shell layout variant
    [[ -n $(backup_runs "$dir") ]] || { echo "No Penumbra system backups in $dir; nothing to undo."; return 0; }
    BACKUP=$dir/uninstall-$STAMP
    mkdir -p "$BACKUP"
    step 'Removing the login screen, cursors and system files'
    undo_runs "$dir" / etc usr
    if [[ -n $user ]] && file=$(oldest_backup "$dir" previous-shell.txt); then
        shell=$(<"$file")
        if [[ -n $shell && -x $shell ]]; then usermod -s "$shell" "$user" && echo "Login shell of $user is $shell again."; fi
    fi
    if file=$(oldest_backup "$dir" localectl-status.txt); then
        layout=$(sed -n 's/^ *X11 Layout: //p' "$file")
        variant=$(sed -n 's/^ *X11 Variant: //p' "$file")
        if [[ -n $layout ]]; then
            localectl --no-convert set-x11-keymap "$layout" "$(localectl_field 'X11 Model')" "$variant" \
                "$(sed -n 's/^ *X11 Options: //p' "$file")" && echo "Login screen keyboard layout is $layout again."
        fi
    fi
    if file=$(oldest_backup "$dir" sddm.enabled) && [[ $(<"$file") != enabled ]]; then
        warn 'SDDM was not enabled before Penumbra. It stays enabled so you can still sign in; enable your'
        warn 'previous display manager, then run: sudo systemctl disable sddm'
    fi
    if file=$(oldest_backup "$dir" removed-packages.txt); then
        echo "Penumbra removed these packages; reinstall them if you want them back: $(cut -d' ' -f1 "$file" | tr '\n' ' ')"
    fi
    echo 'Packages Penumbra installed stay installed. Boot themes have their own undo:'
    echo '  sudo python3 tools/install-boot.py --restore /var/lib/penumbra/boot-backups/DIRECTORY'
    echo "System files from before the uninstall are in $BACKUP."
}

# sudo resets the environment, so hand the system part its options explicitly.
run_system_part_with_sudo() {
    local args=(--system-only --user "$USER" --distro "$DISTRO" --remove-legacy "$REMOVE_LEGACY") key
    for key in "${SETTING_KEYS[@]}"; do args+=("${SETTING_OPTIONS[$key]}" "${settings[$key]}"); done
    [[ $SKIP_PACKAGES == 1 ]] && args+=(--skip-packages)
    sudo "$ROOT/install.sh" "${args[@]}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

# Sourced (by the tests): only define the functions. `return` only works in a sourced file.
if (return 0 2>/dev/null); then return 0; fi

PART=all
UNINSTALL=0
ASSUME_YES=0
SKIP_PACKAGES=${PENUMBRA_SKIP_PACKAGES:-0}
case ${PENUMBRA_REMOVE_LEGACY:-ask} in 1) REMOVE_LEGACY=yes ;; 0) REMOVE_LEGACY=no ;; *) REMOVE_LEGACY=ask ;; esac
TARGET_USER=''
DISTRO=''
# Started and enabled by the system part, besides SDDM; a distribution's distro.sh may change them.
SERVICES=(bluetooth NetworkManager)

while (( $# )); do
    case $1 in
        --user-only) PART=user ;;
        --system-only) PART=system ;;
        --boot-only) PART=boot ;;
        --uninstall) UNINSTALL=1 ;;
        --distro) DISTRO=${2?--distro needs a name}; shift ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --remove-legacy) REMOVE_LEGACY=${2?--remove-legacy needs yes, no or ask}; shift ;;
        --user) TARGET_USER=${2?--user needs a name}; shift ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        -*)
            key=$(option_setting "$1") || { usage >&2; exit 2; }
            settings[$key]=${2?$1 needs a value}
            shift ;;
        *) TARGET_USER=$1 ;;  # Older form: --system-only NAME
    esac
    shift
done

[[ $REMOVE_LEGACY =~ ^(yes|no|ask)$ ]] || die '--remove-legacy should be yes, no or ask.'
for key in "${!settings[@]}"; do
    valid_setting "$key" "${settings[$key]}" || exit 2
done

if (( UNINSTALL )); then
    case $PART in
        system) uninstall_system ;;
        user|all)
            [[ $EUID != 0 ]] || die 'Run the uninstall as your regular desktop user, not root.'
            if interactive && [[ $ASSUME_YES != 1 ]]; then
                ask 'Remove Penumbra and put back the files it replaced?' || exit 0
            fi
            uninstall_user
            [[ $PART == all ]] && sudo "$ROOT/install.sh" --uninstall --system-only --user "$USER"
            echo 'Penumbra is uninstalled. Log out to leave the running desktop.'
            ;;
        boot) die 'Undo boot themes with: sudo python3 tools/install-boot.py --restore DIRECTORY' ;;
    esac
    exit 0
fi

load_distro
case $PART in
    boot)
        [[ $EUID == 0 ]] || exec sudo "$ROOT/install.sh" --boot-only --distro "$DISTRO"
        run_boot_part
        ;;
    system)
        run_system_part
        ;;
    user|all)
        [[ $EUID != 0 ]] || die 'Run this installer as your regular desktop user, not root.'
        load_saved_settings
        detect_settings
        for key in "${SETTING_KEYS[@]}"; do
            valid_setting "$key" "${settings[$key]}" || die "Fix '$key' with its option (see --help) or in $SETTINGS_FILE."
        done
        confirm_settings
        save_settings
        [[ $PART == all ]] && run_system_part_with_sudo
        run_user_part
        ;;
esac
