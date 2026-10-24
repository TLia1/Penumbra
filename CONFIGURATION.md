# Complete Nocturne configuration

Full installer, cursor generator, scripts and authored text configuration. Compiled Xcursor binaries are under `system/usr/share/icons/Nocturne-Cursors/cursors/`; their original SVGs are under `assets/cursors/`. Both are included alongside this Markdown file.

## `install.sh`

```bash
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
```

## `tools/build-cursors.py`

```python
#!/usr/bin/env python3
"""Build original SVG cursor artwork into a complete multi-size Xcursor theme.
Requires Python 3, librsvg (rsvg-convert), and xorg-xcursorgen.
Run from any directory. No downloaded cursor artwork is used.
"""
from pathlib import Path
import math, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/cursors'
THEME=ROOT/'system/usr/share/icons/Nocturne-Cursors'
for stale in ASSETS.glob('*.svg'):stale.unlink()
shutil.rmtree(THEME/'cursors',ignore_errors=True)
ASSETS.mkdir(parents=True,exist_ok=True)
(THEME/'cursors').mkdir(parents=True,exist_ok=True)
# Palette: midnight outline, moonlit lavender body, Nocturne violet accents.
D='#100b1b'; F='url(#body)'; V='#b69af7'; A='#8a63e8'; C='#9a82c9'; R='#ef8fa4'; O=1.6
DEFS=('<defs><linearGradient id="body" gradientUnits="userSpaceOnUse" x1="0" y1="2" x2="0" y2="30">'
 '<stop offset="0" stop-color="#faf6ff"/><stop offset="1" stop-color="#d4c2ff"/></linearGradient>'
 '<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation=".9"/></filter></defs>')
def svg(*layers):
 # Every part gets a midnight rim; each layer's rims sit under its fills so overlapping parts merge into one silhouette.
 rims=''.join(r for layer in layers for r,_ in layer)
 body=''.join(''.join(r for r,_ in layer)+''.join(f for _,f in layer) for layer in layers)
 return (f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">{DEFS}'
  f'<g filter="url(#shadow)" opacity=".42" transform="translate(.4 1.1)">{rims}</g>'
  f'<g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')
def shape(d,fill=F):return (f'<path d="{d}" fill="{D}" stroke="{D}" stroke-width="{2*O}"/>',f'<path d="{d}" fill="{fill}"/>')
def cap(x1,y1,x2,y2,w,fill=F):
 line=f'<path d="M{x1:.2f} {y1:.2f} L{x2:.2f} {y2:.2f}" fill="none" stroke="{{}}" stroke-width="{{}}"/>'
 return (line.format(D,w+2*O),line.format(fill,w))
def disc(cx,cy,r,fill=F):return shape(f'M{cx-r} {cy} a{r} {r} 0 1 0 {2*r} 0 a{r} {r} 0 1 0 {-2*r} 0 Z',fill)
def ring(cx,cy,r,w,fill=F):
 circle=f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{{}}" stroke-width="{{}}"/>'
 return (circle.format(D,w+2*O),circle.format(fill,w))
def mark(d,color=D,w=1.7):return ('',f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}"/>')
def rounded(points,r):
 """Closed polygon with every corner softened by a quadratic of radius r."""
 d='';n=len(points)
 for i,(x,y) in enumerate(points):
  ends=[]
  for px,py in (points[i-1],points[(i+1)%n]):
   k=r/math.hypot(px-x,py-y);ends.append((x+(px-x)*k,y+(py-y)*k))
  d+=('M' if not i else 'L')+f'{ends[0][0]:.2f} {ends[0][1]:.2f} Q{x} {y} {ends[1][0]:.2f} {ends[1][1]:.2f} '
 return d+'Z'
def turn(points,deg,cx=16,cy=16):
 a=math.radians(deg);c,s=math.cos(a),math.sin(a)
 return [(round(cx+(x-cx)*c-(y-cy)*s,3),round(cy+(x-cx)*s+(y-cy)*c,3)) for x,y in points]
# Soft sail-shaped arrow: straight left edge, gently scooped underside.
POINTER='M5 4.3 Q5 2.6 6.3 3.7 L19.2 14.9 Q20.6 16.3 18.6 16.6 Q12 17 8.1 22.6 Q5 26 5 22 Z'
pointer=[shape(POINTER)]
def hand(fingers,thumb,palm_top):
 parts=[cap(*f) for f in fingers]+[cap(*thumb),shape(f'M9.8 {palm_top} H27 V21.8 Q27 29.6 19.8 29.6 H15.2 Q12.2 29.6 10.2 26.6 Z')]
 # Creases run from the valley between two fingers down into the palm.
 for a,b in zip(fingers,fingers[1:]):
  top=max(a[1],b[1])+1.2
  parts.append(mark(f'M{(a[0]+b[0])/2:.2f} {top:.2f} V{max(top+1.6,palm_top+2.4):.2f}',C,.9))
 return parts
point=hand([(12.6,4.6,12.6,18,5.2),(17.4,12.6,17.4,18,4.8),(21.6,14,21.6,18,4.4),(25.1,15.8,25.1,18,3.8)],(6,19.4,10.6,24.6,5),16.4)
grab=hand([(12,7.4,12,17,4.6),(16.6,5,16.6,17,4.6),(21,6.4,21,17,4.4),(25,9.4,25,17.6,3.8)],(6.2,15.6,10.4,21.4,4.6),15)
fist=hand([(12,12.8,12,17,4.6),(16.6,11.8,16.6,17,4.6),(21,12.4,21,17,4.4),(25,13.8,25,17.6,3.8)],(8.6,19.2,13.4,21.4,4.4),15)
UP=[(16,3.6),(22.2,11.6),(9.8,11.6)]
def arrows(*angles,points=UP):return [shape(rounded(turn(points,a),1.9)) for a in angles]+[disc(16,16,1.7,V)]
SMALL=[(16,2.6),(21,8.6),(11,8.6)]
text=[cap(16,5.5,16,26.5,2.8)]
target=[ring(16,16,7.4,1.8)]+[cap(*(c for xy in turn([(16,2.6),(16,7.6)],a) for c in xy),1.8) for a in (0,90,180,270)]+[disc(16,16,2,V)]
def badge(symbol,fill=V):return [disc(23.2,23.2,6.2,fill),mark(symbol)]
marks={'copy':'M20 23.2 H26.4 M23.2 20 V26.4','alias':'M20.6 25.8 L25.4 21 M21.8 20.8 H25.6 V24.6',
 'help':'M21.1 21.8 Q21.4 19.4 23.4 19.4 Q25.6 19.5 25.5 21.4 Q25.3 22.8 23.4 23.6 V24.2 M23.4 26.6 V26.7','context-menu':'M20.4 21 H26 M20.4 23.2 H26 M20.4 25.4 H26'}
def lens(symbol):return [cap(19.6,18.6,27.2,26.2,4.2),disc(14,12.6,8.4),ring(14,12.6,8.4,0.01,A),mark(symbol,D,2)]
shapes={'left_ptr':([pointer],5,3),'hand2':([point],12.6,2.4),'xterm':([text],16,16),
 'ns-resize':([arrows(0,180)],16,16),'ew-resize':([arrows(90,270)],16,16),
 'nwse-resize':([arrows(-45,135)],16,16),'nesw-resize':([arrows(45,225)],16,16),
 'fleur':([arrows(0,90,180,270,points=SMALL)],16,16),'crosshair':([target],16,16),
 'openhand':([grab],16,16),'closedhand':([fist],16,16),'forbidden':([pointer,badge('M20.9 20.9 L25.5 25.5 M26.4 23.2 a3.2 3.2 0 1 0 -6.4 0 a3.2 3.2 0 1 0 6.4 0',R)],5,3),
 'vertical-text':([[cap(5.5,16,26.5,16,2.8)]],16,16),'cell':([[cap(16,5,16,27,5),cap(5,16,27,16,5)]],16,16),
 'zoom-in':([lens('M14 8.6 V16.6 M10 12.6 H18')],14,12.6),'zoom-out':([lens('M10 12.6 H18')],14,12.6)}
for kind,symbol in marks.items():shapes[kind]=([pointer,badge(symbol)],5,3)
def spinner(t,cx=16,cy=16,r=8.6,w=4.4):
 """Violet arc chasing round a lavender track; it stretches and shrinks once per turn and loops seamlessly."""
 length=24+232*math.sin(math.pi*t)**2;mid=720*t
 head,tail=[math.radians(mid+s*length/2) for s in (1,-1)]
 x1,y1,x2,y2=cx+r*math.sin(tail),cy-r*math.cos(tail),cx+r*math.sin(head),cy-r*math.cos(head)
 arc=f'<path d="M{x1:.3f} {y1:.3f} A{r} {r} 0 {int(length>180)} 1 {x2:.3f} {y2:.3f}" fill="none" stroke="{A}" stroke-width="{w-.6}"/>'
 track=ring(cx,cy,r,w)
 return [(track[0],track[1]+arc)]
FRAMES=24
frames={name:([svg(*layers)],x,y) for name,(layers,x,y) in shapes.items()}
frames['watch']=([svg(spinner(i/FRAMES)) for i in range(FRAMES)],16,16)
frames['left_ptr_watch']=([svg(pointer,spinner(i/FRAMES,23.4,23,5,3.2)) for i in range(FRAMES)],5,3)
aliases={
 'left_ptr':'default arrow top_left_arrow center_ptr draft right_ptr',
 'hand2':'pointer pointing_hand hand hand1 link 9d800788f1b08800ae810202380a0822 e29285e634086352946a0e7090d73106',
 'xterm':'text ibeam', 'ns-resize':'n-resize s-resize top_side bottom_side v_double_arrow sb_v_double_arrow row-resize size_ver split_v double_arrow 00008160000006810000408080010102',
 'ew-resize':'e-resize w-resize left_side right_side h_double_arrow sb_h_double_arrow col-resize size_hor split_h 028006030e0e7ebffc7f7070c0600140',
 'nwse-resize':'nw-resize se-resize top_left_corner bottom_right_corner size_fdiag bd_double_arrow c7088f0f3e6c8088236ef8e1e3e70000',
 'nesw-resize':'ne-resize sw-resize top_right_corner bottom_left_corner size_bdiag fd_double_arrow fcf1c3c7cd4491d801f1e1c78f100000',
 'fleur':'move all-scroll size_all dnd-move 4498f0e0c1937ffe01fd06f973665830 9081237383d90e509aa00f00170e968f',
 'crosshair':'cross tcross diamond_cross plus color-picker', 'openhand':'grab 5c6cd98b3f3ebcb1f9c7f1c204630408',
 'closedhand':'grabbing dnd-none 208530c400c041818281048008011002',
 'forbidden':'not-allowed no-drop dnd-no-drop crossed_circle circle X_cursor 03b6e0fcb3499374a867c041f52298f0',
 'copy':'dnd-copy 1081e37283d90000800003c07f3ef6bf 6407b0e94181790501fd1e167b474872',
 'alias':'dnd-link 3085a0e285430894940527032f8b26df 640fb0e74195791501fd1ed57b41487f',
 'help':'question_arrow left_ptr_help whats_this d9ce0ab605698f320427677b458ad60b',
 'watch':'wait', 'left_ptr_watch':'progress half-busy 08e8e1c95fe2fc01f976f1e063a24ccd',
}
with tempfile.TemporaryDirectory(prefix='nocturne-cursors-') as tmp:
 tmp=Path(tmp)
 for name,(images,hx,hy) in frames.items():
  lines=[]
  for i,source in enumerate(images):
   src=ASSETS/f'{name}-{i:02}.svg';src.write_text(source)
   for size in [24,28,32,48,64]:
    png=tmp/f'{name}-{i}-{size}.png'
    subprocess.run(['rsvg-convert','-w',str(size),'-h',str(size),str(src),'-o',str(png)],check=True)
    lines.append(f'{size} {round(hx*size/32)} {round(hy*size/32)} {png} {40 if len(images)>1 else 0}')
  cfg=tmp/(name+'.conf');cfg.write_text('\n'.join(lines)+'\n')
  subprocess.run(['xcursorgen',str(cfg),str(THEME/'cursors'/name)],check=True)
 for canonical,names in aliases.items():
  for alias in names.split():shutil.copyfile(THEME/'cursors'/canonical,THEME/'cursors'/alias)
(THEME/'index.theme').write_text('[Icon Theme]\nName=Nocturne Cursors\nComment=Soft lavender cursors with midnight outlines and a violet ring spinner\nInherits=breeze_cursors\n')
# SVG contact sheet, keeping the artwork editable and inspectable.
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="570" viewBox="0 0 960 570"><rect width="960" height="570" rx="24" fill="#100d18"/><text x="40" y="50" fill="#e4dced" font-family="Inter" font-size="24">NOCTURNE / CURSORS</text><text x="40" y="79" fill="#8f809f" font-family="Inter" font-size="13">Soft lavender silhouettes · midnight outlines · violet ring spinner</text>']
for n,(name,(images,_,_)) in enumerate(frames.items()):
 x=40+(n%6)*150;y=110+(n//6)*110
 inner=images[len(images)//3].split('>',1)[1].rsplit('</svg>',1)[0]
 parts.append(f'<rect x="{x}" y="{y}" width="132" height="82" rx="12" fill="#1a1324"/><g transform="translate({x+42} {y+7}) scale(1.5)">{inner}</g><text x="{x+66}" y="{y+99}" fill="#a99abb" font-family="Inter" font-size="11" text-anchor="middle">{name}</text>')
parts.append('</svg>')
p=ROOT/'previews/cursors.svg';p.write_text(''.join(parts))
subprocess.run(['rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
print(f'Built {len(frames)} original shapes / {len(list((THEME/"cursors").iterdir()))} cursor names, five sizes each.')
```

## `tools/build-wallpapers.py`

```python
#!/usr/bin/env python3
"""Render each wallpaper and a wordmark-free variant for the lock screen and greeter,
then split the dawn and eclipse scenes into the layers the animated Quickshell wallpaper moves."""
from pathlib import Path
import copy
import io
import json
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

from PIL import Image

root = Path(__file__).resolve().parents[1]
assets = root / 'assets'
for name in ('wallpaper', 'wallpaper-dawn', 'wallpaper-eclipse'):
    source = (assets / f'{name}.svg').read_text()
    # The wordmark blurs into a smudge on hyprlock and crowds the SDDM card.
    clean = re.sub(r'<g id="wordmark">.*?</g>\n', '', source, flags=re.S)
    assert clean.count('<text') == 0 and clean != source, f'wordmark group not found in {name}.svg'
    (assets / f'{name}-clean.svg').write_text(clean)
    for variant in (name, f'{name}-clean'):
        subprocess.run(['rsvg-convert', str(assets / f'{variant}.svg'), '-o', str(assets / f'{variant}.png')], check=True)
shutil.copyfile(assets / 'wallpaper-clean.png', root / 'system/usr/share/sddm/themes/nocturne/wallpaper.png')

# Animated scenes: every top-level `layer-*` element becomes its own cropped PNG, drawn in
# document order; whatever is left (sky gradient, wordmark) is the backdrop. Stars are drawn
# by QML so they can twinkle, and glows are rendered brighter so they can breathe both ways.
ns = 'http://www.w3.org/2000/svg'
ET.register_namespace('', ns)
boost = {'glow': 1.6, 'halo': 1.6, 'nebula': 1.6}


def belongs(child, layer):
    child_id = child.get('id') or ''
    if child_id.startswith('layer-'):
        return child_id == f'layer-{layer}'
    return layer is None or child.tag == f'{{{ns}}}defs'


def render(scene, out, layer, name):
    svg = copy.deepcopy(scene)
    for child in list(svg):
        if not belongs(child, layer):
            svg.remove(child)
    for element in svg.iter():
        if name in boost and element.get('opacity'):
            element.set('opacity', f"{float(element.get('opacity')) * boost[name]:.3f}")
    png = subprocess.run(['rsvg-convert'], input=ET.tostring(svg), capture_output=True, check=True).stdout
    image = Image.open(io.BytesIO(png))
    left, top, right, bottom = image.getbbox()
    image.crop((left, top, right, bottom)).save(out / f'{name}.png', optimize=True)
    return {'name': name, 'x': left, 'y': top, 'width': right - left, 'height': bottom - top, 'boost': boost.get(name, 1)}


for name, folder in (('wallpaper-dawn', 'dawn'), ('wallpaper-eclipse', 'eclipse')):
    scene = ET.parse(assets / f'{name}.svg').getroot()
    out = root / 'config/quickshell/nocturne' / folder
    out.mkdir(exist_ok=True)
    names = [child.get('id')[6:] for child in scene if (child.get('id') or '').startswith('layer-')]
    layers = [render(scene, out, None, 'sky')] + [render(scene, out, layer, layer) for layer in names if layer != 'stars']
    stars = [{'x': float(star.get('cx')), 'y': float(star.get('cy')), 'r': float(star.get('r')),
              'opacity': float(star.get('opacity')), 'glint': star.get('class') == 'glint'}
             for star in scene.find(f".//*[@id='layer-stars']")]
    (out / 'layers.js').write_text(
        '.pragma library\n'
        f'// Generated by tools/build-wallpapers.py from assets/{name}.svg; do not edit.\n'
        f"var width = {scene.get('width')};\nvar height = {scene.get('height')};\n"
        f'var layers = {json.dumps(layers)};\nvar stars = {json.dumps(stars)};\n')
    # Shaders ship compiled; rebuilding them needs qsb from qt6-shadertools.
    for shader in out.glob('*.frag'):
        subprocess.run([shutil.which('qsb') or '/usr/lib/qt6/bin/qsb', '--qt6', '-o', f'{shader}.qsb', str(shader)], check=True)
```

## `bin/nocturne-bluetooth`

```bash
#!/usr/bin/env bash
# Always expose the control, including VMs with no passed-through adapter.
if [[ ${1:-} = open ]]; then
 if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then exec blueman-manager; else notify-send 'Bluetooth unavailable' 'No Bluetooth adapter is attached to this computer. Pass a USB adapter through to the VM to pair devices.'; fi
else
 if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then
  printf '{"text":"󰂯","tooltip":"Bluetooth · click to manage devices","class":"available"}\n'
 else
  printf '{"text":"󰂲","tooltip":"Bluetooth · no adapter attached","class":"unavailable"}\n'
 fi
fi
```

## `bin/nocturne-network`

```bash
#!/usr/bin/env bash
if nmcli -t -f TYPE device | grep -qx wifi; then
 exec kitty --class nocturne-network -e nmtui
else
 notify-send 'Network settings' 'Ethernet is available. No Wi-Fi adapter is attached to this VM.'
 exec nm-connection-editor
fi
```

## `bin/nocturne-power`

