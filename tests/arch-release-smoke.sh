#!/usr/bin/env bash
# Run as root in a disposable, provisioned Arch VM. Both directories hold a full package set.
set -euo pipefail
[[ $# == 3 ]] || { echo 'Usage: arch-release-smoke.sh OLD_PACKAGES NEW_PACKAGES TEST_USER' >&2; exit 2; }
old=$1 new=$2 account=$3
home=$(getent passwd "$account" | cut -d: -f6)
[[ $EUID == 0 && -d $home && $account != root && ! -e $home/.config/mango ]] || exit 2
user() {
    runuser -u "$account" -- env HOME="$home" dbus-run-session -- "$@"
}
apply() {
    local packages=$1 version
    pacman -U --noconfirm -- "$packages"/*.pkg.tar.zst
    penumbra-install --system-only --offline --skip-packages --remove-legacy no --shell keep --user "$account"
    user penumbra-install --user-only --offline --yes
    version=$(penumbra-install --version)
    [[ $version == "$(< /usr/share/penumbra/installed-version)" ]]
    [[ $version == "$(<"$home/.local/share/penumbra/installed-version")" ]]
    local shell=config/quickshell/penumbra
    diff <(cd "/usr/share/penumbra-desktop/$shell" && find . -type f | sort) \
         <(cd "$home/.${shell}" && find . -type f | sort)
}
apply "$old"
first=$(penumbra-install --version)
user bash -c 'echo "gap_outer_horizontal=11" >> "$HOME/.config/mango/user.conf"
    echo "font_size 15" >> "$HOME/.config/kitty/user.conf"
    sed -i "s/^scale=.*/scale=1.25/" "$HOME/.config/penumbra/settings.conf"
    echo "{\"reducedMotion\":true}" > "$HOME/.config/penumbra/shell.json"'
custom=("$home"/.config/{mango/user.conf,kitty/user.conf,penumbra/shell.json,penumbra/settings.conf})
before=$(sha256sum "${custom[@]}")
stock=$(sha256sum "$home/.config/mango/keybinds.conf")
apply "$new"
[[ $(vercmp "$(penumbra-install --version)" "$first") == 1 ]]
[[ $(sha256sum "${custom[@]}") == "$before" ]]
cmp /usr/share/penumbra-desktop/config/mango/keybinds.conf "$home/.config/mango/keybinds.conf"
apply "$old"
[[ $(penumbra-install --version) == "$first" && $(sha256sum "${custom[@]}") == "$before" ]]
[[ $(sha256sum "$home/.config/mango/keybinds.conf") == "$stock" ]]
echo 'Arch release install, upgrade and downgrade passed.'
