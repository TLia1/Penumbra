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
