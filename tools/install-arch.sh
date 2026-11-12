#!/usr/bin/env bash
# Run from a UEFI-booted Arch ISO. This script ERASES ONE WHOLE DISK after confirmation.
set -Eeuo pipefail

PENUMBRA_URL=https://github.com/TLia1/Panumbra.git
LIA_URL=https://github.com/TLia1/Lia-s-file-linux.git
TARGET=/mnt/penumbra
WORK=''
MOUNTED=0
SWAP_ACTIVE=0
PHASE=preflight

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
ask() {
    local reply
    read -r -p "$1 [y/N] " reply || return 1
    [[ ${reply,,} == y || ${reply,,} == yes ]]
}
prompt() {
    local reply
    read -r -p "$2 [$3]: " reply || die 'Input closed.'
    printf -v "$1" '%s' "${reply:-$3}"
}
usage() {
    cat <<'EOF'
Usage: install-arch [--penumbra-ref BRANCH_OR_TAG] [--lia-ref BRANCH_OR_TAG]

Interactive x86_64 UEFI installation from ArchISO. Erases a whole disk and creates:
  1 GiB FAT32 EFI /boot, configurable swap, remaining space ext4 /.
Installs Arch, rEFInd, Plymouth, Lia Files and Penumbra. Prompts for networking,
disk, locale, timezone, keyboard, hostname, user, passwords and sudo membership.
GitHub default branches are used unless a branch/tag is supplied. Sources are
downloaded and checked before disk erasure. No unattended or erase-confirmation bypass.
See docs/archiso.md for ISO building, limitations and recovery instructions.
EOF
}

cleanup() {
    local status=$?
    trap - EXIT
    if (( SWAP_ACTIVE )); then swapoff "$SWAP_PART" || true; fi
    if (( status != 0 )); then
        printf '\nStopped during %s. No reboot will occur.\n' "$PHASE" >&2
        if (( MOUNTED )); then
            printf 'The partial installation remains mounted at %s for inspection.\nDo not rerun this installer to resume: it repartitions the disk. See docs/archiso.md.\n' "$TARGET" >&2
        fi
    fi
    [[ -z $WORK ]] || rm -rf -- "$WORK"
    exit "$status"
}

online() { curl -fsSL --connect-timeout 8 --max-time 20 https://archlinux.org/ -o /dev/null; }
connect_network() {
    local choice
    until online; do
        cat <<'EOF'
No working HTTPS connection to archlinux.org (DNS, clock or network may be wrong).
Plug in Ethernet, or choose:
  1) Open iwctl for Wi-Fi
  2) Open a shell for network/clock repair (exit to retry)
  3) Retry
  q) Quit
In iwctl: device list; station wlan0 scan; station wlan0 get-networks;
          station wlan0 connect YOUR_SSID; exit
Replace wlan0 with your device. iwctl asks for the Wi-Fi password itself.
EOF
        read -r -p '> ' choice || die 'Input closed.'
        case $choice in
            1) systemctl start iwd; iwctl || true ;;
            2) bash --noprofile --norc || true ;;
            3) ;;
            q|Q) exit 0 ;;
        esac
    done
    say 'Internet connection verified'
    timedatectl set-ntp true
    # Pacman signatures and HTTPS need a sensible clock before source/package downloads.
    until [[ $(timedatectl show -p NTPSynchronized --value) == yes ]]; do
        say 'Waiting for time synchronization'
        sleep 2
        if [[ $(timedatectl show -p NTPSynchronized --value) != yes ]]; then
            date -u
            ask 'Is this UTC time correct? Continue without waiting for NTP?' && break
        fi
    done
}

partition_path() {
    if [[ $1 =~ [0-9]$ ]]; then printf '%sp%s\n' "$1" "$2"; else printf '%s%s\n' "$1" "$2"; fi
}

validate_disk() {
    [[ -b $DISK && $(lsblk -dnro TYPE "$DISK") == disk ]] || die 'Select a whole disk, not a partition or mapped device.'
    [[ $(lsblk -dnro RO "$DISK") == 0 ]] || die 'This disk is read-only.'
    check_disk_usage
}

