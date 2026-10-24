#!/usr/bin/env bash
# Nocturne installer. Run it as your regular desktop user: ./install.sh
# Run ./install.sh --help for the options.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
SETTINGS_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/nocturne/settings.conf
XKB_RULES=/usr/share/X11/xkb/rules/base.lst

PACKAGES=(
    # Desktop
    hyprland quickshell awww sddm hyprlock hypridle rofi
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-kde-agent
    # Terminal and editor
    kitty fish starship fastfetch htop neovim git ripgrep unzip nodejs npm
    # Applications
    dolphin pavucontrol blueman network-manager-applet
    # Themes and fonts
    breeze breeze-cursors breeze-icons breeze-gtk papirus-icon-theme
    qt5ct qt6ct qt5-wayland qt5-quickcontrols2 ttf-jetbrains-mono-nerd inter-font
    # Hardware and services
    networkmanager bluez bluez-utils pipewire-pulse wireplumber brightnessctl playerctl
    # Screenshots, clipboard and color picker
    grim slurp satty hyprpicker cliphist wl-clipboard
    # Used by the helper scripts and build tools
    pacman-contrib flatpak libnotify librsvg python-pillow xorg-xcursorgen
)
# Replaced by the Quickshell shell (bar, notifications, OSD) and awww (wallpaper).
LEGACY_PACKAGES=(waybar mako swaybg)
LEGACY_CONFIGS=(waybar mako)

