#!/usr/bin/env bash
# Nocturne installer. Run as the desktop user: ./install.sh
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-all}
case "$MODE" in all|--system-only|--user-only|--boot-only) ;; *) echo "Usage: $0 [--system-only|--user-only|--boot-only]" >&2; exit 2;; esac
if [[ "$MODE" == --boot-only ]]; then
    if [[ $EUID == 0 ]]; then
        exec python3 "$ROOT/tools/install-boot.py"
    else
        exec sudo python3 "$ROOT/tools/install-boot.py"
    fi
fi
STAMP=$(date +%Y%m%d-%H%M%S)
# Replaced by the Quickshell shell (bar, notifications, OSD) and awww (wallpaper).
legacy_packages=(waybar mako swaybg)
legacy_configs=(waybar mako)
ask() {
    if [[ ! -t 0 ]]; then printf '%s [y/N] — skipped (noninteractive)\n' "$1"; return 1; fi
    local answer; read -r -p "$1 [y/N] " answer
    [[ ${answer,,} == y || ${answer,,} == yes ]]
}
packages=(neovim git ripgrep wl-clipboard unzip nodejs npm pacman-contrib flatpak hyprland kitty fastfetch dolphin sddm quickshell awww rofi fish starship hyprlock hypridle breeze breeze-cursors breeze-icons breeze-gtk papirus-icon-theme qt6ct qt5ct qt5-wayland qt5-quickcontrols2 blueman network-manager-applet networkmanager pavucontrol pipewire-pulse wireplumber ttf-jetbrains-mono-nerd inter-font grim slurp satty hyprpicker cliphist python-pillow polkit-kde-agent bluez bluez-utils brightnessctl playerctl xdg-desktop-portal-hyprland xdg-desktop-portal-gtk htop libnotify librsvg xorg-xcursorgen)
if [[ "$MODE" == --system-only ]]; then
    [[ $EUID == 0 ]] || { echo 'System phase needs sudo.' >&2; exit 1; }
    target=${SUDO_USER:-${2:-}}
    [[ -n "$target" && "$target" != root ]] || { echo 'Specify the desktop username as argument 2.' >&2; exit 1; }
    if [[ ${NOCTURNE_SKIP_PACKAGES:-0} != 1 ]]; then
        # Use currently synced repositories; never refresh the database alone.
        pacman -S --needed --noconfirm "${packages[@]}"
    fi
    backup="/var/lib/nocturne/backups/$STAMP"
    mkdir -p "$backup"
    # Offer to remove components Nocturne no longer uses; set NOCTURNE_REMOVE_LEGACY=1 or 0 to skip the question.
    mapfile -t installed < <(pacman -Qq "${legacy_packages[@]}" 2>/dev/null || true)
    if (( ${#installed[@]} )); then
        if [[ ${NOCTURNE_REMOVE_LEGACY:-ask} == 1 ]] || { [[ ${NOCTURNE_REMOVE_LEGACY:-ask} == ask ]] && ask "Remove packages Nocturne no longer uses (${installed[*]})?"; }; then
            pacman -Q "${installed[@]}" > "$backup/removed-packages.txt"
            # -s also drops their now-unneeded dependencies, never explicitly installed packages.
            pacman -Rns --noconfirm "${installed[@]}" || echo "Could not remove ${installed[*]}; another package may still depend on them." >&2
        fi
    fi
    getent passwd "$target" | cut -d: -f7 > "$backup/previous-shell.txt"
    for unit in bluetooth NetworkManager sddm; do
        systemctl is-enabled "$unit" > "$backup/$unit.enabled" 2>&1 || true
    done
    while IFS= read -r -d '' source; do
        rel=${source#"$ROOT/system/"}; dest="/$rel"
        if [[ -e "$dest" || -L "$dest" ]]; then mkdir -p "$backup/$(dirname "$rel")"; cp -a "$dest" "$backup/$rel"; else printf '%s\n' "$dest" >> "$backup/new-files.txt"; fi
        install -Dm644 "$source" "$dest"
    done < <(find "$ROOT/system" -type f -print0)
    usermod -s /usr/bin/fish "$target"
    systemctl enable --now bluetooth NetworkManager
    systemctl enable sddm
    # Boot assets are deliberately outside system/: deploy only after opt-in.
    python3 "$ROOT/tools/install-boot.py" || echo 'Optional boot theming did not complete; see diagnostics above.' >&2
    echo "System backup: $backup"
    exit 0
fi
[[ $EUID != 0 ]] || { echo 'Run this installer as your regular desktop user.' >&2; exit 1; }
# sudo resets the environment, so hand the phase its options explicitly.
if [[ "$MODE" != --user-only ]]; then sudo NOCTURNE_SKIP_PACKAGES="${NOCTURNE_SKIP_PACKAGES:-0}" NOCTURNE_REMOVE_LEGACY="${NOCTURNE_REMOVE_LEGACY:-ask}" "$ROOT/install.sh" --system-only; fi
backup="$HOME/.local/state/nocturne/backups/$STAMP"
mkdir -p "$backup"
copy_tree() {
    local source_root=$1 destination_root=$2
    while IFS= read -r -d '' source; do
        rel=${source#"$source_root/"}; dest="$destination_root/$rel"
        if [[ -e "$dest" || -L "$dest" ]]; then
            prior=${dest#"$HOME/"}; mkdir -p "$backup/$(dirname "$prior")"; cp -a "$dest" "$backup/$prior"
        else printf '%s\n' "$dest" >> "$backup/new-files.txt"; fi
        mkdir -p "$(dirname "$dest")"
        cp "$source" "$dest"
    done < <(find "$source_root" -type f -print0)
}
copy_tree "$ROOT/config" "$HOME/.config"
copy_tree "$ROOT/bin" "$HOME/.local/bin"
copy_tree "$ROOT/share" "$HOME/.local/share"
mkdir -p "$HOME/.local/share/nocturne"
# Wallpapers are managed separately and backed up on subsequent installations.
for wallpaper in wallpaper.png wallpaper-clean.png wallpaper-dawn.png wallpaper-dawn-clean.png wallpaper-eclipse.png wallpaper-eclipse-clean.png; do
 if [[ -e "$HOME/.local/share/nocturne/$wallpaper" ]]; then
  mkdir -p "$backup/.local/share/nocturne"
  cp -a "$HOME/.local/share/nocturne/$wallpaper" "$backup/.local/share/nocturne/"
 else printf '%s\n' "$HOME/.local/share/nocturne/$wallpaper" >> "$backup/new-files.txt"; fi
 cp "$ROOT/assets/$wallpaper" "$HOME/.local/share/nocturne/$wallpaper"
done
# The lock screen follows the chosen wallpaper; nocturne-wallpaper repoints this link.
[[ -e "$HOME/.local/share/nocturne/lock.png" ]] || ln -sfn "$HOME/.local/share/nocturne/wallpaper-clean.png" "$HOME/.local/share/nocturne/lock.png"
# Retire the previous bar, notification daemon and wallpaper setter: stop them and move their configs into the backup.
for process in "${legacy_packages[@]}"; do pkill -u "$UID" -x "$process" 2>/dev/null || true; done
for name in "${legacy_configs[@]}"; do
    if [[ -e "$HOME/.config/$name" ]]; then
        mkdir -p "$backup/.config"
        mv "$HOME/.config/$name" "$backup/.config/$name"
        printf 'Moved ~/.config/%s to the backup; it is no longer used.\n' "$name"
    fi
done
python - "$HOME" <<'PY'
from pathlib import Path
import sys
home=Path(sys.argv[1])
for name in ['qt5ct','qt6ct']:
 p=home/'.config'/name/(name+'.conf')
 p.write_text(p.read_text().replace('@@HOME@@',str(home)))
PY
chmod +x "$HOME"/.local/bin/nocturne-*
if command -v gsettings >/dev/null; then
    gsettings list-recursively org.gnome.desktop.interface > "$backup/gsettings-interface.txt"
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
    gsettings set org.gnome.desktop.interface icon-theme Nocturne
    gsettings set org.gnome.desktop.interface cursor-theme Nocturne-Cursors
    gsettings set org.gnome.desktop.interface cursor-size 28
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
fi
# Disable the competing D-Bus notification service, recording its prior state.
if systemctl --user cat dunst.service >/dev/null 2>&1; then
    systemctl --user is-enabled dunst.service > "$backup/dunst.enabled" 2>&1 || true
    if [[ -e "$HOME/.config/systemd/user/dunst.service" || -L "$HOME/.config/systemd/user/dunst.service" ]]; then
        mkdir -p "$backup/.config/systemd/user"
        cp -a "$HOME/.config/systemd/user/dunst.service" "$backup/.config/systemd/user/"
    else printf '%s\n' "$HOME/.config/systemd/user/dunst.service" >> "$backup/new-files.txt"; fi
    systemctl --user mask --now dunst.service
    systemctl --user daemon-reload
fi
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload
    hyprctl dispatch "hl.dsp.exec_cmd('~/.local/bin/nocturne-session restart')"
fi
printf '\nNocturne installed. User backup: %s\nLog out when convenient to apply every environment setting.\n' "$backup"
