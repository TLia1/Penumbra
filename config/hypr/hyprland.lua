-- PENUMBRA / Hyprland 0.56 Lua configuration
-- Keyboard, Num Lock, scale and the terminal come from ~/.config/penumbra/settings.conf, which
-- ./install.sh and the shell's Settings write; screens from ~/.config/penumbra/monitors.lua, which
-- Settings → Displays writes. Put your own settings in ~/.config/hypr/user.lua, which is read last
-- and survives ./install.sh.
local home = os.getenv("HOME")
-- Colours come from palette/palette.toml (tools/build-palette.py), and penumbra-theme rewrites them
-- with the theme you choose. In light mode the shadow is fainter and the blur doesn't darken;
-- penumbra-theme gives a running Hyprland the same (hyprland_lua there).
local c = dofile(home .. "/.config/hypr/colors.lua")
local light = c.mode == "light"
-- settings.conf as a table, read afresh each time (bindings below call it when pressed).
local function settings()
 local s = {kb_layout = "us", kb_variant = "", kb_options = "", scale = "auto", numlock = "on", terminal = "kitty", file_manager = "io.github.lia.Files"}
 local file = io.open(home .. "/.config/penumbra/settings.conf")
 if file then
  for line in file:lines() do
   local key, value = line:match("^([a-z_]+)=(.*)$")
   if key then s[key] = value end
  end
  file:close()
 end
 return s
