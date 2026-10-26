# Colours are in conf.d/penumbra-colors.fish, generated from palette/palette.toml.
# Put your own settings in ~/.config/fish/conf.d/: this file is replaced by ./install.sh.
if status is-interactive
    set -g fish_greeting
    starship init fish | source
    abbr --add ll 'ls -lah --color=auto'
    abbr --add update '@@DISTRO_UPDATE_COMMAND@@'
end
