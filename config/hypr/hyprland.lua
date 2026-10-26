-- PENUMBRA / Hyprland 0.56 Lua configuration
-- Keyboard, Num Lock, scale and the cursor mode come from ~/.config/penumbra/settings.conf (see
-- ./install.sh --help). Put your own settings in ~/.config/hypr/user.lua, which is read last and
-- survives ./install.sh.
local home = os.getenv("HOME")
-- Colours come from palette/palette.toml (tools/build-palette.py).
local c = dofile(home .. "/.config/hypr/colors.lua")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "@@SCALE@@" })
hl.env("XCURSOR_THEME", "Penumbra-Cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- Rounded or sharp corners, as penumbra-corners records them.
local corners = io.open(home .. "/.local/state/penumbra/corners")
local sharp = corners ~= nil and corners:read("l") == "sharp"
if corners then corners:close() end
hl.config({
 xwayland = {
    force_zero_scaling = true
 },
 -- Software cursors in virtual machines, where hardware cursors often draw wrongly; automatic elsewhere.
 cursor = { no_hardware_cursors = @@SOFTWARE_CURSOR@@, enable_hyprcursor = false },
 general = { gaps_in = 6, gaps_out = 14, border_size = 2, resize_on_border = true, layout = "dwindle",
  col = { active_border = {colors = {"rgba(" .. c.violet .. "ee)", "rgba(" .. c.violetDeep .. "bb)"}, angle = 45}, inactive_border = "rgba(" .. c.black .. "ff)" } },
 decoration = { rounding = sharp and 0 or 16, rounding_power = 2, active_opacity = 1, inactive_opacity = 0.97,
  shadow = {enabled = true, range = 28, render_power = 3, color = "rgba(" .. c.violetInk .. "88)", color_inactive = "rgba(00000055)"},
  glow = {enabled = true, range = 18, render_power = 3, color = "rgba(" .. c.violetDeep .. "40)", color_inactive = "rgba(00000000)"},
  blur = {enabled = true, size = 6, passes = 3, vibrancy = 0.2, noise = 0.02, contrast = 1.1, brightness = 0.9, popups = true} },
 animations = {enabled = true},
 dwindle = {preserve_split = true},
 input = {kb_layout = "@@KB_LAYOUT@@", kb_variant = "@@KB_VARIANT@@", kb_options = "@@KB_OPTIONS@@", numlock_by_default = "@@NUMLOCK@@" == "on",
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
-- Your default web browser (xdg-settings set default-web-browser NAME.desktop to change it).
exec("SUPER + B", "gtk-launch \"$(xdg-settings get default-web-browser)\"")
exec("SUPER + M", "~/.local/bin/penumbra-power")
exec("SUPER + L", "loginctl lock-session")
exec("SUPER + N", "quickshell -c penumbra ipc call notifications clear")
exec("SUPER + A", "quickshell -c penumbra ipc call panel control")
exec("SUPER + comma", "quickshell -c penumbra ipc call panel settings")
exec("SUPER + SHIFT + V", "~/.local/bin/penumbra-clipboard")
exec("SUPER + semicolon", "quickshell -c penumbra ipc call launcher emoji")
exec("SUPER + SHIFT + C", "~/.local/bin/penumbra-picker")
exec("SUPER + W", "~/.local/bin/penumbra-wallpaper next")
exec("SUPER + SHIFT + W", "quickshell -c penumbra ipc call panel wallpapers")
exec("SUPER + SHIFT + R", "~/.local/bin/penumbra-session restart")
exec("Print", "~/.local/bin/penumbra-shot")
exec("SHIFT + Print", "~/.local/bin/penumbra-shot annotate")
-- Record the screen; press again (or click the red capsule) to stop.
exec("CTRL + Print", "~/.local/bin/penumbra-record")
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
-- Volume and brightness repeat while held; toggles (mute, play/pause) fire once per press.
for key,cmd in pairs({
 XF86AudioRaiseVolume="~/.local/bin/penumbra-osd volume up",
 XF86AudioLowerVolume="~/.local/bin/penumbra-osd volume down",
 XF86MonBrightnessUp="~/.local/bin/penumbra-osd brightness up", XF86MonBrightnessDown="~/.local/bin/penumbra-osd brightness down"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true, repeating=true}) end
for key,cmd in pairs({
 XF86AudioMute="~/.local/bin/penumbra-osd volume mute",
 XF86AudioMicMute="~/.local/bin/penumbra-osd microphone mute",
 XF86AudioPlay="playerctl play-pause", XF86AudioPause="playerctl pause",
 XF86AudioNext="playerctl next", XF86AudioPrev="playerctl previous"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true}) end
hl.window_rule({name="settings", match={class="^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|qt6ct)$"}, float=true, size="820 540", center=true})
hl.window_rule({name="annotate", match={class="^(com.gabm.satty)$"}, float=true, center=true})
-- Frosted glass behind every Penumbra shell surface and the launcher.
hl.layer_rule({name="glass", match={namespace="^(penumbra-.*|rofi)$"}, blur=true, ignore_alpha=0.3})
-- The screenshot overlay must be gone at once, before grim reads the screen.
hl.layer_rule({name="shot", match={namespace="^penumbra-shot$"}, no_anim=true})
hl.window_rule({name="suppress-maximize", match={class=".*"}, suppress_event="maximize"})
hl.on("hyprland.start", function() hl.exec_cmd("~/.local/bin/penumbra-session") end)
-- Your own settings, if any, override everything above.
local user = io.open(home .. "/.config/hypr/user.lua")
if user then user:close(); dofile(home .. "/.config/hypr/user.lua") end
