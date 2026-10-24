-- PENUMBRA / Hyprland 0.56 Lua configuration
-- Keyboard, Num Lock and scale come from ~/.config/penumbra/settings.conf (see ./install.sh --help).
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "@@SCALE@@" })
hl.env("XCURSOR_THEME", "Penumbra-Cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "Breeze-Dark")
hl.config({
 xwayland = {
    force_zero_scaling = true
 },
 cursor = { no_hardware_cursors = 1, enable_hyprcursor = false },
 general = { gaps_in = 6, gaps_out = 14, border_size = 2, resize_on_border = true, layout = "dwindle",
  col = { active_border = {colors = {"rgba(a78bfaee)", "rgba(6d28d9bb)"}, angle = 45}, inactive_border = "rgba(282333ff)" } },
 decoration = { rounding = 16, rounding_power = 2, active_opacity = 1, inactive_opacity = 0.97,
  shadow = {enabled = true, range = 28, render_power = 3, color = "rgba(1a0b2e88)", color_inactive = "rgba(00000055)"},
  glow = {enabled = true, range = 18, render_power = 3, color = "rgba(7c3aed40)", color_inactive = "rgba(00000000)"},
  blur = {enabled = true, size = 6, passes = 3, vibrancy = 0.2, noise = 0.02, contrast = 1.1, brightness = 0.9, popups = true} },
 animations = {enabled = true},
 dwindle = {preserve_split = true},
 input = {kb_layout = "@@KB_LAYOUT@@", kb_variant = "@@KB_VARIANT@@", kb_options = "@@KB_OPTIONS@@", numlock_by_default = @@NUMLOCK@@,
  follow_mouse = 1, sensitivity = 0, touchpad = {natural_scroll = true}},
 -- A fresh lock screen (hyprlock from a TTY) can take over if the shell's ever dies while locked.
 misc = {disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0, allow_session_lock_restore = true},
})
hl.curve("penumbra", {type = "bezier", points = {{0.16, 1}, {0.3, 1}}})
hl.curve("soft", {type = "bezier", points = {{0.4, 0}, {0.2, 1}}})
hl.curve("linear", {type = "bezier", points = {{0, 0}, {1, 1}}})
for _, a in ipairs({
 {"windows", 4.5, "penumbra", "slide"}, {"windowsIn", 4, "penumbra", "popin 94%"},
 {"windowsOut", 3, "soft", "popin 96%"}, {"border", 5, "penumbra", nil},
 {"borderangle", 60, "linear", "loop"},
 {"fade", 3, "soft", nil}, {"workspaces", 4.5, "penumbra", "slide"},
 {"layers", 3.5, "penumbra", "fade"}
}) do hl.animation({leaf=a[1], enabled=true, speed=a[2], bezier=a[3], style=a[4]}) end
local function exec(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd)) end
exec("SUPER + Return", "kitty")
exec("SUPER + Q", "kitty")
exec("SUPER + E", "dolphin")
exec("SUPER + R", "~/.local/bin/penumbra-launcher")
exec("SUPER + space", "~/.local/bin/penumbra-launcher")
exec("SUPER + B", "firefox")
exec("SUPER + M", "~/.local/bin/penumbra-power")
exec("SUPER + L", "loginctl lock-session")
exec("SUPER + N", "quickshell -c penumbra ipc call notifications clear")
exec("SUPER + A", "quickshell -c penumbra ipc call panel control")
exec("SUPER + SHIFT + V", "~/.local/bin/penumbra-clipboard")
exec("SUPER + semicolon", "quickshell -c penumbra ipc call launcher emoji")
exec("SUPER + SHIFT + C", "~/.local/bin/penumbra-picker")
exec("SUPER + W", "~/.local/bin/penumbra-wallpaper next")
exec("SUPER + SHIFT + W", "quickshell -c penumbra ipc call panel wallpapers")
exec("SUPER + SHIFT + R", "~/.local/bin/penumbra-session restart")
exec("Print", "~/.local/bin/penumbra-shot")
exec("SHIFT + Print", "~/.local/bin/penumbra-shot annotate")
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
for _, d in ipairs({"left", "right", "up", "down"}) do hl.bind("SUPER + "..d, hl.dsp.focus({direction=d})) end
-- Physical keycodes keep the number-row workspace shortcuts working on any layout (AZERTY included).
for i=1,10 do
 hl.bind("SUPER + code:"..(i+9), hl.dsp.focus({workspace=i}))
 hl.bind("SUPER + SHIFT + code:"..(i+9), hl.dsp.window.move({workspace=i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse=true})
hl.bind("SUPER + mouse_down", hl.dsp.focus({workspace="e+1"}))
hl.bind("SUPER + mouse_up", hl.dsp.focus({workspace="e-1"}))
for key,cmd in pairs({
 XF86AudioRaiseVolume="~/.local/bin/penumbra-osd volume up",
 XF86AudioLowerVolume="~/.local/bin/penumbra-osd volume down",
 XF86AudioMute="~/.local/bin/penumbra-osd volume mute",
 XF86AudioMicMute="~/.local/bin/penumbra-osd microphone mute",
 XF86MonBrightnessUp="~/.local/bin/penumbra-osd brightness up", XF86MonBrightnessDown="~/.local/bin/penumbra-osd brightness down",
 XF86AudioPlay="playerctl play-pause", XF86AudioNext="playerctl next", XF86AudioPrev="playerctl previous"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true, repeating=true}) end
hl.window_rule({name="settings", match={class="^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|qt6ct)$"}, float=true, size="820 540", center=true})
hl.window_rule({name="annotate", match={class="^(com.gabm.satty)$"}, float=true, center=true})
-- Frosted glass behind every Penumbra shell surface and the launcher.
hl.layer_rule({name="glass", match={namespace="^(penumbra-.*|rofi)$"}, blur=true, ignore_alpha=0.3})
-- The screenshot overlay must be gone at once, before grim reads the screen.
hl.layer_rule({name="shot", match={namespace="^penumbra-shot$"}, no_anim=true})
hl.window_rule({name="suppress-maximize", match={class=".*"}, suppress_event="maximize"})
hl.on("hyprland.start", function() hl.exec_cmd("~/.local/bin/penumbra-session") end)
