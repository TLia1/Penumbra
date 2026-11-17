#!/usr/bin/env bash
# Build from this source tree, including local changes. No root or network needed.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
[[ $# == 1 ]] || { echo 'Usage: tools/build-arch-packages.sh OUTPUT_DIRECTORY' >&2; exit 2; }
mkdir -p -- "$1"
out=$(cd -- "$1" && pwd)
version=$(<"$root/VERSION")
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid VERSION' >&2; exit 1; }
build=$(mktemp -d)
trap 'rm -rf -- "$build"' EXIT
cd "$build"
archive="penumbra-$version.tar.gz"
tar -C "$root" --sort=name --mtime="@${SOURCE_DATE_EPOCH:-0}" --owner=0 --group=0 \
    --transform="s,^,penumbra-$version/," --exclude=__pycache__ --exclude='*.pyc' \
    -czf "$archive" VERSION install.sh apps assets bin boot config distro licenses palette share system \
    tools/{install-boot.py,install-neovim.sh,render-install.py}
digest=$(sha256sum "$archive")
sed -e "s/@VERSION@/$version/g" -e "s/@SHA256@/${digest%% *}/g" \
    "$root/packaging/arch/PKGBUILD.in" > PKGBUILD
PKGDEST="$build" SRCDEST="$build" BUILDDIR="$build" PKGEXT=.pkg.tar.zst makepkg --cleanbuild --noconfirm
packages=(penumbra-*.pkg.tar.zst)
sha256sum -- "${packages[@]}" > SHA256SUMS
cp -- "${packages[@]}" SHA256SUMS "$out/"
