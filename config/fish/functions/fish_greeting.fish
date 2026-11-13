function fish_greeting
    if command -q fastfetch
        if test "$COLUMNS" -ge 95
            fastfetch
        else
            fastfetch --logo none
        end
    else
        set_color $penumbra_violet
        printf '\n  ◈  P E N U M B R A\n'
        set_color normal
    end
end