check_disk_usage() {
    local node kind swap backing source mounts nodes swaps loops holders
    # Includes the ISO USB, root/home mounts, mounted children and active swap partitions.
    mounts=$(lsblk -nrpo MOUNTPOINTS "$DISK") || die 'Could not inspect disk mounts.'
    [[ -z $(tr -d '[:space:]' <<< "$mounts") ]] || die 'Disk or one of its children is mounted/in use (possibly the installer USB).'
    nodes=$(lsblk -nrpo NAME,TYPE "$DISK") || die 'Could not inspect disk children.'
    [[ -n $nodes ]] || die 'Disk disappeared during inspection.'
    swaps=$(swapon --noheadings --raw --show=NAME) || die 'Could not inspect active swap.'
    loops=$(losetup --list --noheadings --output BACK-FILE) || die 'Could not inspect loop devices.'
    while read -r node kind; do
        [[ $kind == disk || $kind == part ]] || die "Active mapped device on disk: $node ($kind)."
        holders=$(find "/sys/class/block/${node##*/}/holders" -mindepth 1 -maxdepth 1 -print -quit) \
            || die "Could not inspect holders of $node."
        [[ -z $holders ]] || die "Device has active holders: $node."
        while read -r swap; do
            [[ -n $swap ]] || continue
            source=$(findmnt -nro SOURCE -T "$swap" 2>/dev/null || true)
            [[ $swap != "$node" && $source != "$node" ]] || die 'Disk contains active swap.'
        done <<< "$swaps"
        # A live ISO can also be backed by a file on this disk.
        while IFS= read -r backing; do
            [[ -n $backing ]] || continue
            source=$(findmnt -nro SOURCE -T "$backing" 2>/dev/null || true)
            [[ $source != "$node" ]] || die 'Disk backs an active loop device.'
        done <<< "$loops"
    done <<< "$nodes"
}

