#!/usr/bin/env bash
# Penumbra installer. Run it as your regular desktop user: ./install.sh
# Run ./install.sh --help for the options.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
SETTINGS_FILE=${XDG_CONFIG_HOME:-$HOME/.config}/penumbra/settings.conf
XKB_RULES=/usr/share/X11/xkb/rules/base.lst

PACKAGES=(
    # Desktop
    hyprland quickshell awww sddm hyprlock hypridle hyprsunset rofi
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    # Terminal and editor
    kitty fish starship fastfetch htop neovim git ripgrep unzip nodejs npm tree-sitter-cli gcc
    # Applications
    dolphin pavucontrol blueman network-manager-applet xdg-utils
    # Themes and fonts
    breeze breeze-cursors breeze-icons breeze-gtk papirus-icon-theme
    qt5ct qt6ct qt5-wayland qt5-quickcontrols2 ttf-jetbrains-mono-nerd inter-font
    # Hardware and services
    networkmanager bluez bluez-utils pipewire-pulse wireplumber brightnessctl playerctl cava
    # Screenshots, clipboard, color picker, emoji and symbols
    grim slurp satty hyprpicker cliphist wl-clipboard wtype unicode-emoji noto-fonts-emoji
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
  --boot-only          Only the optional GRUB, Limine and Plymouth themes.
  --uninstall          Undo every Penumbra install: put back the files each run
                       replaced and remove the ones it added. Packages stay.
                       With --user-only, only your account's files.

Settings (detected on the first run, then remembered in $SETTINGS_FILE):
  --layout LAYOUT      Keyboard layout, e.g. us, gb, fr, de, or "us,fr" for several.
  --variant VARIANT    Layout variant, e.g. intl, dvorak, colemak. Empty for none.
  --kb-options OPTS    XKB options, e.g. caps:escape,grp:alt_shift_toggle.
  --scale SCALE        Display scale: auto, 1, 1.25, 1.5, 2...
  --numlock on|off     Turn Num Lock on when you log in.
  --shell fish|keep    Make fish your login shell, or keep the current one.

Other options:
  -y, --yes            Don't ask about the settings; use the saved or detected ones.
  --skip-packages      Don't install packages (or PENUMBRA_SKIP_PACKAGES=1).
  --remove-legacy yes|no|ask
                       Whether to remove Waybar, Mako and swaybg if they are
                       installed (or PENUMBRA_REMOVE_LEGACY=1/0). Default: ask.
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
        echo '# Penumbra settings, written by install.sh.'
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
    # Hyprland's no_hardware_cursors: 1 forces software cursors, 2 decides per GPU.
    if is_vm; then text=${text//@@SOFTWARE_CURSOR@@/1}; else text=${text//@@SOFTWARE_CURSOR@@/2}; fi
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
    # Use the currently synced repositories; never refresh the database alone. pacman asks about
    # conflicts and replacements itself, unless nobody is there to answer.
    local confirm=()
    interactive || confirm=(--noconfirm)
    pacman -S --needed "${confirm[@]}" "${PACKAGES[@]}"
}

remove_legacy_packages() {
    local installed
    mapfile -t installed < <(pacman -Qq "${LEGACY_PACKAGES[@]}" 2>/dev/null || true)
    (( ${#installed[@]} )) || return 0
    case $REMOVE_LEGACY in
        yes) ;;
        ask) ask "Remove packages Penumbra no longer uses (${installed[*]})?" || return 0 ;;
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
    BACKUP=/var/lib/penumbra/backups/$STAMP
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
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
    gsettings set org.gnome.desktop.interface icon-theme Penumbra
    gsettings set org.gnome.desktop.interface cursor-theme Penumbra-Cursors
    gsettings set org.gnome.desktop.interface cursor-size 28
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
    # Only a close button on title bars: Hyprland tiles, so minimize and maximize do nothing.
    gsettings set org.gnome.desktop.wm.preferences button-layout ':close'
}

# The Penumbra shell is the notification daemon; mask Dunst so it can't compete.
disable_dunst() {
    systemctl --user cat dunst.service >/dev/null 2>&1 || return 0
    systemctl --user is-enabled dunst.service > "$BACKUP/dunst.enabled" 2>&1 || true
    backup_file "$HOME/.config/systemd/user/dunst.service" .config/systemd/user/dunst.service
    systemctl --user mask --now dunst.service
    systemctl --user daemon-reload
}

run_user_part() {
    BACKUP=$HOME/.local/state/penumbra/backups/$STAMP
    mkdir -p "$BACKUP"

    step 'Installing your configuration'
    prune_tree "$ROOT/config/quickshell/penumbra" "$HOME/.config/quickshell/penumbra"
    prune_tree "$ROOT/config/nvim/lua/penumbra" "$HOME/.config/nvim/lua/penumbra"
    local script
    for script in "$HOME"/.local/bin/penumbra-*; do
        [[ -e $script && ! -e $ROOT/bin/${script##*/} ]] || continue
        backup_file "$script" "${script#"$HOME/"}"
        rm -f "$script"
        echo "Removed ~/.local/bin/${script##*/}; Penumbra no longer uses it."
    done
    install_tree "$ROOT/config" "$HOME/.config"
    install_tree "$ROOT/bin" "$HOME/.local/bin"
    install_tree "$ROOT/share" "$HOME/.local/share"
    create_user_files
    chmod +x "$HOME"/.local/bin/penumbra-*
    # The configs above come rounded; put back sharp corners if that was the choice.
    "$HOME/.local/bin/penumbra-corners" restore
    install_wallpapers
    retire_legacy_desktop

    step 'Applying themes and starting services'
    apply_gtk_settings
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

# undo_runs DIR TARGET TOPS...: undo every run in DIR. Saved files live under TOPS (e.g. ".config",
# or "etc"), relative to TARGET ($HOME or /); new-files.txt paths must be under TARGET.
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
            [[ -d $dir/$run/$top ]] || continue
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
    local dir=$HOME/.local/state/penumbra/backups file key value schema
    [[ -n $(backup_runs "$dir") ]] || die "No Penumbra backups in $dir; nothing to undo."
    BACKUP=$dir/uninstall-$STAMP
    mkdir -p "$BACKUP"
    step 'Removing Penumbra from your account'
    systemctl --user stop penumbra-shell.service 2>/dev/null || true
    undo_runs "$dir" "$HOME" .config .local
    # The lock screen's link to the current wallpaper, and folders left empty.
    [[ -L $HOME/.local/share/penumbra/lock.png ]] && rm -f "$HOME/.local/share/penumbra/lock.png"
    find "$HOME/.config/quickshell/penumbra" "$HOME/.local/share/penumbra" "$HOME/.config/nvim/lua/penumbra" \
        -depth -type d -empty -delete 2>/dev/null || true
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
UNINSTALL=0
ASSUME_YES=0
SKIP_PACKAGES=${PENUMBRA_SKIP_PACKAGES:-0}
case ${PENUMBRA_REMOVE_LEGACY:-ask} in 1) REMOVE_LEGACY=yes ;; 0) REMOVE_LEGACY=no ;; *) REMOVE_LEGACY=ask ;; esac
TARGET_USER=''

while (( $# )); do
    case $1 in
        --user-only) PART=user ;;
        --system-only) PART=system ;;
        --boot-only) PART=boot ;;
        --uninstall) UNINSTALL=1 ;;
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
