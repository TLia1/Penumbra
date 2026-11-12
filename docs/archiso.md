# Install Arch Linux with Penumbra

`tools/install-arch.sh` is an interactive installer for a **64-bit x86 UEFI machine
booted from ArchISO**, with Secure Boot disabled. It **erases one whole disk**.
It does not preserve Windows, other installations or existing partitions.

The installer checks HTTPS connectivity and offers `iwctl` or a repair shell if
offline. It asks for the disk, swap size, hostname, timezone, locale, console and
desktop keyboard layouts, a desktop username, and whether that user should have
password-protected sudo. Root and user passwords are entered directly into
`passwd`, never stored in script arguments or a settings file.

The resulting GPT layout is:

| Partition | Size | Format | Mount |
|---|---|---|---|
| EFI System | 1 GiB | FAT32 | `/boot` |
| Swap | Prompted; default 8 GiB | Linux swap | swap |
| Root | Remaining space; at least 32 GiB | ext4 | `/` |

It installs the standard `linux` kernel, firmware, CPU microcode, NetworkManager,
Mesa Intel/AMD graphics support, multilib, rEFInd, Plymouth, Lia Files and
Penumbra. SDDM and the network/audio services are enabled for the next boot.
Lia Files builds as the new user; root installs its dependencies and resulting
package. Choosing **no sudo** never grants that user temporary sudo privileges.

Encryption, dual boot, BIOS boot, proprietary NVIDIA drivers and hibernation
configuration are outside this installer's scope. Swap is enabled, but it does
not add a `resume=` configuration. Allow time and disk space for the Rust build.
The ISO's Wi-Fi credentials are not copied: reconnect in the installed desktop.

## Publish the chroot support first

The installer clones **<https://github.com/TLia1/Panumbra>** (that spelling is the
repository's existing remote) and runs its `install.sh`. The accompanying change
to `install.sh` adds `--offline`, needed to configure services without a running
desktop or system manager. **Push that change to the GitHub branch you intend to
install before using the ISO.** No commit or push is performed by these files.
If the fetched installer lacks `--offline`, installation stops **before erasing
the disk**. To select a published branch or tag:

```bash
install-arch --penumbra-ref YOUR_BRANCH_OR_TAG
```

Lia Files is fetched from **<https://github.com/TLia1/Lia-s-file-linux>**, including
`build-aux/PKGBUILD`. At implementation time its recipe referenced an unpublished
`v1.0.0` tag. The installer uses the fetched recipe with a local `git archive` of
that **same commit**, replacing only `source`, `sha256sums` and `_srcdir` in its
build copy. The original recipe is preserved as `PKGBUILD.upstream`. This is a
snapshot build with the recipe's package version, not a claimed release build.
The checksum checks archive integrity; it is not an independent authenticity
signature. GitHub is the source of trust for both projects. You can review the
recipe and installer before confirming disk erasure.

Use `--lia-ref YOUR_BRANCH_OR_TAG` to select another published Lia Files revision.
Source commits are recorded in `/root/penumbra-install/sources.txt` on the target.
The Penumbra checkout remains at `~/Penumbra`; Lia's build files remain at
`~/.cache/lia-files-build`.

## Put the script in your Arch ISO

Run these commands on your Arch build machine, where `archiso` is already
installed. Use a **new profile/work directory** for this build. Building the ISO
does not run the installer or partition anything.

```bash
mkdir -p ~/penumbra-iso
cp -a /usr/share/archiso/configs/releng ~/penumbra-iso/profile

install -Dm755 \
  /home/lia/Documents/Codes-project/Penumbra/tools/install-arch.sh \
  ~/penumbra-iso/profile/airootfs/usr/local/bin/install-arch

# ArchISO resets file modes: declare the executable permission in the profile.
cat >> ~/penumbra-iso/profile/profiledef.sh <<'EOF'

file_permissions["/usr/local/bin/install-arch"]="0:0:755"
EOF

# releng already provides most of these; ensure every installer tool is included.
for pkg in arch-install-scripts curl git less iwd parted gptfdisk dosfstools \
           e2fsprogs util-linux kbd efibootmgr python; do
  grep -qxF "$pkg" ~/penumbra-iso/profile/packages.x86_64 || \
    printf '%s\n' "$pkg" >> ~/penumbra-iso/profile/packages.x86_64
done

sudo mkarchiso -v \
  -w ~/penumbra-iso/work \
  -o ~/penumbra-iso/out \
  ~/penumbra-iso/profile
```

The resulting `.iso` is in `~/penumbra-iso/out/`. When rebuilding, use a fresh
work directory (for example `-w ~/penumbra-iso/work-2`). If a build was interrupted,
check `findmnt` for remaining mounts before removing any old work directory.

Boot the ISO in **UEFI mode**, then at its root prompt run:

```bash
install-arch
```

The installer does not auto-start or reboot. It displays the selected disk and
requires typing `ERASE /dev/your-disk` exactly. Mounted disks, active mapped
devices, and disks backing swap or loop devices are rejected. Test your ISO in
a UEFI VM with a disposable virtual disk before using it on a physical machine.

The profile uses ArchISO's documented `airootfs` overlay and `file_permissions`
mechanism: [official profile documentation](https://github.com/archlinux/archiso/blob/master/docs/README.profile.rst).
See also [mkarchiso](https://man.archlinux.org/man/mkarchiso.1).

## Boot setup

The EFI partition holds `vmlinuz-linux` and `initramfs-linux.img`. rEFInd has
explicit graphical and console-recovery entries using the **installed root's
UUID**, plus the Penumbra theme. Its main binary is
`/boot/EFI/refind/refind_x64.efi`; a separate fallback copy lives at
`/boot/EFI/BOOT/BOOTX64.EFI`. The installer attempts an NVRAM entry; if firmware
rejects it, choose the disk's fallback boot option or the EFI file in firmware.
Future rEFInd binary upgrades require refreshing both installed EFI copies from
`/usr/share/refind/refind_x64.efi`.

Plymouth uses Penumbra's theme and a `systemd` mkinitcpio configuration with
`plymouth`, `microcode` and `kms` hooks. `mkinitcpio -P` regenerates the initramfs;
the installer checks that it contains the theme. CPU microcode is included in
the initramfs, so the rEFInd entries do not need a separate microcode image.
See [Plymouth](https://wiki.archlinux.org/title/Plymouth) and
[microcode](https://wiki.archlinux.org/title/Microcode).

## If installation stops

The script stops on command failure and never reboots automatically. After
partitioning, it leaves the target mounted at `/mnt/penumbra` so you can inspect
it. It disables only the swap partition it activated. The base package manager
log is `/mnt/penumbra/var/log/pacman.log`.

**Do not rerun `install-arch` as a resume command:** it starts again with disk
partitioning. From the same live session you can enter the partial installation:

```bash
arch-chroot /mnt/penumbra
```

Inspect the failed step and repair it manually. The copied installer and settings
are under `/root/penumbra-install`; `--inside-chroot` is an internal first-install
stage, not a resumable repair command. If you want a clean restart, exit the
chroot, unmount `/mnt/penumbra` with `umount -R /mnt/penumbra`, then run the
installer and confirm erasure again.