```bash
#!/usr/bin/env bash
set -euo pipefail
# The Nocturne shell draws the session overlay; this rofi menu is the fallback without it.
quickshell -c nocturne ipc call panel session >/dev/null 2>&1 && exit
# One row of large icon tiles; rofi returns the selected index, so labels can change freely.
tiles='window { width: 620px; padding: 22px; } mainbox { children: [ listview ]; }
listview { columns: 5; lines: 1; spacing: 10px; fixed-columns: true; fixed-height: true; }
element { orientation: vertical; padding: 16px 0 10px; border-radius: 16px; }
element-text { horizontal-align: 0.5; font: "Inter 10"; }'
menu() {
 local -n labels=$1 icons=$2; local i
 for i in "${!labels[@]}"; do
  printf "<span font_desc='JetBrainsMono Nerd Font 26'>%s</span>\n<span alpha='75%%'>%s</span>|" "${icons[i]}" "${labels[i]}"
 done
}
pick() { rofi -dmenu -sep '|' -eh 4 -markup-rows -no-custom -format i -no-show-icons -p "$1" -theme-str "$tiles $2"; }
names=(Lock Suspend 'Log out' Restart 'Shut down')
glyphs=(󰌾 󰤄 󰍃 󰜉 󰐥)
choice=$(menu names glyphs | pick SESSION '') || exit 0
case "$choice" in
 0) loginctl lock-session; exit;;
 1) systemctl suspend; exit;;
 2) action=logout;;
 3) action=reboot;;
 4) action=poweroff;;
 *) exit;;
esac
confirm=(Cancel "${names[choice]}")
confirm_glyphs=(󰜺 "${glyphs[choice]}")
answer=$(menu confirm confirm_glyphs | pick CONFIRM 'window { width: 300px; } listview { columns: 2; }') || exit 0
[[ "$answer" = 1 ]] || exit 0
case "$action" in
 logout) hyprctl dispatch 'hl.dsp.exit()';;
 reboot) systemctl reboot;;
 poweroff) systemctl poweroff;;
esac
```

## `bin/nocturne-session`

```bash
#!/usr/bin/env bash
set -u
export QT_QPA_PLATFORMTHEME=qt6ct GTK_THEME=Breeze-Dark XCURSOR_THEME=Nocturne-Cursors XCURSOR_SIZE=28
mkdir -p "$HOME/.local/state/nocturne"
exec 9>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nocturne-session.lock"
flock -n 9 || exit 0
if [[ ${1:-} = restart ]]; then
    pkill -x quickshell || true
    for attempt in {1..20}; do
        pgrep -u "$UID" -x quickshell >/dev/null || break
        sleep 0.1
    done
fi
start() {
 local process=$1; shift
 if ! pgrep -u "$UID" -x "$process" >/dev/null; then
  nohup "$@" >"$HOME/.local/state/nocturne/$process.log" 2>&1 9>&- &
 fi
}
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME GTK_THEME XCURSOR_THEME XCURSOR_SIZE
hyprctl setcursor Nocturne-Cursors 28 >/dev/null
start awww-daemon awww-daemon
# Bar, notifications, OSD, control center and session overlay.
start quickshell quickshell -c nocturne
start hypridle hypridle
# Clipboard history for text and images.
if ! pgrep -u "$UID" -f "^wl-paste --type text --watch cliphist store" >/dev/null; then
 nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 9>&- &
 nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 9>&- &
fi
if ! pgrep -u "$UID" -f "^/usr/lib/polkit-kde-authentication-agent-1" >/dev/null; then
 nohup /usr/lib/polkit-kde-authentication-agent-1 >"$HOME/.local/state/nocturne/polkit.log" 2>&1 9>&- &
fi
nohup "$HOME/.local/bin/nocturne-wallpaper" restore >"$HOME/.local/state/nocturne/wallpaper.log" 2>&1 9>&- &
exec 9>&-
```

## `bin/nocturne-shot`

```bash
#!/usr/bin/env bash
# Region screenshot to ~/Pictures/Screenshots; "annotate" opens it in Satty first.
set -euo pipefail
mkdir -p "$HOME/Pictures/Screenshots"
region=$(slurp -b 100d18aa -c b69af7 -w 2) || exit 0
file="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
if [[ ${1:-} = annotate ]]; then
 grim -g "$region" - | satty --filename - --output-filename "$file"
 exit
fi
grim -g "$region" "$file"
wl-copy < "$file"
notify-send -a Nocturne -i "$file" 'Screenshot saved' "Copied to clipboard · ${file/#$HOME/\~}"
```

## `bin/nocturne-clipboard`

```bash
#!/usr/bin/env bash
# Clipboard history from cliphist, picked in the Nocturne launcher style.
set -euo pipefail
if [[ ${1:-} = clear ]]; then
 cliphist wipe
 notify-send -a Nocturne 'Clipboard cleared' 'History has been wiped.'
 exit
fi
choice=$(cliphist list | rofi -dmenu -i -p CLIPBOARD -display-columns 2 \
 -theme-str 'entry { placeholder: "Search clipboard history…"; } listview { lines: 8; } element { padding: 9px 12px; }') || exit 0
cliphist decode <<<"$choice" | wl-copy
```

## `bin/nocturne-picker`

```bash
#!/usr/bin/env bash
# Pick any on-screen color; the hex value is copied to the clipboard.
set -euo pipefail
color=$(hyprpicker --autocopy --format=hex --no-fancy --quiet 2>/dev/null) || exit 0
[[ -n "$color" ]] || exit 0
notify-send -a Nocturne "Color copied · $color" "<span foreground='$color'>██████</span>  $color"
```

## `bin/nocturne-wallpaper`

```bash
#!/usr/bin/env bash
# Switch Nocturne wallpapers with an awww transition; the lock screen follows the choice.
set -euo pipefail
dir="$HOME/.local/share/nocturne"
state="$HOME/.local/state/nocturne/wallpaper"
names=(wallpaper wallpaper-dawn wallpaper-eclipse)
current=$(cat "$state" 2>/dev/null || echo wallpaper)
[[ -e "$dir/$current.png" ]] || current=wallpaper
transition=(--transition-type grow --transition-duration 1.4 --transition-fps 120)
case "${1:-next}" in
 next)
  for i in "${!names[@]}"; do [[ ${names[i]} = "$current" ]] && break; done
  current=${names[(i + 1) % ${#names[@]}]}
  # Grow each scene out of its planet, or the eclipse.
  case $current in
   wallpaper-dawn) transition+=(--transition-pos 0.32,0.37);;
   wallpaper-eclipse) transition+=(--transition-pos 0.65,0.63);;
   *) transition+=(--transition-pos 0.68,0.51);;
  esac;;
 restore) transition=(--transition-type none);;
 *) echo "Usage: nocturne-wallpaper [next|restore]" >&2; exit 2;;
esac
mkdir -p "${state%/*}"
printf '%s\n' "$current" > "$state"
ln -sfn "$dir/$current-clean.png" "$dir/lock.png"
# The shell animates dawn and eclipse over awww's still image, once the transition has finished.
[[ ${1:-next} = restore ]] && delay=0 || delay=1400
quickshell -c nocturne ipc call wallpaper set "$current" "$delay" >/dev/null 2>&1 || true
for _ in {1..50}; do awww query >/dev/null 2>&1 && break; sleep 0.1; done
exec awww img "$dir/$current.png" --resize crop "${transition[@]}"
```

## `config/dolphinrc`

```text
[General]
ShowFullPath=true
RememberOpenedTabs=false

[MainWindow]
MenuBar=Disabled

[DetailsMode]
PreviewSize=48

[IconsMode]
IconSize=64
PreviewSize=80

[KFileDialog Settings]
Places Icons Auto-resize=false
Places Icons Static Size=22

[UiSettings]
ColorScheme=Nocturne
```

## `config/environment.d/60-nocturne.conf`

```text
QT_QPA_PLATFORMTHEME=qt6ct
GTK_THEME=Breeze-Dark
XCURSOR_THEME=Nocturne-Cursors
XCURSOR_SIZE=28
```

## `config/fish/config.fish`

```fish
if status is-interactive
    set -g fish_greeting
    set -g fish_color_normal e4dced
    set -g fish_color_command b69af7
    set -g fish_color_param ccc0dd
    set -g fish_color_quote a5ccb3
    set -g fish_color_error ef8fa4
    set -g fish_color_comment 71637f
    set -g fish_color_autosuggestion 71637f
    set -g fish_color_selection --background=38264f
    set -g fish_pager_color_prefix b69af7 --bold
    set -g fish_pager_color_selected_background --background=38264f
    starship init fish | source
    abbr --add ll 'ls -lah --color=auto'
    abbr --add update 'sudo pacman -Syu'
end
```

## `config/fish/functions/fish_greeting.fish`

```fish
function fish_greeting
    if command -q fastfetch
        if test "$TERM" = xterm-kitty; and test "$COLUMNS" -ge 95
            fastfetch
        else
            fastfetch --logo none
        end
    else
        set_color b69af7
        printf '\n  ◈  N O C T U R N E\n'
        set_color normal
    end
end
```

## `config/gtk-3.0/gtk.css`

```css
@define-color theme_selected_bg_color #916dcf;
@define-color theme_selected_fg_color #ffffff;
@define-color theme_bg_color #100d18;
@define-color theme_fg_color #e4dced;
@define-color theme_base_color #0d0a12;
@define-color theme_text_color #e4dced;
@define-color accent_color #b69af7;
@define-color accent_bg_color #916dcf;
@define-color accent_fg_color #ffffff;
window, dialog { background-color: #100d18; color: #e4dced; }
headerbar { background: #16111f; color: #e4dced; }
selection { background-color: #916dcf; color: #ffffff; }
```

## `config/gtk-3.0/settings.ini`

```text
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Nocturne
gtk-font-name=Inter 10
gtk-cursor-theme-name=Nocturne-Cursors
gtk-cursor-theme-size=28
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=icon:minimize,maximize,close
```

## `config/gtk-4.0/gtk.css`

```css
@define-color theme_selected_bg_color #916dcf;
@define-color theme_selected_fg_color #ffffff;
@define-color theme_bg_color #100d18;
@define-color theme_fg_color #e4dced;
@define-color theme_base_color #0d0a12;
@define-color theme_text_color #e4dced;
@define-color accent_color #b69af7;
@define-color accent_bg_color #916dcf;
@define-color accent_fg_color #ffffff;
window, dialog { background-color: #100d18; color: #e4dced; }
headerbar { background: #16111f; color: #e4dced; }
selection { background-color: #916dcf; color: #ffffff; }
```

## `config/gtk-4.0/settings.ini`

```text
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Nocturne
gtk-font-name=Inter 10
gtk-cursor-theme-name=Nocturne-Cursors
gtk-cursor-theme-size=28
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=icon:minimize,maximize,close
```

## `config/hypr/hypridle.conf`

```text
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms("on")'
}
listener {
    timeout = 600
    on-timeout = loginctl lock-session
}
```

## `config/hypr/hyprland.lua`

```lua
-- NOCTURNE / Hyprland 0.56 Lua configuration
-- Keyboard, Num Lock and scale come from ~/.config/nocturne/settings.conf (see ./install.sh --help).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "@@SCALE@@" })
hl.env("XCURSOR_THEME", "Nocturne-Cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "Breeze-Dark")
hl.config({
 xwayland = {
    force_zero_scaling = true
 },
 cursor = { no_hardware_cursors = 1, enable_hyprcursor = false },
 general = { gaps_in = 6, gaps_out = 14, border_size = 2, resize_on_border = true, layout = "dwindle",
  col = { active_border = {colors = {"rgba(a78bfaee)", "rgba(6d28d9bb)"}, angle = 45}, inactive_border = "rgba(282333ff)" } },
 decoration = { rounding = 16, rounding_power = 2, active_opacity = 1, inactive_opacity = 0.97,
  shadow = {enabled = true, range = 28, render_power = 3, color = "rgba(1a0b2e88)", color_inactive = "rgba(00000055)"},
  glow = {enabled = true, range = 18, render_power = 3, color = "rgba(7c3aed40)", color_inactive = "rgba(00000000)"},
  blur = {enabled = true, size = 6, passes = 3, vibrancy = 0.2, noise = 0.02, contrast = 1.1, brightness = 0.9, popups = true} },
 animations = {enabled = true},
 dwindle = {preserve_split = true},
 input = {kb_layout = "@@KB_LAYOUT@@", kb_variant = "@@KB_VARIANT@@", kb_options = "@@KB_OPTIONS@@", numlock_by_default = @@NUMLOCK@@,
  follow_mouse = 1, sensitivity = 0, touchpad = {natural_scroll = true}},
 misc = {disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0},
})
hl.curve("nocturne", {type = "bezier", points = {{0.16, 1}, {0.3, 1}}})
hl.curve("soft", {type = "bezier", points = {{0.4, 0}, {0.2, 1}}})
hl.curve("linear", {type = "bezier", points = {{0, 0}, {1, 1}}})
for _, a in ipairs({
 {"windows", 4.5, "nocturne", "slide"}, {"windowsIn", 4, "nocturne", "popin 94%"},
 {"windowsOut", 3, "soft", "popin 96%"}, {"border", 5, "nocturne", nil},
 {"borderangle", 60, "linear", "loop"},
 {"fade", 3, "soft", nil}, {"workspaces", 4.5, "nocturne", "slide"},
 {"layers", 3.5, "nocturne", "fade"}
}) do hl.animation({leaf=a[1], enabled=true, speed=a[2], bezier=a[3], style=a[4]}) end
local function exec(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd)) end
exec("SUPER + Return", "kitty")
exec("SUPER + Q", "kitty")
exec("SUPER + E", "dolphin")
exec("SUPER + R", "rofi -show drun")
exec("SUPER + space", "rofi -show drun")
exec("SUPER + B", "firefox")
exec("SUPER + M", "~/.local/bin/nocturne-power")
exec("SUPER + L", "loginctl lock-session")
exec("SUPER + N", "quickshell -c nocturne ipc call notifications clear")
exec("SUPER + A", "quickshell -c nocturne ipc call panel control")
exec("SUPER + SHIFT + V", "~/.local/bin/nocturne-clipboard")
exec("SUPER + SHIFT + C", "~/.local/bin/nocturne-picker")
exec("SUPER + W", "~/.local/bin/nocturne-wallpaper next")
exec("SUPER + SHIFT + R", "~/.local/bin/nocturne-session restart")
exec("Print", "~/.local/bin/nocturne-shot")
exec("SHIFT + Print", "~/.local/bin/nocturne-shot annotate")
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
for _, d in ipairs({"left", "right", "up", "down"}) do hl.bind("SUPER + "..d, hl.dsp.focus({direction=d})) end
-- Physical keycodes keep the number-row workspace shortcuts working on any layout (AZERTY included).
for i=1,10 do
 hl.bind("SUPER + code:"..(i+9), hl.dsp.focus({workspace=i}))
 hl.bind("SUPER + SHIFT + code:"..(i+9), hl.dsp.window.move({workspace=i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse=true})
hl.bind("SUPER + mouse_down", hl.dsp.focus({workspace="e+1"}))
hl.bind("SUPER + mouse_up", hl.dsp.focus({workspace="e-1"}))
for key,cmd in pairs({
 XF86AudioRaiseVolume="~/.local/bin/nocturne-osd volume up",
 XF86AudioLowerVolume="~/.local/bin/nocturne-osd volume down",
 XF86AudioMute="~/.local/bin/nocturne-osd volume mute",
 XF86AudioMicMute="~/.local/bin/nocturne-osd microphone mute",
 XF86MonBrightnessUp="~/.local/bin/nocturne-osd brightness up", XF86MonBrightnessDown="~/.local/bin/nocturne-osd brightness down",
 XF86AudioPlay="playerctl play-pause", XF86AudioNext="playerctl next", XF86AudioPrev="playerctl previous"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true, repeating=true}) end
hl.window_rule({name="settings", match={class="^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|qt6ct)$"}, float=true, size="820 540", center=true})
hl.window_rule({name="annotate", match={class="^(com.gabm.satty)$"}, float=true, center=true})
-- Frosted glass behind every Nocturne shell surface and the launcher.
hl.layer_rule({name="glass", match={namespace="^(nocturne-.*|rofi)$"}, blur=true, ignore_alpha=0.3})
hl.window_rule({name="suppress-maximize", match={class=".*"}, suppress_event="maximize"})
hl.on("hyprland.start", function() hl.exec_cmd("~/.local/bin/nocturne-session") end)
```

## `config/hypr/hyprlock.conf`

```text
general {
    hide_cursor = true
    immediate_render = true
    screencopy_mode = 1
}
background {
    monitor =
    path = ~/.local/share/nocturne/lock.png
    blur_passes = 2
    blur_size = 3
    brightness = 0.7
}
label {
    monitor =
    text = $TIME
    color = rgba(e9e1f5ff)
    font_size = 84
    font_family = Inter
    position = 0, 100
    halign = center
    valign = center
}
label {
    monitor =
    text = N O C T U R N E   /   $USER
    color = rgba(b69af7ff)
    font_size = 12
    font_family = Inter
    position = 0, 20
    halign = center
    valign = center
}
input-field {
    monitor =
    size = 310, 56
    outline_thickness = 2
    fade_on_empty = false
    dots_size = 0.2
    dots_spacing = 0.3
    outer_color = rgba(8e6ac8ff)
    inner_color = rgba(15101fee)
    font_color = rgba(e9e1f5ff)
    check_color = rgba(a5ccb3ff)
    fail_color = rgba(ef8fa4ff)
    placeholder_text = Enter password
    fail_text = Try again ($ATTEMPTS)
    rounding = 14
    position = 0, -65
    halign = center
    valign = center
}
```

## `config/kdeglobals`

```text
[General]
Name=Nocturne
ColorScheme=Nocturne
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0

[Colors:View]
BackgroundNormal=13,10,18
BackgroundAlternate=20,15,28
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Window]
BackgroundNormal=16,13,24
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Button]
BackgroundNormal=31,24,43
BackgroundAlternate=39,30,52
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Selection]
BackgroundNormal=145,109,207
BackgroundAlternate=118,85,174
ForegroundNormal=255,250,255
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Tooltip]
BackgroundNormal=22,17,31
BackgroundAlternate=28,21,39
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Complementary]
BackgroundNormal=13,10,18
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Header]
BackgroundNormal=20,15,28
BackgroundAlternate=26,19,36
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Icons]
Theme=Nocturne

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
widgetStyle=Breeze
SingleClick=false

[ColorEffects:Disabled]
Color=56,48,66
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[WM]
activeBackground=20,15,28
activeForeground=228,220,237
inactiveBackground=13,10,18
inactiveForeground=139,124,156

[UiSettings]
ColorScheme=Nocturne
```

## `config/kitty/kitty.conf`

```text
# NOCTURNE
shell /usr/bin/fish
font_family JetBrainsMono Nerd Font
bold_font auto
italic_font auto
font_size 11.0
window_padding_width 24
background #0d0a12
foreground #e4dced
background_opacity 0.8
dynamic_background_opacity yes
selection_background #563b7e
selection_foreground #ffffff
cursor #bb9af7
cursor_text_color #100b1b
cursor_shape beam
cursor_trail 3
cursor_trail_decay 0.12 0.35
cursor_blink_interval 0.6
url_color #c4a5ff
color0 #231d2e
color1 #ef8fa4
color2 #a5ccb3
color3 #e5c89a
color4 #a1a5e9
color5 #b69af7
color6 #9ccbd2
color7 #ded5e8
color8 #71637f
color9 #f7a3b6
color10 #b9e0c6
color11 #f4dab0
color12 #b8bdf5
color13 #ceb4ff
color14 #b4e0e5
color15 #faf5ff
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
active_tab_background #a78bfa
active_tab_foreground #110d19
inactive_tab_background #21192e
inactive_tab_foreground #9687aa
hide_window_decorations yes
enable_audio_bell no
confirm_os_window_close 0
remember_window_size yes
initial_window_width 100c
initial_window_height 28c
map ctrl+shift+enter new_window_with_cwd
map ctrl+shift+t new_tab_with_cwd
```