usage() {
    cat <<EOF
Usage: ./install.sh [part] [options]

Parts (default: all of them):
  --user-only          Only copy your configuration; no sudo, no packages.
  --system-only        Only the system part: packages, login screen, services.
                       Needs root; normally started by the full install.
  --boot-only          Only the optional GRUB and Plymouth themes.

Settings (detected on the first run, then remembered in $SETTINGS_FILE):
  --layout LAYOUT      Keyboard layout, e.g. us, gb, fr, de, or "us,fr" for several.
  --variant VARIANT    Layout variant, e.g. intl, dvorak, colemak. Empty for none.
  --kb-options OPTS    XKB options, e.g. caps:escape,grp:alt_shift_toggle.
  --scale SCALE        Display scale: auto, 1, 1.25, 1.5, 2...
  --numlock on|off     Turn Num Lock on when you log in.
  --shell fish|keep    Make fish your login shell, or keep the current one.

Other options:
  -y, --yes            Don't ask about the settings; use the saved or detected ones.
  --skip-packages      Don't install packages (or NOCTURNE_SKIP_PACKAGES=1).
  --remove-legacy yes|no|ask
                       Whether to remove Waybar, Mako and swaybg if they are
                       installed (or NOCTURNE_REMOVE_LEGACY=1/0). Default: ask.
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

# ─── Settings ────────────────────────────────────────────────────────────────
# Each setting comes from, in order: a command-line option, the saved settings
# file, then what this machine already uses.

declare -A settings=()
SETTING_KEYS=(kb_layout kb_variant kb_options scale numlock shell)
declare -A SETTING_LABELS=(
    [kb_layout]='Keyboard layout'
    [kb_variant]='Layout variant'
    [kb_options]='Keyboard options'
    [scale]='Display scale'
    [numlock]='Num Lock at login (on/off)'
    [shell]='Login shell (fish/keep)'
)

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
        echo '# Nocturne settings, written by install.sh.'
        echo '# Edit them, then run ./install.sh --user-only to apply.'
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

# Print a file with its @@PLACEHOLDERS@@ replaced by this user's values.
render_template() {
    local text numlock=false
    [[ ${settings[numlock]} == on ]] && numlock=true
    text=$(<"$1")
    text=${text//@@HOME@@/"$HOME"}
    text=${text//@@KB_LAYOUT@@/"${settings[kb_layout]}"}
    text=${text//@@KB_VARIANT@@/"${settings[kb_variant]}"}
    text=${text//@@KB_OPTIONS@@/"${settings[kb_options]}"}
    text=${text//@@SCALE@@/"${settings[scale]}"}
    text=${text//@@NUMLOCK@@/"$numlock"}
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

# ─── System part (root) ──────────────────────────────────────────────────────

install_packages() {
    if [[ $SKIP_PACKAGES == 1 ]]; then
        echo 'Skipping packages.'
        return
    fi
    # Use the currently synced repositories; never refresh the database alone.
    pacman -S --needed --noconfirm "${PACKAGES[@]}"
}

remove_legacy_packages() {
    local installed
    mapfile -t installed < <(pacman -Qq "${LEGACY_PACKAGES[@]}" 2>/dev/null || true)
    (( ${#installed[@]} )) || return 0
    case $REMOVE_LEGACY in
        yes) ;;
        ask) ask "Remove packages Nocturne no longer uses (${installed[*]})?" || return 0 ;;
        *) return 0 ;;
    esac
    pacman -Q "${installed[@]}" > "$BACKUP/removed-packages.txt"
    # -s also drops their now-unneeded dependencies, never explicitly installed packages.
    pacman -Rns --noconfirm "${installed[@]}" \
        || warn "Could not remove ${installed[*]}; another package may still depend on them."
}

install_system_files() {
    local source rel
    while IFS= read -r -d '' source; do
        rel=${source#"$ROOT/system/"}
        backup_file "/$rel" "$rel"
        install -Dm644 "$source" "/$rel"
    done < <(find "$ROOT/system" -type f -print0)
}

set_login_shell() {
    local user=$1
    [[ ${settings[shell]:-fish} == fish ]] || return 0
    getent passwd "$user" | cut -d: -f7 > "$BACKUP/previous-shell.txt"
    usermod -s /usr/bin/fish "$user"
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

enable_services() {
    local unit
    for unit in bluetooth NetworkManager sddm; do
        systemctl is-enabled "$unit" > "$BACKUP/$unit.enabled" 2>&1 || true
    done
    systemctl enable --now bluetooth NetworkManager
    # Not started now: that would end the current session.
    systemctl enable sddm
}

run_system_part() {
    [[ $EUID == 0 ]] || die 'The system part needs root: sudo ./install.sh --system-only'
    local user=${TARGET_USER:-${SUDO_USER:-}}
    [[ -n $user && $user != root ]] || die 'Name the desktop user with --user NAME.'
    BACKUP=/var/lib/nocturne/backups/$STAMP
    mkdir -p "$BACKUP"

    step 'Installing packages'
    install_packages
    remove_legacy_packages

    step 'Installing the login screen, cursors and system files'
    install_system_files
    set_login_keyboard
    set_login_shell "$user"
    enable_services

    step 'Boot themes (optional)'
    # Boot assets are deliberately outside system/: deploy only after opt-in.
    python3 "$ROOT/tools/install-boot.py" || warn 'Optional boot theming did not complete; see the messages above.'

    echo "System backup: $BACKUP"
}

# ─── User part ───────────────────────────────────────────────────────────────

install_wallpapers() {
    local dir=$HOME/.local/share/nocturne wallpaper
    mkdir -p "$dir"
    for wallpaper in "$ROOT"/assets/wallpaper*.png; do
        backup_file "$dir/${wallpaper##*/}" ".local/share/nocturne/${wallpaper##*/}"
        cp "$wallpaper" "$dir/"
    done
    # The lock screen follows the chosen wallpaper; nocturne-wallpaper repoints this link.
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
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
    gsettings set org.gnome.desktop.interface icon-theme Nocturne
    gsettings set org.gnome.desktop.interface cursor-theme Nocturne-Cursors
    gsettings set org.gnome.desktop.interface cursor-size 28
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
}

# The Nocturne shell is the notification daemon; mask Dunst so it can't compete.
disable_dunst() {
    systemctl --user cat dunst.service >/dev/null 2>&1 || return 0
    systemctl --user is-enabled dunst.service > "$BACKUP/dunst.enabled" 2>&1 || true
    backup_file "$HOME/.config/systemd/user/dunst.service" .config/systemd/user/dunst.service
    systemctl --user mask --now dunst.service
    systemctl --user daemon-reload
}

run_user_part() {
    BACKUP=$HOME/.local/state/nocturne/backups/$STAMP
    mkdir -p "$BACKUP"

    step 'Installing your configuration'
    install_tree "$ROOT/config" "$HOME/.config"
    install_tree "$ROOT/bin" "$HOME/.local/bin"
    install_tree "$ROOT/share" "$HOME/.local/share"
    chmod +x "$HOME"/.local/bin/nocturne-*
    install_wallpapers
    retire_legacy_desktop

    step 'Applying themes and starting services'
    apply_gtk_settings
    disable_dunst
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        hyprctl reload
        hyprctl dispatch "hl.dsp.exec_cmd('~/.local/bin/nocturne-session restart')"
    fi

    printf '\nNocturne installed. User backup: %s\n' "$BACKUP"
    echo 'Log out when convenient to apply every environment setting.'
}

# sudo resets the environment, so hand the system part its options explicitly.
run_system_part_with_sudo() {
    local args=(
        --system-only --user "$USER"
        --layout "${settings[kb_layout]}" --variant "${settings[kb_variant]}"
        --kb-options "${settings[kb_options]}" --shell "${settings[shell]}"
        --remove-legacy "$REMOVE_LEGACY"
    )
    [[ $SKIP_PACKAGES == 1 ]] && args+=(--skip-packages)
    sudo "$ROOT/install.sh" "${args[@]}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

PART=all
ASSUME_YES=0
SKIP_PACKAGES=${NOCTURNE_SKIP_PACKAGES:-0}
case ${NOCTURNE_REMOVE_LEGACY:-ask} in 1) REMOVE_LEGACY=yes ;; 0) REMOVE_LEGACY=no ;; *) REMOVE_LEGACY=ask ;; esac
TARGET_USER=''

while (( $# )); do
    case $1 in
        --user-only) PART=user ;;
        --system-only) PART=system ;;
        --boot-only) PART=boot ;;
        --layout) settings[kb_layout]=${2?--layout needs a value}; shift ;;
        --variant) settings[kb_variant]=${2?--variant needs a value}; shift ;;
        --kb-options) settings[kb_options]=${2?--kb-options needs a value}; shift ;;
        --scale) settings[scale]=${2?--scale needs a value}; shift ;;
        --numlock) settings[numlock]=${2?--numlock needs on or off}; shift ;;
        --shell) settings[shell]=${2?--shell needs fish or keep}; shift ;;
        --skip-packages) SKIP_PACKAGES=1 ;;
        --remove-legacy) REMOVE_LEGACY=${2?--remove-legacy needs yes, no or ask}; shift ;;
        --user) TARGET_USER=${2?--user needs a name}; shift ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        -*) usage >&2; exit 2 ;;
        *) TARGET_USER=$1 ;;  # Older form: --system-only NAME
    esac
    shift
done

[[ $REMOVE_LEGACY =~ ^(yes|no|ask)$ ]] || die '--remove-legacy should be yes, no or ask.'
for key in "${!settings[@]}"; do
    valid_setting "$key" "${settings[$key]}" || exit 2
done

case $PART in
    boot)
        if [[ $EUID == 0 ]]; then exec python3 "$ROOT/tools/install-boot.py"; fi
        exec sudo python3 "$ROOT/tools/install-boot.py"
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
