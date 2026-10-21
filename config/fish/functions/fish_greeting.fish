function fish_greeting
    if command -q fastfetch
        if test "$TERM" = xterm-kitty; and test "$COLUMNS" -ge 95
            fastfetch
        else
            fastfetch --logo none
        end
    else
        set_color b69af7
        printf '\n  ◈  N O C T U R N E\n'
        set_color normal
    end
end