collect_settings() {
    say 'Installation disk (all existing partitions will be erased)'
    lsblk -dpo NAME,SIZE,MODEL,TRAN,RM,RO
    read -r -p 'Whole disk path (for example /dev/nvme0n1): ' DISK
    DISK=$(readlink -f -- "$DISK")
    validate_disk
    local bytes
    bytes=$(blockdev --getsize64 "$DISK")
    while true; do
        prompt SWAP_GIB 'Swap size in whole GiB' 8
        [[ $SWAP_GIB =~ ^[1-9][0-9]{0,3}$ ]] || { echo 'Use a positive integer (1–9999).'; continue; }
        (( bytes > (SWAP_GIB + 33) * 1024 * 1024 * 1024 )) && break
        echo 'Leave at least 32 GiB for root, plus the 1 GiB EFI partition.'
    done
    while true; do
        prompt HOSTNAME 'Hostname' penumbra
        [[ $HOSTNAME =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] && break
        echo 'Use 1–63 letters/digits/hyphens; no leading or trailing hyphen.'
    done
    while true; do
        prompt TIMEZONE 'Timezone (for example Europe/Paris)' UTC
        [[ $TIMEZONE != /* && $TIMEZONE != *..* && -f /usr/share/zoneinfo/$TIMEZONE ]] && break
        echo 'Use a name from /usr/share/zoneinfo.'
    done
    while true; do
        prompt LOCALE 'UTF-8 locale (for example fr_FR.UTF-8)' en_US.UTF-8
        [[ $LOCALE =~ ^[a-z]{2,3}_[A-Z]{2}\.UTF-8$ ]] \
            && grep -Eq "^#?${LOCALE//./\\.}[[:space:]]+UTF-8" /etc/locale.gen && break
        echo 'Choose a UTF-8 locale listed in /etc/locale.gen.'
    done
    while true; do
        prompt KEYMAP 'Console keymap (for example fr)' us
        [[ $KEYMAP =~ ^[a-zA-Z0-9_-]+$ ]] && loadkeys "$KEYMAP" && break
    done
    while true; do
        prompt LAYOUT 'Desktop XKB layout (for example fr or us,fr)' us
        [[ $LAYOUT =~ ^[a-z0-9_]+(,[a-z0-9_]+)*$ ]] && break
    done
    while true; do
        prompt DESKTOP_USER 'Create desktop user' lia
        [[ $DESKTOP_USER =~ ^[a-z_][a-z0-9_-]{0,30}$ && $DESKTOP_USER != root ]] && break
        echo 'Use a lowercase username, other than root, up to 31 characters.'
    done
    SUDO_USER_ENABLED=no
    if ask "Allow $DESKTOP_USER to use sudo (password required)?"; then SUDO_USER_ENABLED=yes; fi
}

fetch_sources() {
    PHASE='GitHub source preflight'
    WORK=$(mktemp -d /tmp/penumbra-arch.XXXXXXXX)
    chmod 755 "$WORK"
    local args=()
    [[ -z $PENUMBRA_REF ]] || args=(--branch "$PENUMBRA_REF")
    git clone --depth 1 "${args[@]}" "$PENUMBRA_URL" "$WORK/Penumbra"
    args=()
    [[ -z $LIA_REF ]] || args=(--branch "$LIA_REF")
    git clone --depth 1 "${args[@]}" "$LIA_URL" "$WORK/Lia-s-file-linux"
    [[ -f $WORK/Penumbra/install.sh && -f $WORK/Lia-s-file-linux/build-aux/PKGBUILD ]] || die 'GitHub checkout is missing an installer or PKGBUILD.'
    grep -q -- '--offline)' "$WORK/Penumbra/install.sh" \
        || die 'Publish the Penumbra install.sh --offline change to GitHub first, or use --penumbra-ref with a branch containing it. No disk has been erased.'
    PENUMBRA_COMMIT=$(git -C "$WORK/Penumbra" rev-parse HEAD)
    LIA_COMMIT=$(git -C "$WORK/Lia-s-file-linux" rev-parse HEAD)
    mkdir "$WORK/lia-build"
    cp "$WORK/Lia-s-file-linux/build-aux/PKGBUILD" "$WORK/lia-build/PKGBUILD.upstream"
    cp "$WORK/lia-build/PKGBUILD.upstream" "$WORK/lia-build/PKGBUILD"
    # The published recipe currently references a nonexistent v1.0.0 tag. Build its matching
    # fetched source instead, without executing a GitHub PKGBUILD as root or trusting SKIP.
    git -C "$WORK/Lia-s-file-linux" archive --format=tar.gz --prefix="Lia-s-file-linux-$LIA_COMMIT/" \
        -o "$WORK/lia-build/lia-files-$LIA_COMMIT.tar.gz" HEAD
    local checksum
    checksum=$(sha256sum "$WORK/lia-build/lia-files-$LIA_COMMIT.tar.gz")
    cat >> "$WORK/lia-build/PKGBUILD" <<EOF

# install-arch: use a verified local snapshot of the same GitHub commit as this recipe.
source=('lia-files-$LIA_COMMIT.tar.gz')
sha256sums=('${checksum%% *}')
_srcdir='Lia-s-file-linux-$LIA_COMMIT'
EOF
    say "Penumbra commit: $PENUMBRA_COMMIT"
    say "Lia Files commit: $LIA_COMMIT"
    echo 'The GitHub installer and PKGBUILD execute code during installation.'
    if ask 'Review the Lia Files build recipe and Penumbra installer?'; then
        less "$WORK/lia-build/PKGBUILD" "$WORK/Penumbra/install.sh"
    fi
}

partition_disk() {
    PHASE=partitioning
    validate_disk
    [[ ! -L $TARGET ]] || die 'Target mount path is a symlink.'
    [[ -z $(findmnt -rn -o TARGET | awk -v p="$TARGET" '$0 == p || index($0, p "/") == 1') ]] \
        || die "$TARGET or a child is already mounted."
    if [[ -d $TARGET ]]; then
        [[ -z $(find "$TARGET" -mindepth 1 -maxdepth 1 -print -quit) ]] || die "$TARGET is not empty."
    fi
    say 'Final disk-erasure confirmation'
    lsblk -po NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS "$DISK"
    printf 'ERASE %s → GPT: 1 GiB EFI /boot + %s GiB swap + ext4 root\n' "$DISK" "$SWAP_GIB"
    printf 'Host: %s | User: %s | Sudo: %s | Locale: %s | Zone: %s\n' \
        "$HOSTNAME" "$DESKTOP_USER" "$SUDO_USER_ENABLED" "$LOCALE" "$TIMEZONE"
    local confirmation
    read -r -p "Type ERASE $DISK exactly to continue: " confirmation
    [[ $confirmation == "ERASE $DISK" ]] || die 'Erasure cancelled.'
    validate_disk
    wipefs --all "$DISK"
    sfdisk --wipe always "$DISK" <<EOF
label: gpt
size=1GiB, type=U, name="EFI System"
size=${SWAP_GIB}GiB, type=S, name="Linux swap"
type=L, name="Arch Linux"
EOF
    partprobe "$DISK"
    udevadm settle
    BOOT_PART=$(partition_path "$DISK" 1)
    SWAP_PART=$(partition_path "$DISK" 2)
    ROOT_PART=$(partition_path "$DISK" 3)
    [[ -b $BOOT_PART && -b $SWAP_PART && -b $ROOT_PART ]] || die 'New partition devices did not appear.'
    mkfs.fat -F 32 -n PENUMBRAEFI "$BOOT_PART"
    mkswap -L penumbra-swap "$SWAP_PART"
    mkfs.ext4 -F -L penumbra-root "$ROOT_PART"
    mkdir -p "$TARGET"
    mount "$ROOT_PART" "$TARGET"
    MOUNTED=1
    mkdir -p "$TARGET/boot"
    mount -o umask=0077 "$BOOT_PART" "$TARGET/boot"
    swapon "$SWAP_PART"
    SWAP_ACTIVE=1
}

install_base() {
    PHASE='base installation'
    pacstrap -K "$TARGET" base base-devel linux linux-firmware mkinitcpio intel-ucode amd-ucode \
        networkmanager sudo git curl nano man-db man-pages refind efibootmgr plymouth \
        dosfstools e2fsprogs python dbus mesa vulkan-intel vulkan-radeon
    # Generate only our mounts and our swap, never unrelated live-environment swap entries.
    genfstab -U "$TARGET" | awk '$3 != "swap"' > "$TARGET/etc/fstab"
    printf 'UUID=%s none swap defaults 0 0\n' "$(blkid -s UUID -o value "$SWAP_PART")" >> "$TARGET/etc/fstab"
    install -d -m 700 "$TARGET/root/penumbra-install"
    cp -a "$WORK/lia-build" "$TARGET/root/penumbra-install/"
    cp -a "$WORK/Penumbra" "$TARGET/root/penumbra-install/"
    # Configuration contains no passwords, and is shell-escaped before being sourced in chroot.
    local key
    for key in TIMEZONE LOCALE KEYMAP LAYOUT HOSTNAME DESKTOP_USER SUDO_USER_ENABLED PENUMBRA_COMMIT LIA_COMMIT; do
        printf '%s=%q\n' "$key" "${!key}"
    done > "$TARGET/root/penumbra-install/settings"
    install -m 700 "${BASH_SOURCE[0]}" "$TARGET/root/penumbra-install/install-arch.sh"
    PHASE='system configuration and desktop installation'
    arch-chroot "$TARGET" /bin/bash /root/penumbra-install/install-arch.sh --inside-chroot
}

refind_config() {
    local root_uuid=$1
    cat <<'EOF'
timeout 5
scanfor manual
include themes/penumbra/theme.conf
menuentry "Arch Linux — Penumbra" {
    icon themes/penumbra/icons/os_arch.png
    loader /vmlinuz-linux
    initrd /initramfs-linux.img
EOF
    printf '    options "root=UUID=%s rw quiet splash"\n}\n' "$root_uuid"
    cat <<'EOF'
menuentry "Arch Linux — console recovery" {
    icon themes/penumbra/icons/os_arch.png
    loader /vmlinuz-linux
    initrd /initramfs-linux.img
EOF
    printf '    options "root=UUID=%s rw systemd.unit=multi-user.target"\n}\n' "$root_uuid"
}

copy_boot_tree() {
    # The ESP is FAT32: it cannot preserve Unix ownership/modes. Copy contents into an
    # explicit destination so retrying a partial copy cannot nest another theme folder.
    mkdir -p -- "$2"
    cp -r --no-preserve=ownership,mode -- "$1/." "$2/"
}

load_target_settings() {
    [[ $EUID == 0 && -f /root/penumbra-install/settings ]] || die 'Internal chroot stage only.'
    systemd-detect-virt --chroot --quiet || die 'Refusing to run the target stage outside a chroot.'
    # shellcheck disable=SC1091
    source /root/penumbra-install/settings
}

configure_target() {
    load_target_settings
    PHASE='target configuration'
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc || echo 'No writable hardware clock; NTP will set time at boot.'
    printf '%s UTF-8\nen_US.UTF-8 UTF-8\n' "$LOCALE" | sort -u > /etc/locale.gen
    locale-gen
    printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf
    printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf
    printf '%s\n' "$HOSTNAME" > /etc/hostname
    printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 %s.localdomain %s\n' "$HOSTNAME" "$HOSTNAME" > /etc/hosts
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
    fi
    pacman -Syu --noconfirm
    useradd -m -U -s /bin/bash "$DESKTOP_USER"
    if [[ $SUDO_USER_ENABLED == yes ]]; then
        usermod -aG wheel "$DESKTOP_USER"
        printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/10-wheel
        chmod 440 /etc/sudoers.d/10-wheel
        visudo -cf /etc/sudoers
    fi
    say 'Set the root password (also provides administration when sudo is disabled)'
    until passwd root; do echo 'Please retry.'; done
    say "Set the password for $DESKTOP_USER"
    until passwd "$DESKTOP_USER"; do echo 'Please retry.'; done
    systemctl enable NetworkManager systemd-timesyncd

    local home=/home/$DESKTOP_USER build repo
    build=$home/.cache/lia-files-build
    repo=$home/Penumbra
    install -d -o "$DESKTOP_USER" -g "$DESKTOP_USER" "$home/.cache"
    mv /root/penumbra-install/lia-build "$build"
    mv /root/penumbra-install/Penumbra "$repo"
    chown -R "$DESKTOP_USER:$DESKTOP_USER" "$build" "$repo"
    # A PKGBUILD is shell code: only makepkg as the unprivileged user evaluates it.
    # shellcheck disable=SC2016 # Expanded by the unprivileged inner shell.
    runuser -u "$DESKTOP_USER" -- bash -c 'cd "$1" && makepkg --printsrcinfo' _ "$build" > /root/penumbra-install/lia.SRCINFO
    local deps=() packages=()
    mapfile -t deps < <(awk '$1 ~ /^(depends|makedepends|checkdepends)(_x86_64)?$/ && $2 == "=" {print $3}' \
        /root/penumbra-install/lia.SRCINFO | sort -u)
    (( ${#deps[@]} )) || die 'No Lia Files dependencies found in the fetched recipe.'
    pacman -S --needed --noconfirm -- "${deps[@]}" gvfs gvfs-mtp gvfs-smb udisks2
    PHASE='building Lia Files'
    # shellcheck disable=SC2016 # Expanded by the unprivileged inner shell.
    runuser -u "$DESKTOP_USER" -- bash -c 'cd "$1" && makepkg --cleanbuild --noconfirm' _ "$build"
    mapfile -t packages < <(find "$build" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig')
    (( ${#packages[@]} )) || die 'Lia Files build produced no package.'
    pacman -U --noconfirm -- "${packages[@]}"
    command -v lia-files >/dev/null || die 'The built package did not install lia-files.'

    PHASE='installing Penumbra'
    bash "$repo/install.sh" --system-only --offline --user "$DESKTOP_USER" --distro arch \
        --layout "$LAYOUT" --shell fish --remove-legacy no --yes < /dev/null
    # A private D-Bus session lets gsettings/dconf save settings without a desktop login.
    runuser -u "$DESKTOP_USER" -- env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME \
        -u XDG_CACHE_HOME -u XDG_RUNTIME_DIR -u HYPRLAND_INSTANCE_SIGNATURE \
        HOME="$home" USER="$DESKTOP_USER" LOGNAME="$DESKTOP_USER" \
        dbus-run-session -- bash "$repo/install.sh" --user-only --offline --distro arch \
        --layout "$LAYOUT" --shell fish --file-manager io.github.lia.Files --yes < /dev/null

    configure_boot "$repo"
}

configure_boot() {
    local repo=$1
    PHASE='configuring rEFInd and Plymouth'
    [[ $(findmnt -nro FSTYPE -M /boot) == vfat ]] || die 'Mount the installation EFI partition at /boot first.'
    [[ -d $repo/boot/refind && -d $repo/boot/plymouth && -s /boot/vmlinuz-linux ]] \
        || die 'The desktop checkout or installed kernel is missing; boot repair cannot continue.'
    # Write a fresh known configuration: do not inherit the ISO's root= or archisodevice=.
    local root_uuid
    root_uuid=$(findmnt -nro UUID /)
    [[ -n $root_uuid ]] || die 'Cannot determine installed root UUID.'
    cat > /etc/mkinitcpio.conf <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd plymouth autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
EOF
    copy_boot_tree "$repo/boot/plymouth" /usr/share/plymouth/themes/penumbra
    if [[ -f /usr/share/plymouth/themes/spinner/keymap-render.png ]]; then
        cp /usr/share/plymouth/themes/spinner/keymap-render.png /usr/share/plymouth/themes/penumbra/
    fi
    plymouth-set-default-theme penumbra
    mkinitcpio -P
    # All kernels/initramfs live on FAT32 /boot; no EFI filesystem driver is needed.
    install -Dm644 /usr/share/refind/refind_x64.efi /boot/EFI/refind/refind_x64.efi
    copy_boot_tree "$repo/boot/refind" /boot/EFI/refind/themes/penumbra
    refind_config "$root_uuid" > /boot/EFI/refind/refind.conf
    printf '"Boot with splash" "root=UUID=%s rw quiet splash initrd=\\initramfs-linux.img"\n' \
        "$root_uuid" > /boot/refind_linux.conf
    # The fallback path works even when firmware rejects/forgets an NVRAM boot entry.
    mkdir -p /boot/EFI/BOOT
    cp /boot/EFI/refind/refind_x64.efi /boot/EFI/BOOT/BOOTX64.EFI
    cp /boot/EFI/refind/refind.conf /boot/EFI/BOOT/refind.conf
    copy_boot_tree /boot/EFI/refind/themes /boot/EFI/BOOT/themes
    [[ -s /boot/vmlinuz-linux && -s /boot/initramfs-linux.img ]] || die 'Kernel or initramfs missing.'
    lsinitcpio /boot/initramfs-linux.img > /root/penumbra-install/initramfs-contents.txt
    grep -q 'penumbra.plymouth' /root/penumbra-install/initramfs-contents.txt || die 'Plymouth theme missing from initramfs.'
    printf 'Penumbra %s\nLia Files %s\n' "$PENUMBRA_COMMIT" "$LIA_COMMIT" > /root/penumbra-install/sources.txt
}

main() {
    PENUMBRA_REF='' LIA_REF=''
    while (( $# )); do
        case $1 in
            -h|--help) usage; return ;;
            --penumbra-ref) PENUMBRA_REF=${2:?Missing branch/tag}; shift ;;
            --lia-ref) LIA_REF=${2:?Missing branch/tag}; shift ;;
            --inside-chroot) configure_target; return ;;
            *) die "Unknown option: $1" ;;
        esac
        shift
    done
    [[ $EUID == 0 ]] || die 'Run as root from the Arch ISO.'
    [[ -t 0 && -t 1 ]] || die 'An interactive terminal is required.'
    [[ $(uname -m) == x86_64 && -d /run/archiso ]] || die 'Boot the x86_64 Arch ISO first.'
    [[ -d /sys/firmware/efi && $(cat /sys/firmware/efi/fw_platform_size) == 64 ]] \
        || die 'Boot the ISO in 64-bit UEFI mode; rEFInd requires UEFI.'
    local command secureboot
    for command in curl git less iwctl timedatectl pacstrap arch-chroot genfstab sfdisk wipefs \
        partprobe udevadm mkfs.fat mkfs.ext4 mkswap swapon swapoff lsblk findmnt blockdev \
        losetup loadkeys efibootmgr python3; do
        command -v "$command" >/dev/null || die "Missing ISO tool: $command (see docs/archiso.md)."
    done
    for secureboot in /sys/firmware/efi/efivars/SecureBoot-*; do
        [[ -f $secureboot ]] || continue
        [[ $(od -An -j4 -N1 -tu1 "$secureboot" | tr -d ' ') == 0 ]] \
            || die 'Disable Secure Boot in firmware first; this installer does not sign boot binaries.'
    done
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    connect_network
    collect_settings
    fetch_sources
    partition_disk
    install_base
    PHASE='registering firmware boot entry'
    if ! efibootmgr --create --disk "$DISK" --part 1 --label 'Penumbra (rEFInd)' \
        --loader '\EFI\refind\refind_x64.efi'; then
        echo 'NVRAM entry could not be created. Use the firmware disk/fallback boot option.'
    fi
    sync
    swapoff "$SWAP_PART"
    SWAP_ACTIVE=0
    umount -R "$TARGET"
    MOUNTED=0
    say 'Installation complete. Remove the ISO/USB and reboot when ready.'
    echo 'Log in to Penumbra with your new account. Reconnect Wi-Fi in the desktop if needed.'
    echo 'The installer does not copy live-ISO Wi-Fi credentials. Source checkout: ~/Penumbra.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