## `config/qt5ct/qt5ct.conf`

```text
[Appearance]
color_scheme_path=@@HOME@@/.config/qt6ct/colors/Nocturne.conf
custom_palette=true
icon_theme=Nocturne
standard_dialogs=default
style=Breeze

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
general="Inter,10,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=0
buttonbox_layout=0
dialog_buttons_have_icons=1
menus_have_icons=true
toolbutton_style=4
```

## `config/qt6ct/colors/Nocturne.conf`

```text
[ColorScheme]
active_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
disabled_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
inactive_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
```

## `config/qt6ct/qt6ct.conf`

```text
[Appearance]
color_scheme_path=@@HOME@@/.config/qt6ct/colors/Nocturne.conf
custom_palette=true
icon_theme=Nocturne
standard_dialogs=default
style=Breeze

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
general="Inter,10,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=0
buttonbox_layout=0
dialog_buttons_have_icons=1
menus_have_icons=true
toolbutton_style=4
```

## `config/quickshell/nocturne/shell.qml`

```qml
//@ pragma UseQApplication
//@ pragma IconTheme Nocturne
// NOCTURNE shell: animated wallpapers, bar, control center, notifications, OSD, calendar and session overlay.
// Run with `quickshell -c nocturne`; scripts talk to it with `quickshell -c nocturne ipc call …`.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Wallpaper {
        id: wallpaper
    }

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    ControlCenter {}
    CalendarPanel {}
    ProcessPanel {}
    NotificationPopups {}
    Osd {}
    SessionMenu {}

    IpcHandler {
        target: "osd"
        function flash(kind: string, value: int, muted: bool): void {
            Ui.showOsd(kind, value, muted);
        }
    }

    IpcHandler {
        target: "panel"
        function control(): void { Ui.toggleControl(); }
        function wifi(): void { Ui.openControl("wifi"); }
        function bluetooth(): void { Ui.openControl("bluetooth"); }
        function calendar(): void { Ui.toggleCalendar(); }
        function monitor(): void { Ui.toggleMonitor(); }
        function session(): void { Ui.openSession(); }
        function close(): void { Ui.close(); Ui.sessionOpen = false; }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clear(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
    }

    IpcHandler {
        target: "wallpaper"
        // `delay` is how long awww's transition takes, in milliseconds.
        function set(name: string, delay: int): void { wallpaper.show(name, delay); }
    }

    IpcHandler {
        target: "updates"
        function refresh(): void { Sys.refreshUpdates(); }
    }
}
```