end
local s = settings()
-- Every screen without a rule of its own in monitors.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = s.scale })
local monitors = io.open(home .. "/.config/penumbra/monitors.lua")
if monitors then monitors:close(); dofile(home .. "/.config/penumbra/monitors.lua") end
hl.env("XCURSOR_THEME", "Penumbra-Cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
-- GTK apps ask the file chooser portal for Open and Save dialogs: Lia Files once it is installed.
hl.env("GTK_USE_PORTAL", "1")
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
  col = { active_border = {colors = {"rgba(" .. c.accent .. "ee)", "rgba(" .. c.accentDeep .. "bb)"}, angle = 45}, inactive_border = "rgba(" .. c.black .. "ff)" } },
 decoration = { rounding = sharp and 0 or 16, rounding_power = 2, active_opacity = 1, inactive_opacity = 0.97,
  shadow = {enabled = true, range = 28, render_power = 3, color = light and "rgba(" .. c.shade .. "30)" or "rgba(" .. c.onAccent .. "88)",
   color_inactive = light and "rgba(00000022)" or "rgba(00000055)"},
  glow = {enabled = true, range = 18, render_power = 3, color = "rgba(" .. c.accentDeep .. "40)", color_inactive = "rgba(00000000)"},
  blur = {enabled = true, size = 6, passes = 3, vibrancy = 0.2, noise = 0.02, contrast = 1.1, brightness = light and 1 or 0.9, popups = true} },
 animations = {enabled = true},
 dwindle = {preserve_split = true},
 input = {kb_layout = s.kb_layout, kb_variant = s.kb_variant, kb_options = s.kb_options, numlock_by_default = s.numlock == "on",
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
-- The terminal chosen in Settings → Default apps (its desktop file, e.g. kitty or foot).
local function terminal() hl.exec_cmd("gtk-launch " .. settings().terminal .. " || kitty") end
hl.bind("SUPER + Return", terminal)
hl.bind("SUPER + Q", terminal)
-- The file manager chosen in Settings → Default apps.
hl.bind("SUPER + E", function() hl.exec_cmd("gtk-launch " .. settings().file_manager .. " || lia-files || dolphin") end)
exec("SUPER + R", "~/.local/bin/penumbra-launcher")
exec("SUPER + space", "~/.local/bin/penumbra-launcher")
-- Your default web browser (Settings → Default apps, or xdg-settings set default-web-browser NAME.desktop).
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
-- Every workspace at a glance: Super and the key left of 1 (` on QWERTY, ² on AZERTY), or four
-- fingers up on a touchpad.
exec("SUPER + code:49", "quickshell -c penumbra ipc call panel overview")
hl.gesture({fingers=4, direction="up", action=function() hl.exec_cmd("quickshell -c penumbra ipc call panel overview") end})
-- Caps Lock shows a popup saying whether it is on; the key still reaches the window.
hl.bind("Caps_Lock", hl.dsp.exec_cmd("quickshell -c penumbra ipc call osd capsLock"), {release=true, non_consuming=true, ignore_mods=true})
exec("Print", "~/.local/bin/penumbra-shot")
exec("SHIFT + Print", "~/.local/bin/penumbra-shot annotate")
-- Record the screen; press again (or click the red capsule) to stop.
exec("CTRL + Print", "~/.local/bin/penumbra-record")
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
-- Pin a floating window (picture-in-picture, a note) so it follows you to every workspace.
hl.bind("SUPER + P", hl.dsp.window.pin())
-- Group windows into tabs; Super+Tab and Super+Shift+Tab step through the group.
hl.bind("SUPER + G", hl.dsp.group.toggle())
hl.bind("SUPER + Tab", hl.dsp.group.next())
hl.bind("SUPER + SHIFT + Tab", hl.dsp.group.prev())
-- A scratchpad workspace that slides over the current one: Super+Shift+S sends a window there.
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("scratch"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({workspace="special:scratch"}))
-- Arrows focus; with Shift they move the window, with Ctrl they resize it (repeating while held).
local step = {left={-40, 0}, right={40, 0}, up={0, -40}, down={0, 40}}
for _, d in ipairs({"left", "right", "up", "down"}) do
 hl.bind("SUPER + "..d, hl.dsp.focus({direction=d}))
 hl.bind("SUPER + SHIFT + "..d, hl.dsp.window.move({direction=d}))
 hl.bind("SUPER + CTRL + "..d, hl.dsp.window.resize({x=step[d][1], y=step[d][2], relative=true}), {repeating=true})
end
-- Physical keycodes keep the number-row workspace shortcuts working on any layout (AZERTY included).
-- Super+Alt sends the window without following it.
for i=1,10 do
 hl.bind("SUPER + code:"..(i+9), hl.dsp.focus({workspace=i}))
 hl.bind("SUPER + SHIFT + code:"..(i+9), hl.dsp.window.move({workspace=i}))
 hl.bind("SUPER + ALT + code:"..(i+9), hl.dsp.window.move({workspace=i, follow=false}))
end
-- Three-finger swipes switch workspaces on a touchpad.
hl.gesture({fingers=3, direction="horizontal", action="workspace"})
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
-- Browser video popped out: floating, on every workspace, keeping its shape.
hl.window_rule({name="pip", match={title="^(Picture-in-Picture|Picture in picture)$"}, float=true, pin=true, keep_aspect_ratio=true, size="480 270"})
-- Open and save dialogs float over their app instead of splitting the screen.
hl.window_rule({name="dialogs", match={title="^(Open File|Open Files|Open Folder|Select Folder|Save File|Save As|Save Image|File Upload|Choose Files?)(.*)$"}, float=true, size="900 600", center=true})
-- Fullscreen windows (videos, games) keep the screen from dimming and locking.
hl.window_rule({name="fullscreen-awake", match={class=".*"}, idle_inhibit="fullscreen"})
-- Frosted glass behind every Penumbra shell surface and the launcher.
hl.layer_rule({name="glass", match={namespace="^(penumbra-.*|rofi)$"}, blur=true, ignore_alpha=0.3})
-- The screenshot overlay must be gone at once, before grim reads the screen.
hl.layer_rule({name="shot", match={namespace="^penumbra-shot$"}, no_anim=true})
hl.window_rule({name="suppress-maximize", match={class=".*"}, suppress_event="maximize"})
hl.on("hyprland.start", function() hl.exec_cmd("~/.local/bin/penumbra-session") end)
-- Your own settings, if any, override everything above.
local user = io.open(home .. "/.config/hypr/user.lua")
if user then user:close(); dofile(home .. "/.config/hypr/user.lua") end
