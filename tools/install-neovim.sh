#!/usr/bin/env bash
# Install only the Neovim configuration; no desktop or system changes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v nvim >/dev/null
command -v git >/dev/null
config_root=${XDG_CONFIG_HOME:-$HOME/.config}
state_root=${XDG_STATE_HOME:-$HOME/.local/state}
destination="$config_root/nvim"
backup=$(mktemp -d "$state_root/penumbra/backups/neovim-XXXXXXXX" 2>/dev/null) || {
    mkdir -p "$state_root/penumbra/backups"
    backup=$(mktemp -d "$state_root/penumbra/backups/neovim-XXXXXXXX")
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