## `config/quickshell/nocturne/Wallpaper.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Animated wallpapers. Each scene sits on the bottom layer over awww's still copy of the same
// image, so fading it in or out changes nothing at rest; night has no animated scene.
// nocturne-wallpaper says when the wallpaper changes.
Scope {
    id: root

    readonly property var scenes: ["wallpaper-dawn", "wallpaper-eclipse"]
    // The animated scene that should be up, and the one loaded now; they differ while one fades out.
    property string target: ""
    property string scene: ""
    // awww's transition is still running.
    property bool waiting: false
    readonly property bool shown: target !== "" && scene === target && !waiting

    property real fade: shown ? 1 : 0
    Behavior on fade { NumberAnimation { duration: root.shown ? 900 : 350; easing.type: Easing.InOutQuad } }
    onFadeChanged: if (fade === 0) scene = target
    onTargetChanged: if (fade === 0) scene = target

    // Wait out awww's transition before covering it.
    function show(name, delay) {
        target = scenes.includes(name) ? name : "";
        waiting = delay > 0;
        if (waiting) {
            reveal.interval = delay;
            reveal.restart();
        }
    }
    Timer {
        id: reveal
        onTriggered: root.waiting = false
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/nocturne/wallpaper"
        onLoaded: root.show(text().trim(), 0)
    }

    Variants {
        model: Quickshell.screens

        delegate: Scope {
            id: output
            required property var modelData

            LazyLoader {
                active: root.fade > 0

                PanelWindow {
                    id: window
                    screen: output.modelData
                    anchors { top: true; bottom: true; left: true; right: true }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    mask: Region {}
                    WlrLayershell.layer: WlrLayer.Bottom
                    // Not nocturne-*: the glass layer rule would blur it.
                    WlrLayershell.namespace: "animated-wallpaper"

                    // Nothing to see under a fullscreen window; stop drawing.
                    readonly property bool running: !(Hyprland.monitorFor(screen)?.activeWorkspace?.hasFullscreen ?? false)

                    // Cover the screen like `awww img --resize crop`.
                    Loader {
                        id: scene
                        anchors.centerIn: parent
                        scale: item ? Math.max(window.width / item.width, window.height / item.height) : 1
                        opacity: root.fade
                        sourceComponent: root.scene === "wallpaper-eclipse" ? eclipse : dawn

                        Component {
                            id: dawn
                            DawnScene {
                                running: window.running
                                pixelScale: Math.max(window.width / width, window.height / height) * window.devicePixelRatio
                            }
                        }
                        Component {
                            id: eclipse
                            EclipseScene {
                                running: window.running
                                pixelScale: Math.max(window.width / width, window.height / height) * window.devicePixelRatio
                            }
                        }
                    }
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/WallpaperScene.qml`

```qml
import QtQuick

// Base for an animated wallpaper scene, laid out in the SVG's own coordinates. Its layers are
// PNGs and a layers.js written by tools/build-wallpapers.py into `folder`, next to this file.
Item {
    id: root
    required property string folder
    required property var layers
    property bool running: true
    // Device pixels per scene unit, so layers decode no larger than they are shown.
    property real pixelScale: 1

    // Seconds of animation; ticking at 30 Hz keeps the redraws cheap.
    property real t: 0
    Timer {
        interval: 33
        repeat: true
        running: root.running
        onTriggered: root.t += interval / 1000
    }
    function wave(period, phase = 0) {
        return Math.sin(2 * Math.PI * root.t / period + phase);
    }
}
```

## `config/quickshell/nocturne/SceneLayer.qml`

```qml
import QtQuick

// One pre-rendered layer of a scene, placed where tools/build-wallpapers.py cropped it.
// `angle` turns it and `zoom` scales it around `pivot`, in scene coordinates.
Image {
    id: root
    required property WallpaperScene scene
    required property string name
    readonly property var info: scene.layers.find(layer => layer.name === name)
    property point pivot: Qt.point(info.x + info.width / 2, info.y + info.height / 2)
    property real angle: 0
    property real zoom: 1

    x: info.x
    y: info.y
    width: info.width
    height: info.height
    source: scene.folder + "/" + name + ".png"
    sourceSize: Qt.size(Math.ceil(info.width * scene.pixelScale), Math.ceil(info.height * scene.pixelScale))
    smooth: true
    transform: [
        Scale {
            origin.x: root.pivot.x - root.x
            origin.y: root.pivot.y - root.y
            xScale: root.zoom
            yScale: root.zoom
        },
        Rotation {
            origin.x: root.pivot.x - root.x
            origin.y: root.pivot.y - root.y
            angle: root.angle
        }
    ]
}
```

## `config/quickshell/nocturne/Stars.qml`

```qml
import QtQuick

// A scene's stars, each twinkling on its own rhythm; glint stars flash a four-point sparkle at their brightest.
Item {
    id: root
    required property WallpaperScene scene
    required property var stars
    property color color: "#e9c8f2"

    Repeater {
        model: root.stars

        delegate: Item {
            id: star
            required property var modelData
            required property int index
            readonly property real twinkle: 0.8 + 0.45 * root.scene.wave(3.5 + index * 0.73 % 4, index * 2.4)
            readonly property real flash: Math.max(0, twinkle - 0.85) / 0.4
            x: modelData.x
            y: modelData.y

            Rectangle {
                x: -width / 2
                y: -height / 2
                width: star.modelData.r * 2
                height: width
                radius: width / 2
                color: root.color
                opacity: star.modelData.opacity * star.twinkle
            }

            Item {
                visible: star.modelData.glint && star.flash > 0
                opacity: star.flash
                scale: 0.6 + 0.6 * star.flash
                Rectangle {
                    x: -width / 2
                    y: -height / 2
                    width: 56
                    height: 1.2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.color }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Rectangle {
                    x: -width / 2
                    y: -height / 2
                    width: 1.2
                    height: 40
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: root.color }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Meteor.qml`

```qml
import QtQuick

// Now and then a shooting star starts somewhere in `area` (scene coordinates) and falls along `heading`.
Item {
    id: root
    property bool running: true
    property rect area
    property real heading: 155
    property real distance: 560

    Rectangle {
        id: streak
        property real startX: 0
        property real startY: 0
        property real progress: 0
        width: 260
        height: 2
        radius: 1
        visible: falling.running
        transformOrigin: Item.Right
        rotation: root.heading
        x: startX + root.distance * progress * Math.cos(root.heading * Math.PI / 180) - width
        y: startY + root.distance * progress * Math.sin(root.heading * Math.PI / 180) - height / 2
        opacity: Math.sin(Math.PI * progress)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: "#f7e6ff" }
        }
        NumberAnimation on progress {
            id: falling
            running: false
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.InQuad
        }
    }

    Timer {
        interval: 20000 + Math.random() * 30000
        repeat: true
        running: root.running
        onTriggered: {
            interval = 20000 + Math.random() * 30000;
            streak.startX = root.area.x + Math.random() * root.area.width;
            streak.startY = root.area.y + Math.random() * root.area.height;
            falling.restart();
        }
    }
}
```

## `config/quickshell/nocturne/DawnScene.qml`

```qml
import QtQuick
import QtQuick.Shapes
import "dawn/layers.js" as Dawn

// Dawn: stars twinkle, the glow breathes, light creeps along the planet's rim, a moonlet rides
// the ring and a shooting star crosses now and then.
WallpaperScene {
    id: root
    folder: "dawn"
    layers: Dawn.layers
    width: Dawn.width
    height: Dawn.height

    // Ring geometry from assets/wallpaper-dawn.svg.
    readonly property point planet: Qt.point(820, 1010)
    readonly property real ringX: 760
    readonly property real ringY: 172
    readonly property real ringTilt: 16 * Math.PI / 180

    SceneLayer { scene: root; name: "sky"; z: 0 }
    // Rendered brighter than the still image, so it can swell and ebb around it.
    SceneLayer {
        scene: root
        name: "glow"
        z: 1
        opacity: (1 + 0.3 * root.wave(11)) / info.boost
    }
    Stars {
        scene: root
        stars: Dawn.stars
        z: 2
    }
    SceneLayer { scene: root; name: "back"; z: 3 }
    SceneLayer { scene: root; name: "planet"; z: 5 }
    SceneLayer {
        scene: root
        name: "rim"
        z: 6
        opacity: 0.85 + 0.15 * root.wave(7, 1)
        pivot: root.planet
        angle: 3 * root.wave(23)
    }
    SceneLayer { scene: root; name: "front"; z: 7 }

    // A moonlet on the ring: behind the planet on the far side, brightest where the ring is lit.
    Item {
        readonly property real angle: 2 * Math.PI * root.t / 80 + 2.2
        readonly property real along: root.ringX * Math.cos(angle)
        readonly property real across: root.ringY * Math.sin(angle)
        x: root.planet.x + along * Math.cos(root.ringTilt) - across * Math.sin(root.ringTilt)
        y: root.planet.y + along * Math.sin(root.ringTilt) + across * Math.cos(root.ringTilt)
        z: across > 0 ? 8 : 4
        scale: 0.85 + 0.15 * Math.sin(angle)
        opacity: Math.max(0.2, 1 - Math.abs(Math.cos(angle)))

        Shape {
            x: -24
            y: -24
            width: 48
            height: 48
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 24; centerY: 24; focalX: 24; focalY: 24
                    centerRadius: 24
                    GradientStop { position: 0; color: Qt.rgba(243 / 255, 180 / 255, 214 / 255, 0.55) }
                    GradientStop { position: 1; color: "transparent" }
                }
                PathAngleArc { centerX: 24; centerY: 24; radiusX: 24; radiusY: 24; sweepAngle: 360 }
            }
        }
        Rectangle {
            x: -2.5
            y: -2.5
            width: 5
            height: 5
            radius: 2.5
            color: "#ffe3f1"
        }
    }

    // Shooting stars cross the open sky to the right.
    Meteor {
        z: 9
        running: root.running
        area: Qt.rect(1700, 80, 700, 300)
    }
}
```

## `config/quickshell/nocturne/EclipseScene.qml`

```qml
import QtQuick
import QtQuick.Shapes
import "eclipse/layers.js" as Eclipse

// Eclipse: the nebula drifts, stars twinkle and glint, the corona's streamers sway and shimmer,
// the diamond-ring flare breathes, two backlit moons circle the eclipse, an aurora ripples along
// the near world's horizon, a satellite blinks across the sky and the odd shooting star falls.
WallpaperScene {
    id: root
    folder: "eclipse"
    layers: Eclipse.layers
    width: Eclipse.width
    height: Eclipse.height

    // Geometry from assets/wallpaper-eclipse.svg.
    readonly property point eclipse: Qt.point(1660, 600)
    readonly property real orbitTilt: -18 * Math.PI / 180
    readonly property point world: Qt.point(380, 2950)
    readonly property real worldRadius: 1680

    SceneLayer { scene: root; name: "sky"; z: 0 }
    // Zoomed a touch so its cropped edges never come into view as it turns.
    SceneLayer {
        scene: root
        name: "nebula"
        z: 1
        opacity: (1 + 0.25 * root.wave(17)) / info.boost
        zoom: 1.05 + 0.02 * root.wave(60)
        angle: 0.8 * root.wave(80)
    }
    Stars {
        scene: root
        stars: Eclipse.stars
        color: "#ddd0f5"
        z: 2
    }
    SceneLayer {
        scene: root
        name: "halo"
        z: 3
        pivot: root.eclipse
        opacity: (1 + 0.2 * root.wave(9)) / info.boost
        zoom: 1.02 + 0.02 * root.wave(9)
    }
    // Two sets of streamers swaying against each other read as a living corona.
    SceneLayer {
        scene: root
        name: "corona"
        z: 4
        pivot: root.eclipse
        angle: 2.5 * root.wave(47)
        opacity: 0.85 + 0.15 * root.wave(6.3)
    }
    SceneLayer {
        scene: root
        name: "wisps"
        z: 5
        pivot: root.eclipse
        angle: -3.5 * root.wave(37, 1)
        zoom: 1 + 0.04 * root.wave(11)
        opacity: 0.7 + 0.3 * root.wave(5.1, 2)
    }
    SceneLayer { scene: root; name: "orbits"; z: 6 }
    SceneLayer { scene: root; name: "body"; z: 8 }
    SceneLayer {
        scene: root
        name: "limb"
        z: 9
        opacity: 0.85 + 0.15 * root.wave(4.3)
    }
    SceneLayer {
        scene: root
        name: "bead"
        z: 10
        opacity: 0.8 + 0.2 * root.wave(5.7)
        zoom: 0.85 + 0.25 * (0.5 + 0.5 * root.wave(5.7))
    }
    SceneLayer { scene: root; name: "near"; z: 11 }

    // Moons on the dotted orbits, lit from behind: a rim on the side facing the eclipse that
    // closes into a ring as they cross it. On the far side they pass behind the eclipsing body.
    component Moon: Item {
        id: moon
        required property real orbitX
        required property real orbitY
        required property real period
        required property real phase
        required property real radius
        readonly property real angle: 2 * Math.PI * root.t / period + phase
        readonly property real along: orbitX * Math.cos(angle)
        readonly property real across: orbitY * Math.sin(angle)
        readonly property real toward: Math.atan2(root.eclipse.y - y, root.eclipse.x - x) * 180 / Math.PI
        readonly property real sweep: 110 + 250 * Math.max(0, 1 - Math.hypot(root.eclipse.x - x, root.eclipse.y - y) / 520)
        x: root.eclipse.x + along * Math.cos(root.orbitTilt) - across * Math.sin(root.orbitTilt)
        y: root.eclipse.y + along * Math.sin(root.orbitTilt) + across * Math.cos(root.orbitTilt)
        z: across > 0 ? 12 : 7

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#0b0911"
                strokeColor: "#2a1d3a"
                strokeWidth: 1
                PathAngleArc { radiusX: moon.radius; radiusY: moon.radius; sweepAngle: 360 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: "#efe4ff"
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    radiusX: moon.radius
                    radiusY: moon.radius
                    startAngle: moon.toward - moon.sweep / 2
                    sweepAngle: moon.sweep
                }
            }
        }
    }
    Moon { orbitX: 360; orbitY: 92; period: 55; phase: 0.6; radius: 13 }
    Moon { orbitX: 560; orbitY: 148; period: 95; phase: 3.4; radius: 8 }

    // A satellite crosses in a minute, then the sky stays empty for a while.
    Item {
        readonly property real progress: root.t % 140 / 60
        visible: progress < 1
        z: 13
        x: -40 + 2680 * progress
        y: 230 - 170 * progress
        Rectangle {
            x: -1.3
            y: -1.3
            width: 2.6
            height: 2.6
            radius: 1.3
            color: "#d8cbe8"
            opacity: 0.6
        }
        Rectangle {
            x: -2.5
            y: -2.5
            width: 5
            height: 5
            radius: 2.5
            color: "#ef8fa4"
            visible: root.t % 1.6 < 0.1
        }
    }

    Meteor {
        z: 14
        running: root.running
        area: Qt.rect(700, 60, 800, 250)
        heading: 150
    }

    SceneLayer { scene: root; name: "world"; z: 15 }
    SceneLayer {
        scene: root
        name: "air"
        z: 16
        opacity: 0.8 + 0.2 * root.wave(8)
    }

    // Aurora along the near world's horizon (eclipse/aurora.frag).
    ShaderEffect {
        z: 17
        y: 640
        width: 1600
        height: 960
        property real time: root.t
        property size size: Qt.size(width, height)
        property point center: Qt.point(root.world.x - x, root.world.y - y)
        property real radius: root.worldRadius
        // From the left edge of the scene to where the horizon leaves its bottom edge.
        property real arcFrom: -0.21
        property real arcTo: 0.545
        fragmentShader: "eclipse/aurora.frag.qsb"
    }
}
```

## `config/quickshell/nocturne/eclipse/aurora.frag`

```glsl
#version 440
// Aurora over the near world's horizon: curtains that fold and drift along the arc, fine rays,
// violet at the base turning rose higher up, and a faint glow on the night side below.
// Compiled to aurora.frag.qsb by tools/build-wallpapers.py.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 size;      // item size, scene units
    vec2 center;    // world center, relative to the item
    float radius;   // world radius
    float arcFrom;  // where the aurora starts and ends, radians from the top of the world
    float arcTo;
};

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = p - center;
    float h = length(d) - radius;
    float a = atan(d.x, -d.y);
    float u = (a - arcFrom) / (arcTo - arcFrom);
    float s = a * radius;

    float envelope = smoothstep(0.0, 0.22, u) * smoothstep(1.0, 0.7, u);
    float fold = 0.5 + 0.5 * sin(s * 0.011 - time * 0.45 + 1.8 * sin(s * 0.0037 + time * 0.12));
    float ripple = 0.5 + 0.5 * sin(s * 0.029 + time * 0.9 + 2.0 * sin(s * 0.006 - time * 0.3));
    float light = fold * (0.35 + 0.65 * ripple);
    float rays = 0.74 + 0.16 * sin(s * 0.21 + 4.0 * sin(s * 0.012 - time * 0.55)) + 0.1 * sin(s * 0.083 - time * 0.3);

    float top = 150.0 + 130.0 * (0.5 + 0.5 * sin(s * 0.005 + time * 0.2));
    // Curtains thin out well before the top of the item, so its edge never shows.
    float curtain = smoothstep(0.0, 22.0, h) * exp(-max(h, 0.0) / top) * (1.0 - smoothstep(top, top * 2.0, h)) * rays;
    float below = exp(min(h, 0.0) / 40.0) * (1.0 - step(0.0, h)) * 0.35;

    float alpha = 0.55 * envelope * light * (curtain + below) * smoothstep(0.0, 160.0, p.y);
    vec3 color = mix(vec3(0.77, 0.65, 1.0), vec3(0.89, 0.54, 0.75), smoothstep(30.0, 260.0, h));
    fragColor = vec4(color * alpha, alpha) * qt_Opacity;
}
```

## `config/quickshell/nocturne/Bar.qml`

```qml
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Floating capsules: launcher and clock left; workspaces and title centered; status right.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: 10; left: Theme.edge; right: Theme.edge }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "nocturne-bar"

    IdleInhibitor {
        window: bar
        enabled: Ui.caffeine
    }

    Item {
    id: content
    anchors.fill: parent
    HoverHandler {
        onPointChanged: bar.updateTip(point.position)
        onHoveredChanged: if (!hovered) bar.updateTip(null)
    }

    // ── Left ────────────────────────────────────────────────────────
    RowLayout {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            padding: 14
            tip: "Applications"
            onClicked: Ui.run("rofi -show drun")
            Glyph { text: "󰣇"; size: 20; color: Theme.violetBright }
        }

        Capsule {
            id: clockCapsule
            padding: 18
            active: Ui.calendarOpen
            tip: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
            onClicked: Ui.toggleCalendar()
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
            Label {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Ui.calendarOpen ? Theme.violetInk : "#eee8ff"
            }
        }
    }

    // ── Center ──────────────────────────────────────────────────────
    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.gap

        Repeater {
            model: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor?.name === bar.screen.name && (w.toplevels.values.length > 0 || w.focused || w.active))
                .sort((a, b) => a.id - b.id)
            delegate: Capsule {
                required property var modelData
                readonly property bool current: modelData.active && modelData.monitor?.name === bar.screen.name
                implicitWidth: current ? 52 : Theme.barHeight
                padding: 0
                active: current
                color: current ? Theme.violet : modelData.urgent ? Theme.rose : (hovered ? Theme.hover : Theme.glass)
                onClicked: modelData.activate()
                Label {
                    text: modelData.name
                    color: current || modelData.urgent ? Theme.violetInk : hovered ? "#eee8ff" : "#aa97bf"
                    font.family: Theme.mono
                    font.weight: current ? Font.Bold : Font.Normal
                }
            }
        }

        Capsule {
            id: title
            // The Wayland toplevel protocol knows the focused window from startup; nothing is
            // activated on an empty workspace. Show it on the bar of the screen it is on.
            readonly property var client: ToplevelManager.activeToplevel
            readonly property bool shown: !!client && client.activated && client.title !== "" && client.screens.some(s => s.name === bar.screen.name)
            visible: shown
            interactive: false
            padding: 16
            tip: shown ? client.title : ""
            Label {
                text: title.shown ? title.client.title : ""
                Layout.maximumWidth: 260
                font.family: Theme.mono
                color: "#c8b8dc"
            }
        }
    }

    // ── Right ───────────────────────────────────────────────────────
    RowLayout {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            visible: Sys.updates > 0
            padding: 12
            tip: Sys.updatesDetail
            onClicked: Ui.run(Ui.bin + "nocturne-updates open")
            Glyph { text: "󰚰"; color: Theme.violetBright }
            Label { text: Sys.updates; color: Theme.violetBright }
        }

        Capsule {
            padding: 12
            spacing: 12
            tip: `CPU ${Sys.cpu}% · Memory ${Sys.memoryDetail}`
            onClicked: Ui.run("kitty --class nocturne-monitor htop")
            RowLayout {
                spacing: 5
                Glyph { text: "󰻠"; size: 12; color: "#aaa0bb" }
                Label { text: Sys.cpu + "%"; font.pixelSize: 11; color: "#aaa0bb"; font.family: Theme.mono }
            }
            RowLayout {
                spacing: 5
                Glyph { text: "󰍛"; size: 12; color: "#aaa0bb" }
                Label { text: Sys.memory + "%"; font.pixelSize: 11; color: "#aaa0bb"; font.family: Theme.mono }
            }
        }

        Capsule {
            // nm-applet and blueman keep running for password and pairing prompts,
            // but the control center replaces their tray icons.
            readonly property var items: SystemTray.items.values.filter(i => !["nm-applet", "blueman"].includes(i.id))
            id: tray
            visible: items.length > 0
            interactive: false
            padding: 12
            spacing: 10
            Repeater {
                model: tray.items
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    implicitWidth: 18
                    implicitHeight: 18
                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        visible: false
                    }
                    // Tinted to match the bar; full color on hover.
                    MultiEffect {
                        anchors.fill: parent
                        source: trayIcon
                        saturation: trayMouse.containsMouse ? 0 : -1
                        colorization: trayMouse.containsMouse ? 0 : 0.35
                        colorizationColor: Theme.violet
                        brightness: trayMouse.containsMouse ? 0 : 0.1
                        Behavior on saturation { NumberAnimation { duration: Theme.fast } }
                        Behavior on colorization { NumberAnimation { duration: Theme.fast } }
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const item = trayItem.modelData;
                            if (m.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (m.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) {
                                    const p = trayItem.mapToItem(bar.contentItem, 0, trayItem.height + 14);
                                    item.display(bar, p.x, p.y);
                                }
                            } else
                                item.activate();
                        }
                        onWheel: w => trayItem.modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }

        // Network, Bluetooth, audio, battery and notifications open the control center.
        Capsule {
            id: controls
            padding: 14
            spacing: 13
            active: Ui.controlOpen
            tip: `${Devices.networkName} · Bluetooth ${Devices.bluetoothName}` + (Devices.hasBattery ? `\n${Devices.batteryDetail}` : "")
            onClicked: m => m.button === Qt.RightButton ? Ui.run("pavucontrol") : Ui.toggleControl()
            onScrolled: delta => Ui.run(Ui.bin + "nocturne-osd volume " + (delta > 0 ? "up" : "down"))
            readonly property color tint: Ui.controlOpen ? Theme.violetInk : Theme.textSoft

            Glyph { text: Devices.networkGlyph; color: Devices.networkName === "Offline" && !Ui.controlOpen ? Theme.dim : controls.tint }
            Glyph { text: Devices.bluetoothGlyph; color: !Devices.bluetoothOn && !Ui.controlOpen ? Theme.dim : controls.tint }
            RowLayout {
                spacing: 5
                Glyph { text: Devices.volumeGlyph; color: Devices.muted && !Ui.controlOpen ? Theme.dim : controls.tint }
                Label {
                    visible: !Devices.muted
                    text: Devices.volume + "%"
                    font.family: Theme.mono
                    color: controls.tint
                }
            }
            RowLayout {
                visible: Devices.hasBattery
                spacing: 5
                Glyph { text: Devices.batteryGlyph; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
                Label { text: Devices.batteryPercent + "%"; font.family: Theme.mono; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
            }
            Item {
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight
                Glyph {
                    id: bell
                    text: Notifs.dnd ? "󰂛" : Notifs.count ? "󰂚" : "󰂜"
                    color: Ui.controlOpen ? Theme.violetInk : Notifs.dnd ? Theme.dim : Theme.textSoft
                }
                Rectangle {
                    visible: Notifs.count > 0 && !Notifs.dnd
                    width: 6; height: 6; radius: 3
                    color: Ui.controlOpen ? Theme.violetInk : Theme.violetBright
                    anchors { right: bell.right; top: bell.top; rightMargin: -2; topMargin: 1 }
                }
            }
        }

        Capsule {
            padding: 14
            tip: "Session & power"
            onClicked: Ui.openSession()
            Glyph { text: "󰐥"; size: 16; color: Theme.violetBright }
        }
    }

    }

    // ── Tooltip ─────────────────────────────────────────────────────
    property Item tipTarget: null
    function updateTip(pos) {
        const target = pos ? capsuleAt(pos) : null;
        if (target !== tipTarget) {
            tipTarget = target;
            tipWindow.visible = false;
            tipDelay.restart();
        }
    }
    // Innermost item under the pointer that declares a tooltip.
    function capsuleAt(pos) {
        let found = null, item = content, p = pos;
        for (let child = item.childAt(p.x, p.y); child; child = item.childAt(p.x, p.y)) {
            p = item.mapToItem(child, p.x, p.y);
            if (child.tip !== undefined)
                found = child;
            item = child;
        }
        return found;
    }
    Timer {
        id: tipDelay
        interval: 550
        onTriggered: tipWindow.visible = !!bar.tipTarget && bar.tipTarget.tip !== ""
    }
    PopupWindow {
        id: tipWindow
        anchor.item: bar.tipTarget ?? bar.contentItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        implicitWidth: tipText.implicitWidth + 24
        implicitHeight: tipText.implicitHeight + 16
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: Theme.glassStrong
            border.color: Theme.lineStrong
            Label {
                id: tipText
                anchors.centerIn: parent
                text: bar.tipTarget?.tip ?? ""
                color: "#e8e1f3"
                elide: Text.ElideNone
            }
        }
    }
}
```

## `config/quickshell/nocturne/CalendarPanel.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Month view under the clock.
Panel {
    id: root
    anchors { top: true; left: true }
    margins.left: Theme.edge
    sheetWidth: 320
    open: Ui.calendarOpen
    onDismissed: Ui.dismiss()

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    onOpenChanged: if (open) { today = new Date(); month = today.getMonth(); year = today.getFullYear(); }
    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 10

        Label {
            text: Qt.formatDate(root.today, "dddd")
            font.pixelSize: 11
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.violet
        }
        Label {
            text: Qt.formatDate(root.today, "d MMMM yyyy")
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                font.weight: Font.DemiBold
                color: Theme.textSoft
            }
            Repeater {
                model: [{ glyph: "󰅁", delta: -1 }, { glyph: "󰅂", delta: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: navArea.containsMouse ? Theme.hover : "transparent"
                    Glyph { anchors.centerIn: parent; text: modelData.glyph; color: Theme.textSoft }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shift(modelData.delta)
                    }
                }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Label {
                required property string shortName
                text: shortName.slice(0, 2)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 34 + 5 * 2
            month: root.month
            year: root.year
            locale: Qt.locale()
            spacing: 2
            delegate: Rectangle {
                required property var model
                readonly property bool isToday: model.today
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: isToday ? Theme.violet : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: model.day
                    font.weight: parent.isToday ? Font.Bold : Font.Normal
                    color: parent.isToday ? Theme.violetInk : model.month === root.month ? Theme.text : Theme.dim
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Capsule.qml`

```qml
import QtQuick
import QtQuick.Layouts

// A floating glass pill; children are laid out in a row.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 13
    property string tip: ""
    property bool interactive: true
    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: height / 2
    color: active ? Theme.violet : (interactive && hovered ? Theme.hover : Theme.glass)
    border.width: 1
    border.color: active ? Theme.violetBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // Declared before the row so it sits underneath: children with their own
    // mouse handling (tray icons) receive their clicks, plain contents fall through.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
```

## `config/quickshell/nocturne/ControlCenter.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Quick settings, sliders, media and notification history, under the status capsule.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge
    sheetWidth: 400
    open: Ui.controlOpen
    onDismissed: Ui.dismiss()

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    property string uptime: ""
    onOpenChanged: if (open) { uptimeFile.reload(); Sys.refreshBrightness(); }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = Number(text().split(" ")[0]), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = h ? `up ${h} h ${m} min` : `up ${m} min`;
        }
    }

    // One page at a time: the main view, or Wi-Fi / Bluetooth settings.
    ColumnLayout {
        id: pages
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 0

        Connections {
            target: Ui
            function onControlPageChanged() { pageIn.restart(); }
        }
        ParallelAnimation {
            id: pageIn
            NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
            NumberAnimation { target: pages; property: "x"; from: Ui.controlPage === "main" ? -6 : 42; to: 18; duration: Theme.slow; easing.type: Easing.OutExpo }
        }

        WifiPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "wifi"
            active: root.open && visible
        }

        BluetoothPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "bluetooth"
            active: root.open && visible
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Ui.controlPage === "main"
            spacing: 14

            // Header: who, how long, and session shortcuts.
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.violet }
                        GradientStop { position: 1; color: Theme.violetDeep }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: Quickshell.env("USER").charAt(0).toUpperCase()
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: Theme.violetInk
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: Quickshell.env("USER"); font.pixelSize: 14; font.weight: Font.DemiBold }
                    Label { text: root.uptime; font.pixelSize: 11; color: Theme.muted }
                }
                Repeater {
                    model: [
                        { glyph: "󰸉", tip: "Next wallpaper", run: () => Ui.run(Ui.bin + "nocturne-wallpaper next") },
                        { glyph: "󰌾", tip: "Lock", run: () => { Ui.close(); Ui.run("loginctl lock-session"); } },
                        { glyph: "󰐥", tip: "Session", run: () => Ui.openSession() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: headerArea.containsMouse ? Theme.hover : Theme.raised
                        border.color: Theme.line
                        Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 15; color: Theme.violetBright }
                        MouseArea {
                            id: headerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.run()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.networkGlyph
                    title: Devices.wifiDevice ? "Wi-Fi" : "Network"
                    subtitle: Devices.networkName
                    on: Devices.wifiDevice ? Networking.wifiEnabled : Devices.wired
                    hasMore: true
                    onToggled: Devices.wifiDevice ? Networking.wifiEnabled = !Networking.wifiEnabled : Ui.controlPage = "wifi"
                    onMore: Ui.controlPage = "wifi"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.bluetoothGlyph
                    title: "Bluetooth"
                    subtitle: Devices.bluetoothName
                    on: Devices.bluetoothOn
                    available: !!Devices.adapter
                    hasMore: true
                    onToggled: Devices.adapter.enabled = !Devices.adapter.enabled
                    onMore: Ui.controlPage = "bluetooth"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Notifs.dnd ? "󰂛" : "󰂚"
                    title: "Do not disturb"
                    subtitle: Notifs.dnd ? "Only critical alerts" : "Off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Ui.caffeine ? "󰅶" : "󰛊"
                    title: "Stay awake"
                    subtitle: Ui.caffeine ? "Idle lock paused" : "Off"
                    on: Ui.caffeine
                    onToggled: Ui.caffeine = !Ui.caffeine
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                SliderRow {
                    Layout.fillWidth: true
                    glyph: Devices.volumeGlyph
                    value: Devices.volume
                    muted: Devices.muted
                    onMoved: v => Devices.setVolume(v)
                    onGlyphClicked: if (Devices.sink) Devices.sink.muted = !Devices.sink.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: !!Devices.source
                    glyph: Devices.micMuted ? "󰍭" : "󰍬"
                    value: Devices.source ? Math.round(Devices.source.volume * 100) : 0
                    muted: Devices.micMuted
                    onMoved: v => { Devices.source.muted = false; Devices.source.volume = v / 100; }
                    onGlyphClicked: Devices.source.muted = !Devices.source.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: Sys.brightness >= 0
                    glyph: "󰃟"
                    value: Sys.brightness
                    onMoved: v => Sys.setBrightness(v)
                }
            }

            // Media
            Rectangle {
                Layout.fillWidth: true
                visible: !!root.player
                implicitHeight: 76
                radius: Theme.radius
                color: Theme.raised
                border.color: Theme.line
                RowLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 12
                    ClippingRectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 12
                        color: Theme.hover
                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: !root.player?.trackArtUrl
                            text: "󰎆"
                            size: 22
                            color: Theme.violetBright
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { Layout.fillWidth: true; text: root.player?.trackTitle || root.player?.identity || ""; font.weight: Font.DemiBold }
                        Label { Layout.fillWidth: true; text: root.player?.trackArtist || root.player?.identity || ""; font.pixelSize: 11; color: Theme.muted }
                    }
                    Repeater {
                        model: [
                            { glyph: "󰒮", run: () => root.player.previous(), ok: root.player?.canGoPrevious },
                            { glyph: root.player?.isPlaying ? "󰏤" : "󰐊", run: () => root.player.togglePlaying(), ok: root.player?.canTogglePlaying, main: true },
                            { glyph: "󰒭", run: () => root.player.next(), ok: root.player?.canGoNext }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: modelData.main ? 38 : 30
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            opacity: modelData.ok ? 1 : 0.4
                            color: modelData.main ? Theme.violet : mediaArea.containsMouse ? Theme.hover : "transparent"
                            Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 16; color: modelData.main ? Theme.violetInk : Theme.text }
                            MouseArea {
                                id: mediaArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!modelData.ok
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.run()
                            }
                        }
                    }
                }
            }

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Label {
                    Layout.fillWidth: true
                    text: Notifs.count ? `Notifications · ${Notifs.count}` : "Notifications"
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: Theme.muted
                }
                Label {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    font.pixelSize: 11
                    color: clearArea.containsMouse ? Theme.violetBright : Theme.violet
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clear()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Notifs.count ? Math.min(contentHeight, 340) : 0
                visible: Notifs.count > 0
                clip: true
                spacing: 8
                model: Notifs.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    required property var modelData
                    width: ListView.view.width
                    notification: modelData
                    compact: true
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                visible: Notifs.count === 0
                spacing: 4
                Glyph { Layout.fillWidth: true; text: "󰂜"; size: 26; color: Theme.dim }
                Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "All caught up"; color: Theme.muted }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Devices.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Live device state, with the glyphs the bar and control center show for it.
