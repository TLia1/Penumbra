# Penumbra on Arch Linux and the distributions built on it (EndeavourOS, CachyOS, Manjaro...).
# install.sh sources this file; EXTENDING.md lists what a distribution's file must define.

DISTRO_NAME='Arch Linux'
# The bar's launcher button: a JetBrainsMono Nerd Font glyph (nf-md-arch).
DISTRO_GLYPH='󰣇'
# What fish's `update` abbreviation runs.
DISTRO_UPDATE_COMMAND='sudo pacman -Syu'

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
    # Passwords apps save, unlocked when you sign in
    gnome-keyring seahorse
    # Screenshots, screen recording, clipboard, color picker, emoji and symbols
    grim slurp satty wf-recorder hyprpicker cliphist wl-clipboard wtype unicode-emoji noto-fonts-emoji
    # Used by the helper scripts and build tools
    pacman-contrib flatpak libnotify librsvg python-pillow xorg-xcursorgen
)
# Replaced by the Quickshell shell (bar, notifications, OSD) and awww (wallpaper).
LEGACY_PACKAGES=(waybar mako swaybg)
# The boot splash, offered by ./install.sh --boot-only.
PLYMOUTH_PACKAGES=(plymouth)

# pkg_install PACKAGE...: install what is missing. Uses the currently synced repositories; never
# refresh the database alone. pacman asks about conflicts and replacements itself, unless nobody is
# there to answer.
pkg_install() {
    local confirm=()
    interactive || confirm=(--noconfirm)
    pacman -S --needed "${confirm[@]}" "$@"
}

# pkg_installed PACKAGE... → the ones that are installed, one per line.
pkg_installed() { pacman -Qq "$@" 2>/dev/null || true; }

# pkg_versions PACKAGE... → "name version" per line, kept in the backup before removing them.
pkg_versions() { pacman -Q "$@"; }

# pkg_remove PACKAGE...: remove them without asking (the installer already asked). -s also drops
# their now-unneeded dependencies, never explicitly installed packages.
pkg_remove() { pacman -Rns --noconfirm "$@"; }
