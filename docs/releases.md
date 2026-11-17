# Penumbra releases on Arch

Each release has a source tag such as `v0.1.0` and four local pacman packages.
`penumbra-desktop` contains the shell, helpers, wallpapers, greeter and stock
configuration. Add `penumbra-apps` for application themes and file manager
actions, `penumbra-editor` for Neovim, and `penumbra-boot` for the optional
boot artwork. The add-ons require the exact core package version and revision.

## Install or upgrade with packages

Keep each release's archives in a separate directory. From the directory
containing the downloaded release assets, verify the checksums, install the
selected packages together, then apply the release as your desktop user.

```bash
sha256sum --check --ignore-missing SHA256SUMS
sudo pacman -U ./penumbra-*.pkg.tar.zst
penumbra-install
```

The wildcard installs all four packages. For a core-only desktop, pass just
`./penumbra-desktop-*.pkg.tar.zst` to pacman. On upgrade, include every
Penumbra add-on already installed in the same transaction.

Pacman owns the stock bundle in `/usr/share/penumbra-desktop`.
`penumbra-install` installs desktop dependencies, applies the system setup, and
renders personal copies using the account's saved preferences. Each additional
desktop user runs `penumbra-install --user-only`. Preview either operation with
`--plan`. Run the same two steps after upgrading the packages.

`penumbra-install --version` reports the available bundle. Each successfully
applied phase records its version in `/usr/share/penumbra/installed-version`
or `~/.local/share/penumbra/installed-version`. If applying stops partway
through, correct the reported error and rerun it. The install journal and
backups identify the files changed before the interruption.

## Install or upgrade directly from source

```bash
git clone https://github.com/TLia1/Panumbra.git Penumbra
cd Penumbra
git fetch --tags
git switch --detach v0.1.0
./install.sh
```

For a later release, fetch the tags, switch to the desired tag and rerun
`./install.sh`. A development checkout or an extracted source tree also works
directly with `./install.sh`. For an existing development branch, update it with
`git pull --ff-only` before applying. Source installs include all integrations.
The packaged and source entry points share preferences, override files and backups.

To build the four pacman archives yourself, install Arch's `base-devel` first.
Run the builder as your regular user from the source tree. It packages the
current working files, including local edits.

```bash
tools/build-arch-packages.sh "dist/arch/$(cat VERSION)"
```

## Roll back one release

1. From the saved **previous release's** directory, install its core and matching
   add-ons together with `sudo pacman -U ./penumbra-*.pkg.tar.zst`. On a source
   install, switch the checkout back to the previous tag or commit.
2. Run `penumbra-install` (packages) or `./install.sh` (source). For each
   additional account, apply the previous release with `--user-only`.
3. Check the applied version and log back into Mango. The installer reuses the
   saved settings, shell preferences, palette, and Mango, Kitty and Neovim
   override files. If you edited a stock file directly, its previous copy is in
   the timestamped installer backup. Boot loader and initramfs changes have
   their own [boot backup recovery procedure](boot-themes.md#restore-a-boot-backup).

## Migration for 0.1.0

The first versioned release adopts the unversioned installer's configuration
in place. Both use the same settings format and override paths. The first
successful application records the transition from `unversioned` to `0.1.0`
in the phase's backup journal. A compatible downgrade retains unrecognized
preference keys for use when returning to the newer release. To return to the
pre-release desktop, rerun the installer from the original source revision.
That installer predates version receipts. After it succeeds, remove
`~/.local/share/penumbra/installed-version` for the reverted account and
`/usr/share/penumbra/installed-version` if you also reverted the system phase.

## Cutting the next release

Update `VERSION`, the standalone `RELEASE_TAG` in `tools/install-arch.sh` and
these migration notes together. Pin the matching Lia Files commit in that script.
Document moves, retired stock files and any preference conversions in both
directions, and implement them in the installer before tagging.

Build both package sets and run this check as root inside a disposable Arch VM
with the desktop dependencies installed. Supply an unused regular account with
a working default file manager. The test applies both the system and user
phases, changes two overrides and a shell preference, upgrades, then downgrades
and compares the restored files.

```bash
tests/arch-release-smoke.sh /path/to/previous-packages /path/to/new-packages testuser
```

Pushing the matching version tag runs CI, builds the archives, checks the
packaged and source installers, and attaches the packages and `SHA256SUMS` to
the GitHub release.