Singleton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    readonly property int volume: sink ? Math.round(sink.volume * 100) : 0
    readonly property bool muted: sink?.muted ?? true
    readonly property string volumeGlyph: muted ? "󰝟" : volume > 60 ? "󰕾" : volume > 25 ? "󰖀" : "󰕿"
    readonly property bool micMuted: source?.muted ?? true
    function setVolume(percent) {
        if (!sink)
            return;
        sink.muted = false;
        sink.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property string networkName: wifiNetwork ? wifiNetwork.name : wired ? "Wired" : "Offline"
    // Signal strength as 0–1, whichever scale the backend reports.
    function strength(network) {
        return network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength;
    }
    function signalGlyph(network) {
        const s = strength(network);
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }
    readonly property string networkGlyph: {
        if (wifiNetwork)
            return signalGlyph(wifiNetwork);
        return wired ? "󰈀" : Networking.wifiEnabled ? "󰤯" : "󰤭";
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property var bluetoothConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string bluetoothGlyph: !adapter ? "󰂲" : !bluetoothOn ? "󰂲" : bluetoothConnected.length ? "󰂱" : "󰂯"
    readonly property string bluetoothName: !adapter ? "No adapter" : !bluetoothOn ? "Off" : bluetoothConnected.length ? bluetoothConnected[0].name : "On"

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isPresent && battery.type === UPowerDeviceType.Battery
    readonly property int batteryPercent: !hasBattery ? 0 : Math.round(battery.percentage > 1 ? battery.percentage : battery.percentage * 100)
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge)
    readonly property string batteryGlyph: charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(batteryPercent / 20))]
    readonly property color batteryColor: charging ? Theme.green : batteryPercent <= 10 ? Theme.rose : batteryPercent <= 25 ? Theme.amber : Theme.textSoft
    readonly property string batteryDetail: {
        if (!hasBattery)
            return "";
        const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!seconds)
            return charging ? "Charging" : "On battery";
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return `${h ? h + " h " : ""}${m} min ${charging ? "until full" : "left"}`;
    }
}
```

## `config/quickshell/nocturne/Glyph.qml`

```qml
import QtQuick

// A Nerd Font icon.
Text {
    property real size: 14
    color: Theme.textSoft
    font.family: Theme.mono
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
```

## `config/quickshell/nocturne/Label.qml`

```qml
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: 12
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
```

## `config/quickshell/nocturne/NotificationCard.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// One notification: icon, app, summary, body and actions. Click runs the default action.
Rectangle {
    id: root

    required property var notification
    property bool compact: false
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + 28
    radius: Theme.radius
    color: compact ? (area.containsMouse ? Theme.hover : Theme.raised) : Theme.glassStrong
    border.color: critical ? Theme.rose : compact ? Theme.line : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const n = root.notification;
            const action = n.actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            n.dismiss();
        }
    }

    RowLayout {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource !== ""
                IconImage {
                    anchors.fill: parent
                    source: root.iconSource
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource === ""
                Glyph {
                    anchors.centerIn: parent
                    text: root.critical ? "󰀦" : "󰂚"
                    size: 17
                    color: root.critical ? Theme.rose : Theme.violetBright
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: root.notification?.appName || "Notification"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: root.critical ? Theme.rose : Theme.violet
                }
                Glyph {
                    text: "󰅖"
                    size: 13
                    color: close.containsMouse ? Theme.text : Theme.dim
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 4
                color: Theme.textSoft
                linkColor: Theme.violetBright
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: actionLabel.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: actionArea.containsMouse ? Theme.violet : Theme.raised
                        border.color: Theme.line
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: 11
                            color: actionArea.containsMouse ? Theme.violetInk : Theme.text
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke();
                                root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/NotificationPopups.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland

// New notifications slide in at the top right, then retire to the control center.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 10 + Theme.gap; right: Theme.edge }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: Math.max(1, column.height)
    visible: Notifs.popups.length > 0 && !Ui.controlOpen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-popups"
    // Only the cards take input; the rest of the column passes clicks through.
    mask: Region { item: column }

    Column {
        id: column
        width: parent.width
        spacing: 8
        move: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }

        Repeater {
            model: Notifs.popups
            delegate: NotificationCard {
                id: card
                required property var modelData
                width: column.width
                notification: modelData
                opacity: 0
                x: 40
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

                Timer {
                    interval: Notifs.timeout(card.modelData)
                    running: interval > 0 && !card.hoveredCard
                    onTriggered: Notifs.hidePopup(card.modelData)
                }
                readonly property bool hoveredCard: hover.hovered
                HoverHandler { id: hover }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Notifs.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon: popups for new notifications, history for the control center.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    // Newest first.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
    }
    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    // Milliseconds a popup stays up (expireTimeout is already in ms); critical ones wait for the user.
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? Math.min(n.expireTimeout, 20000) : 6000;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.hidePopup(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 4);
        }
    }
}
```

## `config/quickshell/nocturne/Osd.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Volume / microphone / brightness feedback, floating above the bottom edge.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 58
    visible: Ui.osdVisible || pill.opacity > 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-osd"

    readonly property string glyph: {
        if (Ui.osdKind === "brightness")
            return Ui.osdValue > 66 ? "󰃠" : Ui.osdValue > 33 ? "󰃟" : "󰃞";
        if (Ui.osdKind === "microphone")
            return Ui.osdMuted ? "󰍭" : "󰍬";
        return Ui.osdMuted ? "󰝟" : Ui.osdValue > 60 ? "󰕾" : Ui.osdValue > 25 ? "󰖀" : "󰕿";
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: Ui.osdVisible ? 1 : 0
        scale: Ui.osdVisible ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 14
            Glyph {
                text: root.glyph
                size: 19
                color: Ui.osdMuted ? Theme.dim : Theme.violetBright
                Layout.preferredWidth: 22
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.raised
                Rectangle {
                    width: parent.width * (Ui.osdMuted ? 0 : Ui.osdValue / 100)
                    height: parent.height
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.violetDeep }
                        GradientStop { position: 1; color: Theme.violet }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                }
            }
            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Ui.osdMuted ? "Muted" : Ui.osdValue + "%"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.textSoft
            }
        }
    }
}
```

## `config/quickshell/nocturne/Panel.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A glass sheet that drops in under the bar and closes on Escape or a click outside.
PanelWindow {
    id: panel

    property bool open: false
    property int sheetWidth: 380
    default property alias content: sheet.data
    property alias sheet: sheet
    signal dismissed()

    screen: Ui.screen
    visible: open || sheet.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sheetWidth
    // A fixed-height surface; only the sheet takes input, so it can grow and shrink smoothly.
    implicitHeight: (screen?.height ?? 1080) - margins.top - Theme.edge
    mask: Region { item: sheet }
    margins.top: Theme.barHeight + 10 + Theme.gap
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nocturne-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.dismissed()
    }

    Rectangle {
        id: sheet
        width: parent.width
        // Content sits at x/y = 18; keep the same padding below it.
        implicitHeight: childrenRect.y + childrenRect.height + 18
        height: implicitHeight
        clip: true
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: panel.open ? 1 : 0
        y: panel.open ? 0 : -14
        focus: panel.open
        Keys.onEscapePressed: panel.dismissed()
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
}
```

## `config/quickshell/nocturne/SessionMenu.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Full-screen session overlay. Destructive choices need a second press to confirm.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.sessionOpen || backdrop.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-session"
    WlrLayershell.keyboardFocus: Ui.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var entries: [
        { glyph: "󰌾", label: "Lock", command: "loginctl lock-session" },
        { glyph: "󰤄", label: "Suspend", command: "systemctl suspend" },
        { glyph: "󰍃", label: "Log out", command: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true },
        { glyph: "󰜉", label: "Restart", command: "systemctl reboot", confirm: true },
        { glyph: "󰐥", label: "Shut down", command: "systemctl poweroff", confirm: true }
    ]
    property int selected: 0
    property int armed: -1

    Connections {
        target: Ui
        function onSessionOpenChanged() {
            root.selected = 0;
            root.armed = -1;
        }
    }

    function choose(index) {
        const entry = entries[index];
        if (entry.confirm && armed !== index) {
            armed = index;
            selected = index;
            return;
        }
        Ui.sessionOpen = false;
        Ui.run(entry.command);
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(7 / 255, 7 / 255, 11 / 255, 0.62)
        opacity: Ui.sessionOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        focus: Ui.sessionOpen
        Keys.onEscapePressed: Ui.sessionOpen = false
        Keys.onLeftPressed: { root.selected = (root.selected + 4) % 5; root.armed = -1; }
        Keys.onRightPressed: { root.selected = (root.selected + 1) % 5; root.armed = -1; }
        Keys.onTabPressed: { root.selected = (root.selected + 1) % 5; root.armed = -1; }
        Keys.onReturnPressed: root.choose(root.selected)
        Keys.onEnterPressed: root.choose(root.selected)
        Keys.onSpacePressed: root.choose(root.selected)

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.sessionOpen = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 26
            scale: Ui.sessionOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "S E S S I O N"
                font.pixelSize: 12
                color: Theme.violet
            }

            RowLayout {
                spacing: 14
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index
                        readonly property bool isArmed: root.armed === index
                        implicitWidth: 132
                        implicitHeight: 140
                        radius: Theme.radiusLarge
                        color: isArmed ? Qt.rgba(239 / 255, 143 / 255, 164 / 255, 0.22) : current ? Theme.raised : Theme.glassStrong
                        border.width: current ? 2 : 1
                        border.color: isArmed ? Theme.rose : current ? Theme.violet : Theme.line
                        scale: current ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Glyph {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.glyph
                                size: 34
                                color: tile.isArmed ? Theme.rose : tile.current ? Theme.violetBright : Theme.textSoft
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.isArmed ? "Confirm" : tile.modelData.label
                                font.pixelSize: 13
                                font.weight: tile.current ? Font.DemiBold : Font.Normal
                                color: tile.isArmed ? Theme.rose : Theme.text
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (root.armed !== tile.index) { root.selected = tile.index; root.armed = -1; }
                            onClicked: root.choose(tile.index)
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.armed >= 0 ? `Press again to ${root.entries[root.armed].label.toLowerCase()} · Esc to cancel` : "← → to choose · Enter to select · Esc to close"
                font.pixelSize: 11
                color: root.armed >= 0 ? Theme.rose : Theme.muted
            }
        }
    }
}
```

## `config/quickshell/nocturne/SliderRow.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Glyph button (mute) plus a soft violet slider, 0–100.
RowLayout {
    id: root

    property string glyph
    property real value: 0
    property bool muted: false
    signal moved(real value)
    signal glyphClicked()

    spacing: 10

    Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        color: button.containsMouse ? Theme.hover : Theme.raised
        Glyph {
            anchors.centerIn: parent
            text: root.glyph
            size: 16
            color: root.muted ? Theme.dim : Theme.violetBright
        }
        MouseArea {
            id: button
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.glyphClicked()
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: 100
        value: root.value
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 8
            radius: 4
            color: Theme.raised
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.violetDeep }
                    GradientStop { position: 1; color: root.muted ? Theme.dim : Theme.violet }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 18 : 16
            height: width
            radius: width / 2
            color: "#f3edff"
            border.color: Theme.violet
            border.width: 2
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    Label {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value) + "%"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.muted
    }
}
```

## `config/quickshell/nocturne/Sys.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polled system state: CPU, memory, backlight and pending updates.
Singleton {
    id: root

    property int cpu: 0
    property int memory: 0
    property string memoryDetail: ""
    property int brightness: -1 // -1 when the machine has no backlight
    property int updates: 0
    property string updatesDetail: ""

    property var lastCpu: null

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root.lastCpu.idle) / dt)) : 0;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memory = Math.round(100 * used / total);
            root.memoryDetail = `${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GiB`;
        }
    }

    // brightnessctl -m prints: device,class,current,percent%,max
    Process {
        id: backlight
        command: ["brightnessctl", "-m", "--class=backlight", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                root.brightness = parts.length >= 4 ? parseInt(parts[3]) : -1;
            }
        }
    }
    function refreshBrightness() {
        backlight.running = true;
    }
    function setBrightness(percent) {
        root.brightness = Math.max(1, Math.round(percent));
        brightnessDebounce.restart();
    }
    Timer {
        id: brightnessDebounce
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "--class=backlight", "--min-value=1", "set", root.brightness + "%"])
    }

    Process {
        id: updateCheck
        command: [Ui.bin + "nocturne-updates", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const status = JSON.parse(text);
                    root.updates = parseInt(status.text.replace(/\D/g, "")) || 0;
                    root.updatesDetail = status.tooltip.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
                } catch (e) {
                    root.updates = 0;
                }
            }
        }
    }
    function refreshUpdates() {
        updateCheck.running = true;
    }
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshUpdates()
    }
}
```

## `config/quickshell/nocturne/Theme.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell

// NOCTURNE palette, type and geometry, shared by every shell surface.
Singleton {
    readonly property color base: "#0d0a12"
    readonly property color surface: "#100d18"
    readonly property color glass: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.72)
    readonly property color glassStrong: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.88)
    readonly property color raised: Qt.rgba(40 / 255, 30 / 255, 58 / 255, 0.55)
    readonly property color hover: "#38264f"
    readonly property color line: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16)
    readonly property color lineStrong: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.34)
    readonly property color violet: "#b69af7"
    readonly property color violetBright: "#c4a5ff"
    readonly property color violetDeep: "#6d28d9"
    readonly property color violetInk: "#100b1b"
    readonly property color text: "#e9e1f5"
    readonly property color textSoft: "#c8bbde"
    readonly property color muted: "#8f809f"
    readonly property color dim: "#6c627b"
    readonly property color rose: "#ef8fa4"
    readonly property color green: "#a5ccb3"
    readonly property color amber: "#e5c89a"

    readonly property string sans: "Inter"
    readonly property string mono: "JetBrainsMono Nerd Font"

    readonly property int radiusLarge: 22
    readonly property int radius: 16
    readonly property int radiusSmall: 12
    readonly property int barHeight: 40
    readonly property int gap: 8
    readonly property int edge: 14

    readonly property int fast: 160
    readonly property int normal: 260
    readonly property int slow: 420
}
```

## `config/quickshell/nocturne/Tile.qml`

```qml
import QtQuick
import QtQuick.Layouts

// Quick-settings toggle: click the body to toggle, the chevron for more.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property bool on: false
    property bool available: true
    property bool hasMore: false
    signal toggled()
    signal more()

    implicitHeight: 62
    radius: Theme.radius
    color: on ? Theme.violet : body.containsMouse ? Theme.hover : Theme.raised
    border.color: on ? Theme.violetBright : Theme.line
    opacity: available ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: root.hasMore ? 6 : 14 }
        spacing: 11
        Glyph {
            text: root.glyph
            size: 19
            color: root.on ? Theme.violetInk : Theme.violetBright
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: root.on ? Theme.violetInk : Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: 11
                color: root.on ? Qt.rgba(16 / 255, 11 / 255, 27 / 255, 0.7) : Theme.muted
            }
        }
        Rectangle {
            visible: root.hasMore
            implicitWidth: 30
            implicitHeight: 44
            radius: Theme.radiusSmall
            color: more.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Glyph {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.on ? Theme.violetInk : Theme.muted
            }
            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more()
            }
        }
    }
}
```

## `config/quickshell/nocturne/Ui.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which surfaces are open, and the screen they open on.
Singleton {
    id: root

    property bool controlOpen: false
    property string controlPage: "main" // main, wifi or bluetooth
    property bool calendarOpen: false
    property bool sessionOpen: false
    property bool caffeine: false

    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    // Panels follow the monitor that has focus.
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    function close() {
        controlOpen = false;
        calendarOpen = false;
    }
    // A click outside a panel closes it; ignore that same click reopening it from the bar.
    property double closedAt: 0
    function dismiss() {
        closedAt = Date.now();
        close();
    }
    function toggleControl() {
        const reopen = !controlOpen && Date.now() - closedAt > 250;
        close();
        if (reopen)
            controlPage = "main";
        controlOpen = reopen;
    }
    function openControl(page) {
        close();
        controlPage = page;
        controlOpen = true;
    }
    function toggleCalendar() {
        const reopen = !calendarOpen && Date.now() - closedAt > 250;
        close();
        calendarOpen = reopen;
    }
    function openSession() {
        close();
        sessionOpen = true;
    }

    function showOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(100, value));
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    function run(command) {
        Quickshell.execDetached(["bash", "-c", command]);
    }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
}
```

## `config/quickshell/nocturne/BluetoothPage.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth devices: discover, pair, connect, disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var adapter: Devices.adapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var all: Bluetooth.devices.values
    readonly property var paired: all.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices only advertise their address; leave them out.
    readonly property var available: all.filter(d => !d.paired && !d.bonded && d.deviceName && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name))
        .sort((a, b) => a.name.localeCompare(b.name))
    property string expanded: ""
    property string pairingAddress: ""

    spacing: 12

    // Discover only while the page is on screen.
    function updateDiscovery() {
        if (adapter && adapter.enabled && adapter.discovering !== active)
            adapter.discovering = active;
    }
    onActiveChanged: { updateDiscovery(); if (!active) expanded = ""; }
    onPoweredChanged: updateDiscovery()

    function glyphFor(device) {
        const icon = device.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone"))
            return "󰋋";
        if (icon.includes("audio") || icon.includes("speaker"))
            return "󰓃";
        if (icon.includes("mouse"))
            return "󰍽";
        if (icon.includes("keyboard"))
            return "󰌌";
        if (icon.includes("gaming") || icon.includes("joystick"))
            return "󰊴";
        if (icon.includes("phone"))
            return "󰏲";
        if (icon.includes("computer"))
            return "󰌢";
        return "󰂯";
    }
    function statusFor(device) {
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (device.connected)
            return device.batteryAvailable ? `Connected · ${Math.round(device.battery > 1 ? device.battery : device.battery * 100)}% battery` : "Connected";
        return "Not connected";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        status: !root.adapter ? "No adapter" : !root.powered ? "Off" : root.adapter.discovering ? "On · searching for devices" : "On"
        showSwitch: !!root.adapter
        checked: root.powered
        onBack: Ui.controlPage = "main"
        onToggled: root.adapter.enabled = !root.adapter.enabled
    }

    component SectionTitle: Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    Flickable {
        id: scroller
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 400)
        visible: root.powered
        contentHeight: sections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: scroller.contentHeight > scroller.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: sections
            width: scroller.width
            spacing: 4

            SectionTitle { visible: root.paired.length > 0; text: "My devices" }
            Repeater {
                model: root.paired
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    readonly property bool changing: dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: root.statusFor(dev)
                    highlighted: dev.connected
                    busy: changing
                    expanded: root.expanded === dev.address
                    onClicked: {
                        const open = root.expanded === dev.address;
                        root.expanded = open ? "" : dev.address;
                        // One click connects; the row stays open for Disconnect and Forget.
                        if (!open && !dev.connected && !changing)
                            dev.connect();
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        PillButton {
                            text: row.dev.connected ? "Disconnect" : "Connect"
                            primary: !row.dev.connected
                            available: !row.changing
                            onClicked: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                        }
                        PillButton {
                            text: "Forget"
                            danger: true
                            onClicked: { root.expanded = ""; row.dev.forget(); }
                        }
                    }
                }
            }

            SectionTitle {
                Layout.topMargin: root.paired.length ? 10 : 2
                text: root.available.length ? "Available devices" : "Searching for devices…"
            }
            Repeater {
                model: root.available
                delegate: ListRow {
                    id: candidate
                    required property var modelData
                    readonly property var dev: modelData
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: dev.pairing ? "Pairing…" : "Click to pair"
                    busy: dev.pairing
                    onClicked: {
                        if (dev.pairing)
                            return;
                        root.pairingAddress = dev.address;
                        dev.pair();
                    }
                    // Trust and connect as soon as pairing completes.
                    Connections {
                        target: candidate.dev
                        function onPairedChanged() {
                            if (candidate.dev.paired && root.pairingAddress === candidate.dev.address) {
                                root.pairingAddress = "";
                                candidate.dev.trusted = true;
                                candidate.dev.connect();
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.powered
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰂲"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.adapter ? "This computer has no Bluetooth adapter" : "Bluetooth is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        visible: !!root.adapter
        text: "Advanced Bluetooth settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("blueman-manager"); }
        }
    }
}
```

## `config/quickshell/nocturne/ListRow.qml`

```qml
import QtQuick
import QtQuick.Layouts

// A device or network row; `expanded` reveals the extra content below it.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property string trailing: "" // glyph on the right, e.g. a lock
    property bool highlighted: false
    property bool busy: false
    property bool expanded: false
    property bool danger: false
    default property alias extra: extraColumn.data
    signal clicked()

    implicitHeight: column.implicitHeight + 16
    radius: Theme.radiusSmall
    color: highlighted ? Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16) : area.containsMouse || expanded ? Theme.raised : "transparent"
    border.color: highlighted ? Theme.lineStrong : expanded ? Theme.line : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    clip: true

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 11
            Glyph {
                Layout.preferredWidth: 22
                text: root.glyph
                size: 17
                color: root.highlighted ? Theme.violetBright : Theme.textSoft
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: root.title; font.weight: root.highlighted ? Font.DemiBold : Font.Normal }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: 11
                    color: root.danger ? Theme.rose : root.highlighted ? Theme.violet : Theme.muted
                }
            }
            Glyph {
                visible: root.busy
                text: "󰔟"
                size: 14
                color: Theme.violet
                RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
            }
            Glyph {
                visible: root.trailing !== "" && !root.busy
                text: root.trailing
                size: 13
                color: Theme.dim
            }
        }

        ColumnLayout {
            id: extraColumn
            Layout.fillWidth: true
            Layout.leftMargin: 33
            visible: root.expanded
            spacing: 8
        }
    }
}
```

## `config/quickshell/nocturne/PageHeader.qml`

```qml
import QtQuick
import QtQuick.Layouts

// Back arrow, title, optional status text and an on/off switch.
RowLayout {
    id: root

    property string title
    property string status
    property bool checked: false
    property bool showSwitch: true
    signal back()
    signal toggled()

    spacing: 10

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: backArea.containsMouse ? Theme.hover : Theme.raised
        border.color: Theme.line
        Glyph { anchors.centerIn: parent; text: "󰁍"; size: 15; color: Theme.textSoft }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        // fillWidth on the labels lets the column (and so the row) stretch to the switch.
        Label { Layout.fillWidth: true; text: root.title; font.pixelSize: 15; font.weight: Font.DemiBold }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.status; font.pixelSize: 11; color: Theme.muted }
    }
    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
```

## `config/quickshell/nocturne/PillButton.qml`

```qml
import QtQuick

// Small text button used inside expanded rows.
Rectangle {
    id: root

    property string text
    property bool primary: false
    property bool danger: false
    property bool available: true
    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30
    radius: 15
    opacity: available ? 1 : 0.45
    color: primary ? (area.containsMouse ? Theme.violetBright : Theme.violet) : area.containsMouse ? Theme.hover : Theme.raised
    border.color: danger ? Qt.rgba(239 / 255, 143 / 255, 164 / 255, 0.5) : primary ? Theme.violetBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.primary ? Theme.violetInk : root.danger ? Theme.rose : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
```

## `config/quickshell/nocturne/Switch.qml`

```qml
import QtQuick

// Pill switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    radius: 12
    color: checked ? Theme.violet : Theme.raised
    border.color: checked ? Theme.violetBright : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.violetInk : Theme.textSoft
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
```

## `config/quickshell/nocturne/WifiPage.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

// Wi-Fi networks: scan, connect (with a password when needed), disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var device: Devices.wifiDevice
    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (Devices.strength(b) - Devices.strength(a)))
    property string expanded: ""
    property var failures: ({}) // network name → message

    spacing: 12

    // Scan only while the page is on screen.
    function updateScanner() {
        if (device)
            device.scannerEnabled = active && Networking.wifiEnabled;
    }
    onActiveChanged: { updateScanner(); if (!active) expanded = ""; }
    onDeviceChanged: updateScanner()
    Connections {
        target: Networking
        function onWifiEnabledChanged() { root.updateScanner(); }
    }

    function fail(name, message) {
        failures = Object.assign({}, failures, { [name]: message });
    }
    function clearFailure(name) {
        const next = Object.assign({}, failures);
        delete next[name];
        failures = next;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        status: !root.device ? "No Wi-Fi adapter" : !Networking.wifiEnabled ? "Off" : Devices.wifiNetwork ? `Connected to ${Devices.wifiNetwork.name}` : "Not connected"
        showSwitch: !!root.device
        checked: Networking.wifiEnabled
        onBack: Ui.controlPage = "main"
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Wired connection, while a cable is plugged in.
    ListRow {
        Layout.fillWidth: true
        visible: Devices.wired
        glyph: "󰈀"
        title: "Ethernet"
        subtitle: "Connected"
        highlighted: true
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: !!root.device && Networking.wifiEnabled
        text: root.networks.length ? "Networks" : "Searching for networks…"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: !!root.device && Networking.wifiEnabled
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.networks
        ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        delegate: ListRow {
            id: row
            required property var modelData
            readonly property var net: modelData
            readonly property bool secured: net.security !== WifiSecurityType.Open
            readonly property bool connecting: net.stateChanging || net.state === ConnectionState.Connecting
            readonly property string failure: root.failures[net.name] ?? ""

            width: ListView.view.width
            glyph: Devices.signalGlyph(net)
            title: net.name
            subtitle: failure !== "" ? failure : net.connected ? "Connected" : connecting ? "Connecting…" : net.known ? "Saved" : secured ? "Secured" : "Open"
            danger: failure !== ""
            trailing: secured ? "󰌾" : ""
            highlighted: net.connected
            busy: connecting
            expanded: root.expanded === net.name

            function connect() {
                root.clearFailure(net.name);
                if (net.known || !secured)
                    net.connect();
                else if (password.text !== "")
                    net.connectWithPsk(password.text);
            }

            onClicked: {
                const open = root.expanded === net.name;
                root.expanded = open ? "" : net.name;
                // Saved and open networks connect straight away; the row stays open for Forget.
                if (!open && !net.connected && (net.known || !secured))
                    connect();
                if (!open && !net.known && secured)
                    password.forceActiveFocus();
            }

            Connections {
                target: row.net
                function onConnectionFailed(reason) {
                    const wrongKey = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed;
                    root.fail(row.net.name, wrongKey ? "Wrong password, or the network refused the connection" : "Couldn't connect");
                    root.expanded = row.net.name;
                }
                function onConnectedChanged() {
                    if (row.net.connected) {
                        root.clearFailure(row.net.name);
                        password.text = "";
                    }
                }
            }

            // Password entry for new secured networks.
            RowLayout {
                Layout.fillWidth: true
                visible: !row.net.known && row.secured
                spacing: 8
                TextField {
                    id: password
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                    color: Theme.text
                    placeholderTextColor: Theme.dim
                    selectionColor: Theme.violet
                    selectedTextColor: Theme.violetInk
                    font.family: Theme.sans
                    font.pixelSize: 12
                    leftPadding: 12
                    rightPadding: 34
                    background: Rectangle {
                        implicitHeight: 32
                        radius: 10
                        color: Theme.glassStrong
                        border.color: password.activeFocus ? Theme.violet : Theme.lineStrong
                    }
                    onAccepted: row.connect()
                    Glyph {
                        id: reveal
                        property bool checked: false
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: checked ? "󰈈" : "󰈉"
                        size: 14
                        color: Theme.muted
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: reveal.checked = !reveal.checked
                        }
                    }
                }
                PillButton {
                    text: "Connect"
                    primary: true
                    available: password.text !== "" && !row.connecting
                    onClicked: row.connect()
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: row.net.known || row.net.connected || !row.secured
                spacing: 6
                PillButton {
                    visible: !row.net.connected
                    text: row.connecting ? "Connecting…" : "Connect"
                    primary: true
                    available: !row.connecting
                    onClicked: row.connect()
                }
                PillButton {
                    visible: row.net.connected
                    text: "Disconnect"
                    onClicked: row.net.disconnect()
                }
                PillButton {
                    visible: row.net.known
                    text: "Forget"
                    danger: true
                    onClicked: { row.net.forget(); root.expanded = ""; }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.device || !Networking.wifiEnabled
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰤭"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.device ? "This computer has no Wi-Fi adapter" : "Wi-Fi is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        text: "Advanced network settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("nm-connection-editor"); }
        }
    }
}
```

## `config/rofi/config.rasi`

```text
configuration {
 modi: "drun,run,window";
 show-icons: true;
 display-drun: "APPS";
 display-run: "RUN";
 display-window: "WINDOWS";
 drun-display-format: "{name}";
 font: "Inter 12";
 icon-theme: "Nocturne";
 terminal: "kitty";
}
@theme "nocturne"
```

## `config/rofi/nocturne.rasi`

```text
* { bg: #100d18c4; fg: #e9e1f5; muted: #8f809f; violet: #b69af7; selection: #2e2342b3;
 background-color: transparent; text-color: @fg; border-color: #b69af733; }
window { width: 640px; padding: 26px; border: 1px; border-radius: 22px; background-color: @bg; }
mainbox { spacing: 22px; children: [ inputbar, listview, mode-switcher ]; }
inputbar { padding: 16px; border-radius: 12px; background-color: #1c152899; spacing: 14px; children: [ prompt, entry ]; }
prompt { text-color: @violet; font: "Inter Bold 11"; vertical-align: 0.5; }
entry { placeholder: "Search your applications…"; placeholder-color: @muted; }
listview { lines: 6; columns: 1; spacing: 5px; fixed-height: true; }
element { padding: 12px; border-radius: 10px; spacing: 14px; }
element selected.normal { background-color: @selection; text-color: @violet; }
element-icon { size: 28px; }
element-text { vertical-align: 0.5; text-color: inherit; }
mode-switcher { spacing: 10px; }
button { padding: 8px; border-radius: 8px; text-color: @muted; font: "Inter 10"; }
button selected { text-color: @violet; background-color: #20172e99; }
message { padding: 10px; }
```

## `config/satty/config.toml`

```toml
# NOCTURNE — screenshot annotation (Shift+Print)
[general]
initial-tool = "arrow"
copy-command = "wl-copy"
annotation-size-factor = 1.5
corner-roundness = 12
early-exit = ["copy", "save"]
actions-on-enter = ["save-to-clipboard", "save-to-file"]
actions-on-escape = ["exit"]
primary-highlighter = "block"
default-round-caps = true
no-window-decoration = true
notification-thumbnail = "screenshot"

[font]
family = "Inter"
style = "Bold"

[color-palette]
palette = [
    "#b69af7ff",
    "#ef8fa4ff",
    "#a5ccb3ff",
    "#e5c89aff",
    "#9ccbd2ff",
    "#faf5ffff",
]
```

## `config/starship.toml`

```toml
add_newline = true
format = "[󰣇 ](bold #b69af7)$directory$git_branch$git_status$cmd_duration$character"
right_format = "$time"
[directory]
style = "bold #b69af7"
truncation_length = 3
truncation_symbol = "…/"
[character]
success_symbol = "[❯](bold #b69af7)"
error_symbol = "[❯](bold #ef8fa4)"
[git_branch]
symbol = " "
style = "#9ccbd2"
[git_status]
style = "#e5c89a"
[cmd_duration]
min_time = 2000
format = "[ · $duration](#8f809f)"
[time]
disabled = false
time_format = "%H:%M"
format = "[󰥔 $time](#71637f)"
```

## `config/xdg-desktop-portal/portals.conf`

```text
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
```

## `system/etc/sddm.conf.d/90-nocturne.conf`

```text
[Theme]
Current=nocturne
CursorTheme=Nocturne-Cursors
CursorSize=28
Font=Inter,10,-1,5,50,0,0,0,0,0

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1,QT_QUICK_CONTROLS_STYLE=Basic,QT_QUICK_BACKEND=software
```

## `system/usr/share/icons/Nocturne-Cursors/index.theme`

```text
[Icon Theme]
Name=Nocturne Cursors
Comment=Soft lavender cursors with midnight outlines and a violet ring spinner
Inherits=breeze_cursors
```

## `system/usr/share/sddm/themes/nocturne/Main.qml`

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
 id: root
 width: 1280; height: 800; color: "#08070d"
 property string clockText: Qt.formatTime(new Date(), "HH:mm")
 property bool busy: false
 function login() { if (!busy && username.text.length) { busy = true; status.text = "Signing in…"; sddm.login(username.text, password.text, session.currentIndex); } }
 Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop }
 Rectangle { anchors.fill: parent; color: "#2008070d" }
 Timer { interval: 1000; repeat: true; running: true; onTriggered: root.clockText = Qt.formatTime(new Date(), "HH:mm") }
 Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 46; text: root.clockText; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 36 }
 Rectangle {
  id: card
  width: 380; height: 500; x: Math.max(36, parent.width * 0.09); anchors.verticalCenter: parent.verticalCenter
  radius: 24; color: "#ed100d18"; border.color: "#443253"; border.width: 1
  opacity: 0
  Component.onCompleted: entrance.start()
  NumberAnimation { id: entrance; target: card; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
  Rectangle { width: 42; height: 3; radius: 2; x: 32; y: 32; color: "#b69af7"
   SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation {to: 0.4; duration: 2200} NumberAnimation {to: 1; duration: 2200} }
  }
  ColumnLayout {
   anchors.fill: parent; anchors.margins: 32; anchors.topMargin: 55; spacing: 14
   Text { text: "N O C T U R N E"; color: "#b69af7"; font.family: "Inter"; font.pixelSize: 11; font.bold: true }
   Text { text: "Welcome back."; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 28; Layout.topMargin: 6 }
   Text { text: "Your space, after dark."; color: "#8f809f"; font.family: "Inter"; font.pixelSize: 12; Layout.bottomMargin: 10 }
   TextField {
    id: username; Layout.fillWidth: true; implicitHeight: 46; text: userModel.lastUser; placeholderText: "Username"
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: username.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: password.forceActiveFocus()
   }
   TextField {
    id: password; Layout.fillWidth: true; implicitHeight: 46; placeholderText: "Password"; echoMode: TextInput.Password
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: password.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: root.login()
   }
   ComboBox {
    id: session; Layout.fillWidth: true; implicitHeight: 38; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
    palette.button: "#1c1528"; palette.buttonText: "#b9abc9"; palette.text: "#e9e1f5"; palette.base: "#1c1528"; palette.highlight: "#694797"; palette.highlightedText: "#ffffff"; font.family: "Inter"; font.pixelSize: 11
    background: Rectangle {color: "#1c1528"; radius: 8; border.color: "#33263f"}
   }
   Button {
    Layout.fillWidth: true; implicitHeight: 46; text: root.busy ? "Signing in…" : "Sign in  →"; enabled: !root.busy
    contentItem: Text {text: parent.text; color: "#100b1b"; font.family: "Inter"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter}
    background: Rectangle {color: parent.hovered ? "#cbb0ff" : "#b69af7"; radius: 10; Behavior on color { ColorAnimation {duration: 160} }}
    onClicked: root.login()
   }
   Text { id: status; text: ""; color: "#ef8fa4"; font.family: "Inter"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.minimumHeight: 16 }
   RowLayout {
    Layout.alignment: Qt.AlignHCenter; spacing: 22
    Button { text: "Restart"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "restart"; powerDialog.open()} }
    Button { text: "Shut down"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "shutdown"; powerDialog.open()} }
   }
  }
 }
 Dialog {
  id: powerDialog; property string action: ""; anchors.centerIn: parent; title: action === "restart" ? "Restart computer?" : "Shut down computer?"; modal: true
  standardButtons: Dialog.Ok | Dialog.Cancel
  palette.window: "#16111f"; palette.windowText: "#e9e1f5"; palette.button: "#292039"; palette.buttonText: "#b69af7"
  onAccepted: { if (action === "restart") sddm.reboot(); else sddm.powerOff(); }
 }
 Connections {
  target: sddm
  function onLoginFailed() { root.busy = false; password.text = ""; status.text = "Sign-in failed. Please try again."; password.forceActiveFocus(); }
  function onLoginSucceeded() { status.text = "Welcome."; }
 }
 Component.onCompleted: { if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus(); }
}
```

## `system/usr/share/sddm/themes/nocturne/metadata.desktop`

```text
[SddmGreeterTheme]
Name=Nocturne
Description=An original black and violet orbital greeter
Author=lia
License=MIT
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=nocturne
Theme-API=2.0
QtVersion=6
```

## `system/usr/share/sddm/themes/nocturne/theme.conf`

```text
[General]
background=wallpaper.png
```

## `share/color-schemes/Nocturne.colors`

```text
[General]
Name=Nocturne
ColorScheme=Nocturne
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0

[Colors:View]
BackgroundNormal=13,10,18
BackgroundAlternate=20,15,28
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Window]
BackgroundNormal=16,13,24
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Button]
BackgroundNormal=31,24,43
BackgroundAlternate=39,30,52
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Selection]
BackgroundNormal=145,109,207
BackgroundAlternate=118,85,174
ForegroundNormal=255,250,255
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Tooltip]
BackgroundNormal=22,17,31
BackgroundAlternate=28,21,39
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Complementary]
BackgroundNormal=13,10,18
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Header]
BackgroundNormal=20,15,28
BackgroundAlternate=26,19,36
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Icons]
Theme=Papirus-Dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
widgetStyle=Breeze
SingleClick=false

[ColorEffects:Disabled]
Color=56,48,66
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[WM]
activeBackground=20,15,28
activeForeground=228,220,237
inactiveBackground=13,10,18
inactiveForeground=139,124,156

[UiSettings]
ColorScheme=Nocturne
```

## `share/icons/Nocturne/index.theme`

```text
[Icon Theme]
Name=Nocturne
Comment=Papirus violet folders
Inherits=Papirus-Dark,breeze-dark,hicolor
Directories=16x16/places,22x22/places,24x24/places,32x32/places,48x48/places,64x64/places

[16x16/places]
Size=16
Context=Places
Type=Fixed

[22x22/places]
Size=22
Context=Places
Type=Fixed

[24x24/places]
Size=24
Context=Places
Type=Fixed

[32x32/places]
Size=32
Context=Places
Type=Fixed

[48x48/places]
Size=48
Context=Places
Type=Fixed

[64x64/places]
Size=64
Context=Places
Type=Fixed
```

## `share/icons/default/index.theme`

```text
[Icon Theme]
Name=Nocturne cursor fallback
Inherits=Nocturne-Cursors
```

## `assets/wallpaper.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1600" viewBox="0 0 2560 1600">
<defs>
 <radialGradient id="bg" cx="73%" cy="49%" r="66%"><stop stop-color="#201031"/><stop offset=".47" stop-color="#100b19"/><stop offset="1" stop-color="#07070b"/></radialGradient>
 <linearGradient id="rim" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#2b1547"/><stop offset=".37" stop-color="#7c3cc7"/><stop offset=".65" stop-color="#dabaff"/><stop offset=".8" stop-color="#8651c0"/><stop offset="1" stop-color="#1d102a"/></linearGradient>
 <radialGradient id="planet" cx="74%" cy="26%" r="75%"><stop stop-color="#41245c"/><stop offset=".3" stop-color="#1b102b"/><stop offset=".75" stop-color="#08080e"/><stop offset="1" stop-color="#08070c"/></radialGradient>
 <filter id="glow"><feGaussianBlur stdDeviation="18"/></filter>
 <filter id="soft"><feGaussianBlur stdDeviation="55"/></filter>
</defs>
<rect width="2560" height="1600" fill="url(#bg)"/>
<ellipse cx="1750" cy="820" rx="540" ry="480" fill="#6e2cb9" opacity=".1" filter="url(#soft)"/>
<g transform="translate(1730 790) rotate(-28)">
 <ellipse rx="720" ry="245" fill="none" stroke="#7e4ab4" stroke-width="1" opacity=".16"/>
 <ellipse rx="780" ry="290" fill="none" stroke="#7e4ab4" stroke-width="1" opacity=".08"/>
</g>
<circle cx="1730" cy="790" r="370" fill="url(#planet)" stroke="#362047" stroke-width="1"/>
<g transform="translate(1730 790) rotate(-28)">
 <ellipse rx="615" ry="188" fill="none" stroke="#a66ce9" stroke-width="12" filter="url(#glow)" opacity=".5"/>
 <ellipse rx="615" ry="188" fill="none" stroke="url(#rim)" stroke-width="4"/>
 <ellipse rx="626" ry="199" fill="none" stroke="url(#rim)" stroke-width="1" opacity=".4"/>
</g>
<g fill="#c8a2ef"><circle cx="2250" cy="430" r="3" opacity=".6"/><circle cx="1110" cy="1110" r="2" opacity=".5"/><circle cx="2080" cy="1260" r="2" opacity=".35"/></g>
<g id="wordmark">
<path d="M150 1330h56" stroke="#ad83e2" stroke-width="2"/>
<text x="150" y="1380" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#b8a4cf">NOCTURNE</text>
<text x="150" y="1414" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#635570">A QUIETER ORBIT.</text>
</g>
</svg>
```

## `assets/wallpaper-dawn.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1600" viewBox="0 0 2560 1600">
<defs>
 <radialGradient id="bg" cx="30%" cy="68%" r="78%"><stop stop-color="#2c1232"/><stop offset=".42" stop-color="#130b1c"/><stop offset="1" stop-color="#07070b"/></radialGradient>
 <linearGradient id="ring" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#1d102a"/><stop offset=".25" stop-color="#8a3f9e"/><stop offset=".5" stop-color="#f3b4d6"/><stop offset=".72" stop-color="#9b6fe6"/><stop offset="1" stop-color="#1d102a"/></linearGradient>
 <linearGradient id="dawn" x1=".73" y1=".95" x2=".5" y2=".5"><stop stop-color="#ffd0e4"/><stop offset=".3" stop-color="#e48ac0" stop-opacity=".9"/><stop offset=".62" stop-color="#7c3cc7" stop-opacity="0"/></linearGradient>
 <radialGradient id="planet" cx="28%" cy="22%" r="80%"><stop stop-color="#3d1d4a"/><stop offset=".32" stop-color="#1a0f26"/><stop offset=".78" stop-color="#09080e"/><stop offset="1" stop-color="#08070c"/></radialGradient>
 <radialGradient id="moon" cx="30%" cy="30%" r="80%"><stop stop-color="#5a3d74"/><stop offset=".6" stop-color="#1c1328"/><stop offset="1" stop-color="#0d0a12"/></radialGradient>
 <clipPath id="front"><rect x="-900" y="0" width="1800" height="400"/></clipPath>
 <filter id="glow"><feGaussianBlur stdDeviation="16"/></filter>
 <filter id="soft"><feGaussianBlur stdDeviation="70"/></filter>
</defs>
<rect width="2560" height="1600" fill="url(#bg)"/>
<g id="layer-glow">
<ellipse cx="760" cy="900" rx="640" ry="520" fill="#b04a8f" opacity=".11" filter="url(#soft)"/>
<ellipse cx="560" cy="700" rx="320" ry="260" fill="#f3a6cf" opacity=".07" filter="url(#soft)"/>
</g>
<g id="layer-stars" fill="#e9c8f2"><circle cx="1620" cy="300" r="2.5" opacity=".55"/><circle cx="2140" cy="760" r="2" opacity=".4"/><circle cx="1880" cy="1180" r="1.5" opacity=".35"/><circle cx="1290" cy="520" r="1.5" opacity=".3"/><circle cx="2380" cy="380" r="2" opacity=".45"/><circle cx="1500" cy="1420" r="1.5" opacity=".25"/><circle cx="1420" cy="180" r="1.2" opacity=".3"/><circle cx="2260" cy="220" r="1.5" opacity=".35"/><circle cx="1760" cy="560" r="1.2" opacity=".25"/><circle cx="2480" cy="620" r="1.2" opacity=".3"/><circle cx="2300" cy="1060" r="1.5" opacity=".3"/><circle cx="2040" cy="980" r="1.2" opacity=".25"/><circle cx="1150" cy="240" r="1.2" opacity=".25"/><circle cx="440" cy="190" r="1.2" opacity=".2"/></g>
<g id="layer-back">
<circle cx="1980" cy="430" r="28" fill="url(#moon)" stroke="#4a3260" stroke-width="1"/>
<g transform="translate(820 1010) rotate(16)">
 <ellipse rx="880" ry="230" fill="none" stroke="#8e5bc4" stroke-width="1" opacity=".12"/>
 <ellipse rx="760" ry="172" fill="none" stroke="#e48ac0" stroke-width="10" filter="url(#glow)" opacity=".35"/>
 <ellipse rx="760" ry="172" fill="none" stroke="url(#ring)" stroke-width="3"/>
</g>
</g>
<circle id="layer-planet" cx="820" cy="1010" r="430" fill="url(#planet)" stroke="#33203f" stroke-width="1"/>
<g id="layer-rim">
<circle cx="820" cy="1010" r="430" fill="none" stroke="url(#dawn)" stroke-width="16" stroke-dasharray="950 1752" transform="rotate(162 820 1010)" filter="url(#glow)" opacity=".45"/>
<circle cx="820" cy="1010" r="429" fill="none" stroke="url(#dawn)" stroke-width="3" stroke-linecap="round" stroke-dasharray="950 1752" transform="rotate(162 820 1010)"/>
</g>
<g id="layer-front" transform="translate(820 1010) rotate(16)" clip-path="url(#front)">
 <ellipse rx="760" ry="172" fill="none" stroke="#e48ac0" stroke-width="10" filter="url(#glow)" opacity=".35"/>
 <ellipse rx="760" ry="172" fill="none" stroke="url(#ring)" stroke-width="3"/>
 <ellipse rx="772" ry="182" fill="none" stroke="url(#ring)" stroke-width="1" opacity=".4"/>
</g>
<g id="wordmark">
<path d="M2354 1330h56" stroke="#e48ac0" stroke-width="2"/>
<text x="2410" y="1380" text-anchor="end" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#d6b4d8">NOCTURNE</text>
<text x="2410" y="1414" text-anchor="end" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#6d5574">BEFORE THE LIGHT.</text>
</g>
</svg>
```

## `assets/wallpaper-eclipse.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1600" viewBox="0 0 2560 1600">
<defs>
 <radialGradient id="bg" cx="65%" cy="37%" r="72%"><stop stop-color="#1d1233"/><stop offset=".45" stop-color="#0f0b1a"/><stop offset="1" stop-color="#07070b"/></radialGradient>
 <radialGradient id="halo"><stop stop-color="#e2d2ff"/><stop offset=".3" stop-color="#9b6fe6" stop-opacity=".45"/><stop offset=".62" stop-color="#6d28d9" stop-opacity=".12"/><stop offset="1" stop-color="#6d28d9" stop-opacity="0"/></radialGradient>
 <linearGradient id="streamer" x1="0" y1="1" x2="0" y2="0"><stop stop-color="#efe4ff"/><stop offset=".35" stop-color="#c4a5ff" stop-opacity=".5"/><stop offset="1" stop-color="#9b6fe6" stop-opacity="0"/></linearGradient>
 <linearGradient id="streamer-rose" x1="0" y1="1" x2="0" y2="0"><stop stop-color="#ffe0ef"/><stop offset=".35" stop-color="#e48ac0" stop-opacity=".45"/><stop offset="1" stop-color="#b04a8f" stop-opacity="0"/></linearGradient>
 <radialGradient id="body" cx="38%" cy="70%" r="75%"><stop stop-color="#151021"/><stop offset=".6" stop-color="#09070f"/><stop offset="1" stop-color="#050408"/></radialGradient>
 <radialGradient id="world" cx="74%" cy="6%" r="52%"><stop stop-color="#1a1126"/><stop offset=".3" stop-color="#0d0a15"/><stop offset="1" stop-color="#060509"/></radialGradient>
 <linearGradient id="air" gradientUnits="userSpaceOnUse" x1="1180" y1="1476" x2="0" y2="1300"><stop stop-color="#f6e8ff"/><stop offset=".25" stop-color="#b69af7" stop-opacity=".7"/><stop offset=".7" stop-color="#7c3cc7" stop-opacity=".25"/><stop offset="1" stop-color="#6d28d9" stop-opacity=".08"/></linearGradient>
 <clipPath id="near"><rect x="-800" y="0" width="1600" height="300"/></clipPath>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
 <filter id="wisp" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="12"/></filter>
 <filter id="haze" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="28"/></filter>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="80"/></filter>
</defs>
<rect width="2560" height="1600" fill="url(#bg)"/>
<g id="layer-nebula" transform="rotate(24 760 420)">
 <ellipse cx="760" cy="420" rx="860" ry="170" fill="#6e2cb9" opacity=".1" filter="url(#soft)"/>
 <ellipse cx="480" cy="400" rx="420" ry="110" fill="#b04a8f" opacity=".07" filter="url(#soft)"/>
 <ellipse cx="1100" cy="430" rx="380" ry="100" fill="#5b3fa8" opacity=".08" filter="url(#soft)"/>
</g>
<g id="layer-stars" fill="#ddd0f5"><circle class="glint" cx="2210" cy="250" r="2.6" opacity=".7"/><circle class="glint" cx="520" cy="760" r="2.2" opacity=".55"/><circle class="glint" cx="2420" cy="1060" r="2" opacity=".5"/><circle cx="1240" cy="150" r="1.6" opacity=".4"/><circle cx="980" cy="330" r="1.2" opacity=".3"/><circle cx="1420" cy="1010" r="1.5" opacity=".35"/><circle cx="2380" cy="560" r="1.5" opacity=".4"/><circle cx="2060" cy="1180" r="1.2" opacity=".3"/><circle cx="2470" cy="140" r="1.2" opacity=".3"/><circle cx="160" cy="220" r="1.5" opacity=".35"/><circle cx="330" cy="520" r="1.2" opacity=".25"/><circle cx="760" cy="120" r="1.2" opacity=".3"/><circle cx="210" cy="980" r="1.5" opacity=".3"/><circle cx="640" cy="1080" r="1.2" opacity=".25"/><circle cx="1080" cy="880" r="1.2" opacity=".25"/><circle cx="1880" cy="1360" r="1.5" opacity=".3"/><circle cx="2240" cy="1480" r="1.2" opacity=".25"/><circle cx="1620" cy="1250" r="1.2" opacity=".25"/><circle cx="2500" cy="820" r="1.2" opacity=".3"/><circle cx="1960" cy="80" r="1.5" opacity=".35"/><circle cx="440" cy="60" r="1.2" opacity=".25"/><circle cx="1130" cy="620" r="1.2" opacity=".2"/><circle cx="60" cy="640" r="1.2" opacity=".25"/><circle cx="2300" cy="900" r="1.2" opacity=".25"/></g>
<circle id="layer-halo" cx="1660" cy="600" r="660" fill="url(#halo)" opacity=".6"/>
<g id="layer-corona" transform="translate(1660 600)" filter="url(#wisp)">
 <path d="M-46 0C-16-156-3-364 0-520C3-364 16-156 46 0Z" transform="rotate(70) translate(0 -185)" fill="url(#streamer)" opacity="0.5"/>
 <path d="M-40 0C-14-99-3-231 0-330C3-231 14-99 40 0Z" transform="rotate(98) translate(0 -185)" fill="url(#streamer)" opacity="0.32"/>
 <path d="M-46 0C-16-150-3-350 0-500C3-350 16-150 46 0Z" transform="rotate(252) translate(0 -185)" fill="url(#streamer)" opacity="0.48"/>
 <path d="M-36 0C-13-90-3-210 0-300C3-210 13-90 36 0Z" transform="rotate(280) translate(0 -185)" fill="url(#streamer)" opacity="0.3"/>
 <path d="M-34 0C-12-69-3-161 0-230C3-161 12-69 34 0Z" transform="rotate(12) translate(0 -185)" fill="url(#streamer)" opacity="0.28"/>
 <path d="M-38 0C-13-84-3-196 0-280C3-196 13-84 38 0Z" transform="rotate(40) translate(0 -185)" fill="url(#streamer)" opacity="0.25"/>
 <path d="M-34 0C-12-75-3-175 0-250C3-175 12-75 34 0Z" transform="rotate(165) translate(0 -185)" fill="url(#streamer)" opacity="0.26"/>
 <path d="M-30 0C-10-60-3-140 0-200C3-140 10-60 30 0Z" transform="rotate(205) translate(0 -185)" fill="url(#streamer)" opacity="0.22"/>
 <path d="M-34 0C-12-72-3-168 0-240C3-168 12-72 34 0Z" transform="rotate(320) translate(0 -185)" fill="url(#streamer)" opacity="0.24"/>
 <path d="M-28 0C-10-54-3-126 0-180C3-126 10-54 28 0Z" transform="rotate(350) translate(0 -185)" fill="url(#streamer)" opacity="0.2"/>
</g>
<g id="layer-wisps" transform="translate(1660 600)" filter="url(#wisp)">
 <path d="M-34 0C-12-120-3-280 0-400C3-280 12-120 34 0Z" transform="rotate(58) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.32"/>
 <path d="M-34 0C-12-114-3-266 0-380C3-266 12-114 34 0Z" transform="rotate(238) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.32"/>
 <path d="M-28 0C-10-69-3-161 0-230C3-161 10-69 28 0Z" transform="rotate(128) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.24"/>
 <path d="M-28 0C-10-63-3-147 0-210C3-147 10-63 28 0Z" transform="rotate(300) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.22"/>
 <path d="M-24 0C-8-48-3-112 0-160C3-112 8-48 24 0Z" transform="rotate(190) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.2"/>
 <path d="M-24 0C-8-45-3-105 0-150C3-105 8-45 24 0Z" transform="rotate(20) translate(0 -185)" fill="url(#streamer-rose)" opacity="0.18"/>
</g>
<g id="layer-orbits" transform="translate(1660 600) rotate(-18)" fill="none" stroke="#b69af7" stroke-width="1.5" stroke-dasharray="2 10">
 <ellipse rx="360" ry="92" opacity=".22"/>
 <ellipse rx="560" ry="148" opacity=".16"/>
 <ellipse rx="780" ry="206" stroke-dasharray="none" stroke-width="1" opacity=".06"/>
</g>
<circle id="layer-body" cx="1660" cy="600" r="200" fill="url(#body)"/>
<g id="layer-limb">
 <circle cx="1660" cy="600" r="222" fill="none" stroke="#cdb4ff" stroke-width="56" filter="url(#haze)" opacity=".45"/>
 <circle cx="1660" cy="600" r="201" fill="none" stroke="#d9c4ff" stroke-width="18" filter="url(#glow)" opacity=".7"/>
 <circle cx="1660" cy="600" r="200.5" fill="none" stroke="#f4ecff" stroke-width="2.5" opacity=".9"/>
</g>
<g id="layer-bead">
 <ellipse cx="1519" cy="741" rx="130" ry="1.4" fill="#f6e8ff" opacity=".45"/>
 <ellipse cx="1519" cy="741" rx="1.4" ry="44" fill="#f6e8ff" opacity=".3"/>
 <circle cx="1519" cy="741" r="30" fill="#f3d6ff" filter="url(#glow)" opacity=".9"/>
 <circle cx="1519" cy="741" r="6" fill="#ffffff"/>
</g>
<g id="layer-near" transform="translate(1660 600) rotate(-18)" clip-path="url(#near)" fill="none" stroke="#b69af7" stroke-width="1.5" stroke-dasharray="2 10">
 <ellipse rx="360" ry="92" opacity=".22"/>
 <ellipse rx="560" ry="148" opacity=".16"/>
</g>
<circle id="layer-world" cx="380" cy="2950" r="1680" fill="url(#world)"/>
<g id="layer-air">
 <circle cx="380" cy="2950" r="1680" fill="none" stroke="url(#air)" stroke-width="24" filter="url(#glow)" opacity=".4"/>
 <circle cx="380" cy="2950" r="1680" fill="none" stroke="url(#air)" stroke-width="2" opacity=".85"/>
</g>
<g id="wordmark">
<path d="M2354 1330h56" stroke="#b69af7" stroke-width="2"/>
<text x="2410" y="1380" text-anchor="end" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#c9b8e6">NOCTURNE</text>
<text x="2410" y="1414" text-anchor="end" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#625775">AFTER THE LIGHT.</text>
</g>
</svg>
```

## `config/fastfetch/config.jsonc`

```json
{
  "logo": {
    "type": "kitty-direct",
    "source": "~/.config/fastfetch/nocturne-arch.png",
    "width": 26,
    "height": 13,
    "padding": {
      "top": 1,
      "left": 0,
      "right": 4
    }
  },
  "display": {
    "separator": " : ",
    "color": {
      "keys": "#b69af7",
      "title": "#ceb4ff",
      "output": "#e4dced",
      "separator": "#71637f"
    },
    "key": {
      "width": 16
    }
  },
  "modules": [
    "break",
    {
      "type": "custom",
      "format": "  ◈  N O C T U R N E  ·  a quieter orbit."
    },
    {
      "type": "custom",
      "format": "╭────────────────────────────────────────────────╮"
    },
    {
      "type": "host",
      "key": "  󰌢 Host",
      "keyColor": "#9ccbd2",
      "format": "{name}"
    },
    {
      "type": "os",
      "key": "  󰣇 OS",
      "keyColor": "#b69af7"
    },
    {
      "type": "kernel",
      "key": "   Kernel",
      "keyColor": "#ceb4ff"
    },
    {
      "type": "packages",
      "key": "  󰏖 Packages",
      "keyColor": "#a5ccb3"
    },
    {
      "type": "display",
      "key": "  󰍹 Display",
      "keyColor": "#9ccbd2",
      "format": "{width}×{height} @ {refresh-rate} Hz"
    },
    {
      "type": "terminal",
      "key": "   Terminal",
      "keyColor": "#e5c89a"
    },
    {
      "type": "wm",
      "key": "   WM",
      "keyColor": "#b69af7"
    },
    {
      "type": "custom",
      "format": "╰────────────────────────────────────────────────╯"
    },
    "break",
    {
      "type": "title",
      "key": "  ",
      "keyColor": "#9ccbd2",
      "format": "{user-name} @ {host-name}"
    },
    {
      "type": "custom",
      "format": "╭────────────────────────────────────────────────╮"
    },
    {
      "type": "cpu",
      "key": "   CPU",
      "keyColor": "#a1a5e9"
    },
    {
      "type": "gpu",
      "key": "  󰢮 GPU",
      "keyColor": "#a1a5e9"
    },
    {
      "type": "gpu",
      "key": "   Driver",
      "keyColor": "#b69af7",
      "format": "{driver}"
    },
    {
      "type": "memory",
      "key": "   Memory",
      "keyColor": "#ceb4ff"
    },
    {
      "type": "disk",
      "key": "  󰋊 Disk",
      "keyColor": "#a5ccb3",
      "folders": "/"
    },
    {
      "type": "uptime",
      "key": "  󰔟 Uptime",
      "keyColor": "#ef8fa4"
    },
    {
      "type": "custom",
      "format": "╰────────────────────────────────────────────────╯"
    },
    {
      "type": "colors",
      "symbol": "circle",
      "paddingLeft": 2
    },
    "break"
  ]
}
```

## `config/fastfetch/nocturne-arch.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="640" viewBox="0 0 400 400">
<defs><mask id="arch"><path fill="white" d="M200 20 372 365 Q286 314 241 308 C246 249 232 222 204 222 C174 222 158 251 162 308 Q107 320 28 365 L146 130 181 153 151 119Z"/></mask></defs>
<g mask="url(#arch)"><path fill="#b69af7" d="M0 0H400V400H0z"/><path fill="#ceb4ff" d="M200 20 246 126 180 330 115 273Z"/><path fill="#71637f" d="M246 126 400 400 202 316Z"/><path fill="#a1a5e9" d="M28 365 115 273 159 314Z"/><path fill="#e4dced" d="M200 20 210 43 153 121 146 130Z"/><path fill="#231d2e" d="M286 269 339 290 318 258 400 400 231 313Z"/></g>
</svg>
```

## `bin/nocturne-osd`

```python
#!/usr/bin/env python3
"""Adjust desktop controls and show a single, replacing Nocturne popup."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, env={**os.environ, 'LC_ALL': 'C'}).strip()


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('volume', 'microphone', 'brightness') or sys.argv[2] not in ('up', 'down', 'mute', 'show'):
        sys.exit('Usage: nocturne-osd volume|microphone|brightness up|down|mute|show')
    control, action = sys.argv[1:]
    if control == 'brightness' and action == 'mute':
        sys.exit('Brightness cannot be muted')
    directory = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'nocturne'
    directory.mkdir(parents=True, exist_ok=True)
    # Serialize repeat events so the last popup always reflects the latest value.
    with (directory / 'osd.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        muted = False
        if control == 'brightness':
            if action != 'show':
                run('brightnessctl', '--class=backlight', '--min-value=1', 'set', '+5%' if action == 'up' else '5%-')
            current = int(run('brightnessctl', '--class=backlight', 'get'))
            maximum = int(run('brightnessctl', '--class=backlight', 'max'))
            value = round(current * 100 / maximum)
            title = f'Brightness · {value}%'
        else:
            device = '@DEFAULT_AUDIO_SOURCE@' if control == 'microphone' else '@DEFAULT_AUDIO_SINK@'
            if action == 'mute':
                run('wpctl', 'set-mute', device, 'toggle')
            elif action != 'show':
                run('wpctl', 'set-volume', '-l', '1', device, '5%+' if action == 'up' else '5%-')
            status = run('wpctl', 'get-volume', device)
            value = round(float(status.split()[1]) * 100)
            label = 'Microphone' if control == 'microphone' else 'Volume'
            muted = '[MUTED]' in status
            title = f'{label} · Muted' if muted else f'{label} · {value}%'
        value = min(100, max(0, value))
        # The Nocturne shell draws the popup; fall back to a plain notification without it.
        try:
            shown = subprocess.run(['quickshell', '-c', 'nocturne', 'ipc', 'call', 'osd', 'flash',
                                    control, str(value), 'true' if muted else 'false'],
                                   capture_output=True).returncode == 0
        except OSError:
            shown = False
        if not shown:
            run('notify-send', '--app-name=Nocturne OSD', '--urgency=low', '--expire-time=1500',
                '--hint=int:value:' + str(0 if muted else value),
                '--hint=string:x-canonical-private-synchronous:nocturne-osd', title)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'nocturne-osd: {error}')
```


## Neovim workspace

The editor-only installer backs up an existing configuration and restores the locked plugin versions. See README.md for usage and language-server setup.

### `tools/install-neovim.sh`

```bash
#!/usr/bin/env bash
# Install only the Neovim configuration; no desktop or system changes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v nvim >/dev/null
command -v git >/dev/null
config_root=${XDG_CONFIG_HOME:-$HOME/.config}
state_root=${XDG_STATE_HOME:-$HOME/.local/state}
destination="$config_root/nvim"
backup=$(mktemp -d "$state_root/nocturne/backups/neovim-XXXXXXXX" 2>/dev/null) || {
    mkdir -p "$state_root/nocturne/backups"
    backup=$(mktemp -d "$state_root/nocturne/backups/neovim-XXXXXXXX")
}
if [[ -e "$destination" || -L "$destination" ]]; then
    mv -- "$destination" "$backup/nvim"
else
    printf '%s\n' "$destination" > "$backup/new-files.txt"
fi
mkdir -p "$config_root"
cp -a "$ROOT/config/nvim" "$destination"
printf 'Neovim configuration installed. Backup record: %s\n' "$backup"
nvim --headless '+Lazy! restore' +qa
printf 'Open a project with: nvim /path/to/project\n'
```

### `config/nvim/colors/nocturne.lua`

```lua
-- Original Nocturne palette, shared with the desktop.
vim.cmd('highlight clear')
if vim.g.syntax_on then vim.cmd('syntax reset') end
vim.o.background = 'dark'
vim.g.colors_name = 'nocturne'
local c = { bg = '#0d0a12', panel = '#100d18', raised = '#1b1526', border = '#352a46',
  violet = '#b69af7', fg = '#e4dced', muted = '#8f809f', green = '#a6d4bc',
  rose = '#ed9cad', gold = '#e5c49a', blue = '#a3c5e9', pink = '#d5a4dc' }
local groups = {
  Normal = { fg = c.fg, bg = c.bg }, NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.panel }, FloatBorder = { fg = c.violet, bg = c.panel },
  FloatTitle = { fg = c.violet, bg = c.panel, bold = true },
  CursorLine = { bg = c.raised }, CursorLineNr = { fg = c.violet, bold = true },
  LineNr = { fg = c.muted }, SignColumn = { bg = c.bg }, EndOfBuffer = { fg = c.border },
  WinSeparator = { fg = c.border }, Visual = { bg = '#3d2d54' },
  Search = { fg = c.bg, bg = c.gold }, IncSearch = { fg = c.bg, bg = c.violet },
  Pmenu = { fg = c.fg, bg = c.panel }, PmenuSel = { fg = c.bg, bg = c.violet },
  PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.muted },
  StatusLine = { fg = c.fg, bg = c.panel }, StatusLineNC = { fg = c.muted, bg = c.panel },
  TabLine = { fg = c.muted, bg = c.panel }, TabLineSel = { fg = c.violet, bg = c.raised, bold = true },
  TabLineFill = { bg = c.panel }, Directory = { fg = c.violet },
  Title = { fg = c.violet, bold = true }, Comment = { fg = c.muted, italic = true },
  Constant = { fg = c.gold }, String = { fg = c.green }, Character = { fg = c.green },
  Number = { fg = c.gold }, Boolean = { fg = c.gold }, Float = { fg = c.gold },
  Identifier = { fg = c.fg }, Function = { fg = c.blue }, Statement = { fg = c.violet },
  Keyword = { fg = c.violet }, Operator = { fg = c.pink }, PreProc = { fg = c.pink },
  Type = { fg = c.gold }, Special = { fg = c.pink }, Delimiter = { fg = c.muted },
  Underlined = { fg = c.blue, underline = true }, Todo = { fg = c.gold, bold = true },
  Error = { fg = c.rose }, ErrorMsg = { fg = c.rose }, WarningMsg = { fg = c.gold },
  MatchParen = { fg = c.violet, bg = c.border, bold = true }, NonText = { fg = c.border },
  Folded = { fg = c.muted, bg = c.panel }, FoldColumn = { fg = c.muted },
  DiffAdd = { bg = '#1c3029' }, DiffDelete = { bg = '#38202d' },
  DiffChange = { bg = '#27243f' }, DiffText = { bg = '#403457' },
  GitSignsAdd = { fg = c.green }, GitSignsChange = { fg = c.violet }, GitSignsDelete = { fg = c.rose },
  DiagnosticError = { fg = c.rose }, DiagnosticWarn = { fg = c.gold },
  DiagnosticInfo = { fg = c.blue }, DiagnosticHint = { fg = c.violet },
  NvimTreeNormal = { fg = c.fg, bg = c.panel }, NvimTreeNormalNC = { fg = c.fg, bg = c.panel },
  NvimTreeEndOfBuffer = { fg = c.panel, bg = c.panel },
  NvimTreeRootFolder = { fg = c.violet, bold = true }, NvimTreeFolderName = { fg = c.violet },
  NvimTreeOpenedFolderName = { fg = c.pink, bold = true }, NvimTreeFolderIcon = { fg = c.violet },
  TelescopeBorder = { fg = c.border }, TelescopeSelection = { bg = c.raised },
  TelescopeMatching = { fg = c.violet, bold = true },
  WhichKey = { fg = c.violet }, WhichKeyGroup = { fg = c.blue }, WhichKeyDesc = { fg = c.fg },
}
for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
for _, severity in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
  vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. severity, { sp = groups['Diagnostic' .. severity].fg, undercurl = true })
end
local terminal = { c.panel, c.rose, c.green, c.gold, c.violet, c.pink, c.blue, c.fg,
  c.muted, '#f5b4c1', '#bce6ce', '#f2d7b3', '#cbb4ff', '#e6bce9', '#bddbf5', '#f7f0ff' }
for i, color in ipairs(terminal) do vim.g['terminal_color_' .. (i - 1)] = color end
```

### `config/nvim/init.lua`

```lua
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.mouse = 'a'
o.clipboard = 'unnamedplus'
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = 'yes'
o.cursorline = true
o.wrap = false
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.completeopt = { 'menu', 'menuone', 'noselect' }
o.laststatus = 3
vim.cmd.colorscheme('nocturne')
local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(path) then
  local result = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', path })
  if vim.v.shell_error ~= 0 then
    vim.notify('Plugin download failed. Check your connection and restart Neovim.\n' .. result, vim.log.levels.ERROR)
    return
  end
end
vim.opt.rtp:prepend(path)
require('lazy').setup('nocturne.plugins', {
  change_detection = { notify = false },
  checker = { enabled = false },
  local_spec = false,
  ui = { border = 'rounded' },
})
require('nocturne.keys')
vim.diagnostic.config({ virtual_text = false, float = { border = 'rounded' }, severity_sort = true })
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() > 1 then return end
    local arg = vim.fn.argv(0)
    if vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1 then
      if vim.fn.isdirectory(arg) == 1 then vim.cmd.cd(vim.fn.fnameescape(arg)) end
      require('nvim-tree.api').tree.open()
    end
  end,
})
```

### `config/nvim/lazy-lock.json`

```json
{
  "bufferline.nvim": { "branch": "main", "commit": "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3" },
  "gitsigns.nvim": { "branch": "main", "commit": "683137003522aebd6948358334164a6ba2ca7cd5" },
  "lazy.nvim": { "branch": "main", "commit": "85c7ff3711b730b4030d03144f6db6375044ae82" },
  "lualine.nvim": { "branch": "master", "commit": "221ce6b2d999187044529f49da6554a92f740a96" },
  "mason.nvim": { "branch": "main", "commit": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d" },
  "nvim-autopairs": { "branch": "master", "commit": "3172f40c16563db871a58f20d205c710ad782311" },
  "nvim-lspconfig": { "branch": "master", "commit": "77b7432d4770d23b277d37923e5a08a442d8bb07" },
  "nvim-tree.lua": { "branch": "master", "commit": "9a2e0006d42f292eb3ade7dfdff201a7429a780c" },
  "nvim-web-devicons": { "branch": "master", "commit": "ec309a0eaff6ea967e58c275996155ab5c16938d" },
  "plenary.nvim": { "branch": "master", "commit": "74b06c6c75e4eeb3108ec01852001636d85a932b" },
  "telescope.nvim": { "branch": "master", "commit": "40aedd8a68c78a656a10a8d62d80c54af59420fb" },
  "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" }
}
```

### `config/nvim/lua/nocturne/keys.lua`

```lua
local function map(key, action, desc, mode)
  vim.keymap.set(mode or 'n', key, action, { silent = true, desc = desc })
end
local function find(name)
  return function() require('telescope.builtin')[name]() end
end
map('<leader>e', '<cmd>NvimTreeToggle<cr>', 'Toggle file tree')
map('<leader>o', '<cmd>NvimTreeFindFile<cr>', 'Reveal current file')
map('<leader><space>', find('find_files'), 'Find project file')
map('<C-p>', find('find_files'), 'Find project file')
map('<leader>ff', find('find_files'), 'Find files')
map('<leader>fg', find('live_grep'), 'Search project text')
map('<leader>fr', find('oldfiles'), 'Recent files')
map('<leader>fb', find('buffers'), 'Open buffers')
map('<leader>fh', find('help_tags'), 'Search help')
map('<S-l>', '<cmd>bnext<cr>', 'Next file')
map('<S-h>', '<cmd>bprevious<cr>', 'Previous file')
map('<leader>bn', '<cmd>bnext<cr>', 'Next file')
map('<leader>bp', '<cmd>bprevious<cr>', 'Previous file')
map('<leader>bd', '<cmd>bdelete<cr>', 'Close file (protect unsaved changes)')
map('<leader>s', '<cmd>write<cr>', 'Save file')
map('<C-s>', '<cmd>write<cr>', 'Save file', { 'n', 'i' })
map('<leader>q', '<cmd>confirm qall<cr>', 'Quit (ask about unsaved files)')
map('<Esc>', '<cmd>nohlsearch<cr>', 'Clear search highlight')
map('<leader>?', function() require('which-key').show({ global = true }) end, 'Show shortcuts')
map('<leader>wl', '<C-w>l', 'Focus right window')
map('<leader>wh', '<C-w>h', 'Focus left window')
map('<leader>wj', '<C-w>j', 'Focus lower window')
map('<leader>wk', '<C-w>k', 'Focus upper window')
map('<leader>wv', '<cmd>vsplit<cr>', 'Split vertically')
map('<leader>ws', '<cmd>split<cr>', 'Split horizontally')
map('<leader>gg', find('git_status'), 'Git changed files')
map('<leader>gp', function() require('gitsigns').preview_hunk() end, 'Preview Git change')
map('<leader>cm', '<cmd>Mason<cr>', 'Install language tools')
map('<leader>cd', vim.diagnostic.open_float, 'Line diagnostics')
map('<leader>cl', find('diagnostics'), 'Project diagnostics')
map('<leader>cr', vim.lsp.buf.rename, 'Rename symbol')
map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
map('<leader>cf', function() vim.lsp.buf.format({ async = true }) end, 'Format with language server')
map('gd', vim.lsp.buf.definition, 'Go to definition')
map('grr', vim.lsp.buf.references, 'Find references')
map('K', vim.lsp.buf.hover, 'Documentation')
map('<leader>t', '<cmd>botright 12split | terminal<cr>', 'Open terminal')
map('<Esc><Esc>', '<C-\\><C-n>', 'Leave terminal mode', 't')
map('<leader>p', '<cmd>Lazy<cr>', 'Manage plugins')
```

### `config/nvim/lua/nocturne/plugins.lua`

```lua
return {
  { 'nvim-tree/nvim-web-devicons', opts = {} },
  { 'nvim-tree/nvim-tree.lua', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    view = { width = 32, side = 'left' },
    renderer = { group_empty = true, highlight_git = 'name' },
    update_focused_file = { enable = true },
    filters = { dotfiles = false, custom = { '^.git$' } },
    actions = { open_file = { quit_on_open = false } },
  } },
  { 'folke/which-key.nvim', opts = { preset = 'modern', delay = 350, spec = {
    { '<leader>f', group = 'Find' }, { '<leader>b', group = 'Buffers' },
    { '<leader>c', group = 'Code' }, { '<leader>g', group = 'Git' },
    { '<leader>w', group = 'Windows' },
  } } },
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {
    defaults = { sorting_strategy = 'ascending', layout_config = { prompt_position = 'top' },
      file_ignore_patterns = { 'node_modules/', '%.git/' } },
    pickers = { find_files = { hidden = true } },
  } },
  { 'akinsho/bufferline.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    options = { diagnostics = 'nvim_lsp', separator_style = 'thin',
      offsets = { { filetype = 'NvimTree', text = 'NOCTURNE · Files', text_align = 'center' } } },
  } },
  { 'nvim-lualine/lualine.nvim', opts = {
    options = { theme = {
      normal = { a = { fg = '#0d0a12', bg = '#b69af7', gui = 'bold' }, b = { fg = '#e4dced', bg = '#292035' }, c = { fg = '#8f809f', bg = '#100d18' } },
      insert = { a = { fg = '#0d0a12', bg = '#a6d4bc' } },
      visual = { a = { fg = '#0d0a12', bg = '#d5a4dc' } },
      replace = { a = { fg = '#0d0a12', bg = '#ed9cad' } },
      inactive = { a = { fg = '#8f809f', bg = '#100d18' }, b = { fg = '#8f809f', bg = '#100d18' }, c = { fg = '#8f809f', bg = '#100d18' } },
    }, globalstatus = true },
  } },
  { 'lewis6991/gitsigns.nvim', opts = {} },
  { 'windwp/nvim-autopairs', opts = {} },
  { 'mason-org/mason.nvim', opts = { ui = { border = 'rounded' } } },
  { 'neovim/nvim-lspconfig', dependencies = { 'mason-org/mason.nvim' }, config = function()
    -- Enable only installed servers; Mason adds its executables to PATH.
    local servers = {
      lua_ls = 'lua-language-server', pyright = 'pyright-langserver',
      ts_ls = 'typescript-language-server', bashls = 'bash-language-server',
      clangd = 'clangd', rust_analyzer = 'rust-analyzer', gopls = 'gopls',
    }
    vim.lsp.config('lua_ls', { settings = { Lua = { diagnostics = { globals = { 'vim' } } } } })
    for server, executable in pairs(servers) do
      if vim.fn.executable(executable) == 1 then vim.lsp.enable(server) end
    end
    vim.api.nvim_create_autocmd('LspAttach', { callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method('textDocument/completion') then
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
    end })
  end },
}
```

