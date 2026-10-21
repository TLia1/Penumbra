# Complete Nocturne configuration

Full installer, cursor generator, scripts and authored text configuration. Compiled Xcursor binaries are under `system/usr/share/icons/Nocturne-Cursors/cursors/`; their original SVGs are under `assets/cursors/`. Both are included alongside this Markdown file.

## `install.sh`

```bash
#!/usr/bin/env bash
# Nocturne installer. Run as the desktop user: ./install.sh
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-all}
case "$MODE" in all|--system-only|--user-only) ;; *) echo "Usage: $0 [--system-only|--user-only]" >&2; exit 2;; esac
STAMP=$(date +%Y%m%d-%H%M%S)
packages=(hyprland kitty fastfetch dolphin sddm waybar rofi fish starship swaybg mako hyprlock hypridle breeze breeze-cursors breeze-icons breeze-gtk papirus-icon-theme qt6ct qt5ct qt5-wayland qt5-quickcontrols2 blueman network-manager-applet networkmanager pavucontrol pipewire-pulse wireplumber ttf-jetbrains-mono-nerd inter-font grim slurp python-pillow polkit-kde-agent bluez bluez-utils brightnessctl playerctl xdg-desktop-portal-hyprland xdg-desktop-portal-gtk htop libnotify librsvg xorg-xcursorgen)
if [[ "$MODE" == --system-only ]]; then
    [[ $EUID == 0 ]] || { echo 'System phase needs sudo.' >&2; exit 1; }
    target=${SUDO_USER:-${2:-}}
    [[ -n "$target" && "$target" != root ]] || { echo 'Specify the desktop username as argument 2.' >&2; exit 1; }
    if [[ ${NOCTURNE_SKIP_PACKAGES:-0} != 1 ]]; then
        # Use currently synced repositories; never refresh the database alone.
        pacman -S --needed --noconfirm "${packages[@]}"
    fi
    backup="/var/lib/nocturne/backups/$STAMP"
    mkdir -p "$backup"
    getent passwd "$target" | cut -d: -f7 > "$backup/previous-shell.txt"
    for unit in bluetooth NetworkManager sddm; do
        systemctl is-enabled "$unit" > "$backup/$unit.enabled" 2>&1 || true
    done
    while IFS= read -r -d '' source; do
        rel=${source#"$ROOT/system/"}; dest="/$rel"
        if [[ -e "$dest" || -L "$dest" ]]; then mkdir -p "$backup/$(dirname "$rel")"; cp -a "$dest" "$backup/$rel"; else printf '%s\n' "$dest" >> "$backup/new-files.txt"; fi
        install -Dm644 "$source" "$dest"
    done < <(find "$ROOT/system" -type f -print0)
    usermod -s /usr/bin/fish "$target"
    systemctl enable --now bluetooth NetworkManager
    systemctl enable sddm
    echo "System backup: $backup"
    exit 0
fi
[[ $EUID != 0 ]] || { echo 'Run this installer as your regular desktop user.' >&2; exit 1; }
if [[ "$MODE" != --user-only ]]; then sudo "$ROOT/install.sh" --system-only; fi
backup="$HOME/.local/state/nocturne/backups/$STAMP"
mkdir -p "$backup"
copy_tree() {
    local source_root=$1 destination_root=$2
    while IFS= read -r -d '' source; do
        rel=${source#"$source_root/"}; dest="$destination_root/$rel"
        if [[ -e "$dest" || -L "$dest" ]]; then
            prior=${dest#"$HOME/"}; mkdir -p "$backup/$(dirname "$prior")"; cp -a "$dest" "$backup/$prior"
        else printf '%s\n' "$dest" >> "$backup/new-files.txt"; fi
        mkdir -p "$(dirname "$dest")"
        cp "$source" "$dest"
    done < <(find "$source_root" -type f -print0)
}
copy_tree "$ROOT/config" "$HOME/.config"
copy_tree "$ROOT/bin" "$HOME/.local/bin"
copy_tree "$ROOT/share" "$HOME/.local/share"
mkdir -p "$HOME/.local/share/nocturne"
# Wallpaper is managed separately and backed up on subsequent installations.
if [[ -e "$HOME/.local/share/nocturne/wallpaper.png" ]]; then
 mkdir -p "$backup/.local/share/nocturne"
 cp -a "$HOME/.local/share/nocturne/wallpaper.png" "$backup/.local/share/nocturne/"
else printf '%s\n' "$HOME/.local/share/nocturne/wallpaper.png" >> "$backup/new-files.txt"; fi
cp "$ROOT/assets/wallpaper.png" "$HOME/.local/share/nocturne/wallpaper.png"
python - "$HOME" <<'PY'
from pathlib import Path
import sys
home=Path(sys.argv[1])
for name in ['qt5ct','qt6ct']:
 p=home/'.config'/name/(name+'.conf')
 p.write_text(p.read_text().replace('@@HOME@@',str(home)))
PY
chmod +x "$HOME"/.local/bin/nocturne-*
if command -v gsettings >/dev/null; then
    gsettings list-recursively org.gnome.desktop.interface > "$backup/gsettings-interface.txt"
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme Breeze-Dark
    gsettings set org.gnome.desktop.interface icon-theme Nocturne
    gsettings set org.gnome.desktop.interface cursor-theme Nocturne-Cursors
    gsettings set org.gnome.desktop.interface cursor-size 28
    gsettings set org.gnome.desktop.interface font-name 'Inter 10'
fi
# Disable the competing D-Bus notification service, recording its prior state.
if systemctl --user cat dunst.service >/dev/null 2>&1; then
    systemctl --user is-enabled dunst.service > "$backup/dunst.enabled" 2>&1 || true
    if [[ -e "$HOME/.config/systemd/user/dunst.service" || -L "$HOME/.config/systemd/user/dunst.service" ]]; then
        mkdir -p "$backup/.config/systemd/user"
        cp -a "$HOME/.config/systemd/user/dunst.service" "$backup/.config/systemd/user/"
    else printf '%s\n' "$HOME/.config/systemd/user/dunst.service" >> "$backup/new-files.txt"; fi
    systemctl --user mask --now dunst.service
    systemctl --user daemon-reload
fi
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    hyprctl reload
    hyprctl dispatch "hl.dsp.exec_cmd('~/.local/bin/nocturne-session restart')"
fi
printf '\nNocturne installed. User backup: %s\nLog out when convenient to apply every environment setting.\n' "$backup"
```

## `tools/build-cursors.py`

```python
#!/usr/bin/env python3
"""Build original SVG cursor artwork into a complete multi-size Xcursor theme.
Requires Python 3, librsvg (rsvg-convert), and xorg-xcursorgen.
Run from any directory. No downloaded cursor artwork is used.
"""
from pathlib import Path
import math, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/cursors'
THEME=ROOT/'system/usr/share/icons/Nocturne-Cursors'
ASSETS.mkdir(parents=True,exist_ok=True)
(THEME/'cursors').mkdir(parents=True,exist_ok=True)
V='#b69af7'; D='#100b1b'; L='#eee3ff'
HEAD=f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g stroke="{D}" stroke-width="2" stroke-linejoin="round" stroke-linecap="round" fill="{V}">'
END='</g></svg>'
def svg(body):return HEAD+body+END
pointer='<path d="M5 3 L5 25 L11 20 L16 29 L20 27 L15 18 L24 17 Z"/><path d="M7 7 L7 19" fill="none" stroke="#eee3ff" stroke-width="1" opacity=".65"/>'
hand='<path d="M10 17 V6 Q10 2 13 2 Q16 2 16 6 V13 Q20 10 22 14 Q26 12 27 17 V22 Q27 29 21 30 H14 Q11 30 9 26 L4 19 Q2 15 5 14 Q7 13 10 17 Z"/><path d="M16 14 V19 M21 15 V19" fill="none" stroke="#7653a7" stroke-width="1"/>'
text='<path d="M11 4 H21 M16 4 V28 M11 28 H21" fill="none" stroke="#100b1b" stroke-width="5"/><path d="M11 4 H21 M16 4 V28 M11 28 H21" fill="none" stroke="#d5bdff" stroke-width="2"/>'
ns='<path d="M16 2 L9 10 H13 V22 H9 L16 30 L23 22 H19 V10 H23 Z"/>'
ew='<g transform="rotate(90 16 16)">'+ns+'</g>'
move='<path d="M16 2 L10 8 H14 V14 H8 V10 L2 16 L8 22 V18 H14 V24 H10 L16 30 L22 24 H18 V18 H24 V22 L30 16 L24 10 V14 H18 V8 H22 Z"/>'
cross='<path d="M16 3 V29 M3 16 H29" fill="none" stroke="#100b1b" stroke-width="5"/><path d="M16 3 V29 M3 16 H29" fill="none" stroke="#c8a9ff" stroke-width="2"/><circle cx="16" cy="16" r="3" fill="#eee3ff" stroke-width="1"/>'
grab='<path d="M7 16 V10 Q7 7 10 9 V6 Q12 2 15 6 Q19 2 21 7 Q25 5 26 10 V21 Q26 29 20 30 H13 Q10 30 8 26 L4 20 Q3 15 7 16 Z"/><path d="M11 9 V16 M16 8 V15 M21 10 V16" fill="none" stroke="#7653a7" stroke-width="1"/>'
fist='<path d="M6 14 Q6 9 10 11 Q12 7 16 10 Q19 7 22 11 Q27 10 27 15 V23 Q26 29 21 29 H12 Q8 28 6 23 L3 19 Q2 15 6 14 Z"/><path d="M10 13 V17 M16 12 V16 M22 13 V17" fill="none" stroke="#7653a7" stroke-width="1"/>'
no='<circle cx="16" cy="16" r="12" fill="#100b1b" stroke="#b69af7" stroke-width="3"/><path d="M8 8 L24 24" stroke="#b69af7" stroke-width="3"/>'
def badge(kind):
 base='<g transform="translate(0 0) scale(.82)">'+pointer+'</g><rect x="16" y="17" width="15" height="14" rx="4" fill="#241731"/>'
 marks={'copy':'M20 24 H27 M23.5 20.5 V27.5','alias':'M20 26 L27 20 M21 20 H27 V26','help':'M21 21 Q24 18 27 21 Q28 23 24 24 M24 27 V27.1','context-menu':'M20 21 H27 M20 24 H27 M20 27 H27'}
 return base+f'<path d="{marks[kind]}" fill="none" stroke="{L}" stroke-width="1.5"/>'
shapes={'left_ptr':(pointer,5,3),'hand2':(hand,13,3),'xterm':(text,16,16),'ns-resize':(ns,16,16),'ew-resize':(ew,16,16),'nwse-resize':('<g transform="rotate(-45 16 16)">'+ns+'</g>',16,16),'nesw-resize':('<g transform="rotate(45 16 16)">'+ns+'</g>',16,16),'fleur':(move,16,16),'crosshair':(cross,16,16),'openhand':(grab,16,16),'closedhand':(fist,16,16),'forbidden':(no,16,16),'copy':(badge('copy'),5,3),'alias':(badge('alias'),5,3),'help':(badge('help'),5,3),'context-menu':(badge('context-menu'),5,3),'vertical-text':('<g transform="rotate(90 16 16)">'+text+'</g>',16,16),'cell':('<rect x="7" y="7" width="18" height="18" rx="2" fill="none" stroke="#100b1b" stroke-width="5"/><rect x="7" y="7" width="18" height="18" rx="2" fill="none" stroke="#c8a9ff" stroke-width="2"/>',16,16)}
for name,symbol in [('zoom-in','M17 7 V17 M12 12 H22'),('zoom-out','M12 12 H22')]:
 shapes[name]=('<path d="M22 22 L29 29" stroke-width="6"/><path d="M22 22 L29 29" stroke="#b69af7" stroke-width="3"/><circle cx="15" cy="12" r="10" fill="#1c1328"/><path d="'+symbol+'" fill="none" stroke="#d5bdff" stroke-width="2"/>',15,12)
def orbit(frame,cx=16,cy=16,r=10):
 result=f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="#38264f" stroke-width="3"/>'
 for j in range(8):
  angle=(frame*30-j*17)*math.pi/180
  x=cx+r*math.cos(angle);y=cy+r*math.sin(angle)
  result+=f'<circle cx="{x:.3f}" cy="{y:.3f}" r="{1.1+j*.02 if j else 2.8}" fill="{L if j==0 else V}" stroke="none" opacity="{1-j*.105:.3f}"/>'
 return result
frames={name:([svg(body)],x,y) for name,(body,x,y) in shapes.items()}
frames['watch']=([svg(orbit(i)) for i in range(12)],16,16)
frames['left_ptr_watch']=([svg('<g transform="scale(.75)">'+pointer+'</g>'+orbit(i,23,23,6)) for i in range(12)],4,2)
aliases={
 'left_ptr':'default arrow top_left_arrow center_ptr draft right_ptr',
 'hand2':'pointer pointing_hand hand hand1 link 9d800788f1b08800ae810202380a0822 e29285e634086352946a0e7090d73106',
 'xterm':'text ibeam', 'ns-resize':'n-resize s-resize top_side bottom_side v_double_arrow sb_v_double_arrow row-resize size_ver split_v double_arrow 00008160000006810000408080010102',
 'ew-resize':'e-resize w-resize left_side right_side h_double_arrow sb_h_double_arrow col-resize size_hor split_h 028006030e0e7ebffc7f7070c0600140',
 'nwse-resize':'nw-resize se-resize top_left_corner bottom_right_corner size_fdiag bd_double_arrow c7088f0f3e6c8088236ef8e1e3e70000',
 'nesw-resize':'ne-resize sw-resize top_right_corner bottom_left_corner size_bdiag fd_double_arrow fcf1c3c7cd4491d801f1e1c78f100000',
 'fleur':'move all-scroll size_all dnd-move 4498f0e0c1937ffe01fd06f973665830 9081237383d90e509aa00f00170e968f',
 'crosshair':'cross tcross diamond_cross plus color-picker', 'openhand':'grab 5c6cd98b3f3ebcb1f9c7f1c204630408',
 'closedhand':'grabbing dnd-none 208530c400c041818281048008011002',
 'forbidden':'not-allowed no-drop dnd-no-drop crossed_circle circle X_cursor 03b6e0fcb3499374a867c041f52298f0',
 'copy':'dnd-copy 1081e37283d90000800003c07f3ef6bf 6407b0e94181790501fd1e167b474872',
 'alias':'dnd-link 3085a0e285430894940527032f8b26df 640fb0e74195791501fd1ed57b41487f',
 'help':'question_arrow left_ptr_help whats_this d9ce0ab605698f320427677b458ad60b',
 'watch':'wait', 'left_ptr_watch':'progress half-busy 08e8e1c95fe2fc01f976f1e063a24ccd',
}
with tempfile.TemporaryDirectory(prefix='nocturne-cursors-') as tmp:
 tmp=Path(tmp)
 for name,(images,hx,hy) in frames.items():
  lines=[]
  for i,source in enumerate(images):
   src=ASSETS/f'{name}-{i:02}.svg';src.write_text(source)
   for size in [24,28,32,48,64]:
    png=tmp/f'{name}-{i}-{size}.png'
    subprocess.run(['rsvg-convert','-w',str(size),'-h',str(size),str(src),'-o',str(png)],check=True)
    lines.append(f'{size} {round(hx*size/32)} {round(hy*size/32)} {png} {75 if len(images)>1 else 0}')
  cfg=tmp/(name+'.conf');cfg.write_text('\n'.join(lines)+'\n')
  subprocess.run(['xcursorgen',str(cfg),str(THEME/'cursors'/name)],check=True)
 for canonical,names in aliases.items():
  for alias in names.split():shutil.copyfile(THEME/'cursors'/canonical,THEME/'cursors'/alias)
(THEME/'index.theme').write_text('[Icon Theme]\nName=Nocturne Cursors\nComment=Original violet cursors with orbital busy animation\nInherits=breeze_cursors\n')
# SVG contact sheet, keeping the artwork editable and inspectable.
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="570" viewBox="0 0 960 570"><rect width="960" height="570" rx="24" fill="#100d18"/><text x="40" y="50" fill="#e4dced" font-family="Inter" font-size="24">NOCTURNE / CURSORS</text><text x="40" y="79" fill="#8f809f" font-family="Inter" font-size="13">Violet silhouettes · midnight outlines · orbital motion</text>']
for n,(name,(images,_,_)) in enumerate(frames.items()):
 x=40+(n%6)*150;y=110+(n//6)*110
 inner=images[0].split('>',1)[1].rsplit('</svg>',1)[0]
 parts.append(f'<rect x="{x}" y="{y}" width="132" height="82" rx="12" fill="#1a1324"/><g transform="translate({x+42} {y+7}) scale(1.5)">{inner}</g><text x="{x+66}" y="{y+99}" fill="#a99abb" font-family="Inter" font-size="11" text-anchor="middle">{name}</text>')
parts.append('</svg>')
p=ROOT/'previews/cursors.svg';p.write_text(''.join(parts))
subprocess.run(['rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
print(f'Built {len(frames)} original shapes / {len(list((THEME/"cursors").iterdir()))} cursor names, five sizes each.')
```

## `bin/nocturne-bluetooth`

```bash
#!/usr/bin/env bash
# Always expose the control, including VMs with no passed-through adapter.
if [[ ${1:-} = open ]]; then
 if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then exec blueman-manager; else notify-send 'Bluetooth unavailable' 'No Bluetooth adapter is attached to this computer. Pass a USB adapter through to the VM to pair devices.'; fi
else
 if compgen -G '/sys/class/bluetooth/hci*' >/dev/null; then
  printf '{"text":"󰂯","tooltip":"Bluetooth · click to manage devices","class":"available"}\n'
 else
  printf '{"text":"󰂲","tooltip":"Bluetooth · no adapter attached","class":"unavailable"}\n'
 fi
fi
```

## `bin/nocturne-network`

```bash
#!/usr/bin/env bash
if nmcli -t -f TYPE device | grep -qx wifi; then
 exec kitty --class nocturne-network -e nmtui
else
 notify-send 'Network settings' 'Ethernet is available. No Wi-Fi adapter is attached to this VM.'
 exec nm-connection-editor
fi
```

## `bin/nocturne-power`

```bash
#!/usr/bin/env bash
set -euo pipefail
choice=$(printf '󰌾  Lock\n󰤄  Suspend\n󰍃  Log out\n󰜉  Restart\n󰐥  Shut down\n' | rofi -dmenu -i -p 'SESSION' -theme-str 'listview { lines: 5; } mainbox { children: [ inputbar, listview ]; }') || exit 0
case "$choice" in
 *Lock) loginctl lock-session; exit;;
 *Suspend) systemctl suspend; exit;;
 *'Log out') action=logout;;
 *Restart) action=reboot;;
 *'Shut down') action=poweroff;;
 *) exit;;
esac
answer=$(printf 'Cancel\nConfirm\n' | rofi -dmenu -i -p "$choice" -theme-str 'listview { lines: 2; } mainbox { children: [ inputbar, listview ]; }') || exit 0
[[ "$answer" = Confirm ]] || exit 0
case "$action" in
 logout) hyprctl dispatch 'hl.dsp.exit()';;
 reboot) systemctl reboot;;
 poweroff) systemctl poweroff;;
esac
```

## `bin/nocturne-session`

```bash
#!/usr/bin/env bash
set -u
export QT_QPA_PLATFORMTHEME=qt6ct GTK_THEME=Breeze-Dark XCURSOR_THEME=Nocturne-Cursors XCURSOR_SIZE=28
mkdir -p "$HOME/.local/state/nocturne"
exec 9>"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/nocturne-session.lock"
flock -n 9 || exit 0
if [[ ${1:-} = restart ]]; then
    pkill -x waybar || true
    pkill -x swaybg || true
    for attempt in {1..20}; do
        if ! pgrep -u "$UID" -x waybar >/dev/null && ! pgrep -u "$UID" -x swaybg >/dev/null; then break; fi
        sleep 0.1
    done
    makoctl reload 2>/dev/null || true
fi
start() {
 local process=$1; shift
 if ! pgrep -u "$UID" -x "$process" >/dev/null; then
  nohup "$@" >"$HOME/.local/state/nocturne/$process.log" 2>&1 9>&- &
 fi
}
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME GTK_THEME XCURSOR_THEME XCURSOR_SIZE
hyprctl setcursor Nocturne-Cursors 28 >/dev/null
start swaybg swaybg -i "$HOME/.local/share/nocturne/wallpaper.png" -m fill
start waybar waybar
start mako mako
start hypridle hypridle
if ! pgrep -u "$UID" -f "^/usr/lib/polkit-kde-authentication-agent-1" >/dev/null; then
 nohup /usr/lib/polkit-kde-authentication-agent-1 >"$HOME/.local/state/nocturne/polkit.log" 2>&1 9>&- &
fi
exec 9>&-
```

## `bin/nocturne-shot`

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Pictures/Screenshots"
region=$(slurp -b 100d18aa -c b69af7) || exit 0
file="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
grim -g "$region" "$file"
notify-send 'Screenshot saved' "$file"
```

## `config/dolphinrc`

```text
[General]
ShowFullPath=true
RememberOpenedTabs=false

[MainWindow]
MenuBar=Disabled

[DetailsMode]
PreviewSize=48

[IconsMode]
IconSize=64
PreviewSize=80

[KFileDialog Settings]
Places Icons Auto-resize=false
Places Icons Static Size=22

[UiSettings]
ColorScheme=Nocturne
```

## `config/environment.d/60-nocturne.conf`

```text
QT_QPA_PLATFORMTHEME=qt6ct
GTK_THEME=Breeze-Dark
XCURSOR_THEME=Nocturne-Cursors
XCURSOR_SIZE=28
```

## `config/fish/config.fish`

```fish
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
```

## `config/fish/functions/fish_greeting.fish`

```fish
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
```

## `config/gtk-3.0/gtk.css`

```css
@define-color theme_selected_bg_color #916dcf;
@define-color theme_selected_fg_color #ffffff;
@define-color theme_bg_color #100d18;
@define-color theme_fg_color #e4dced;
@define-color theme_base_color #0d0a12;
@define-color theme_text_color #e4dced;
@define-color accent_color #b69af7;
@define-color accent_bg_color #916dcf;
@define-color accent_fg_color #ffffff;
window, dialog { background-color: #100d18; color: #e4dced; }
headerbar { background: #16111f; color: #e4dced; }
selection { background-color: #916dcf; color: #ffffff; }
```

## `config/gtk-3.0/settings.ini`

```text
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Nocturne
gtk-font-name=Inter 10
gtk-cursor-theme-name=Nocturne-Cursors
gtk-cursor-theme-size=28
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=icon:minimize,maximize,close
```

## `config/gtk-4.0/gtk.css`

```css
@define-color theme_selected_bg_color #916dcf;
@define-color theme_selected_fg_color #ffffff;
@define-color theme_bg_color #100d18;
@define-color theme_fg_color #e4dced;
@define-color theme_base_color #0d0a12;
@define-color theme_text_color #e4dced;
@define-color accent_color #b69af7;
@define-color accent_bg_color #916dcf;
@define-color accent_fg_color #ffffff;
window, dialog { background-color: #100d18; color: #e4dced; }
headerbar { background: #16111f; color: #e4dced; }
selection { background-color: #916dcf; color: #ffffff; }
```

## `config/gtk-4.0/settings.ini`

```text
[Settings]
gtk-theme-name=Breeze-Dark
gtk-icon-theme-name=Nocturne
gtk-font-name=Inter 10
gtk-cursor-theme-name=Nocturne-Cursors
gtk-cursor-theme-size=28
gtk-application-prefer-dark-theme=true
gtk-decoration-layout=icon:minimize,maximize,close
```

## `config/hypr/hypridle.conf`

```text
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms("on")'
}
listener {
    timeout = 600
    on-timeout = loginctl lock-session
}
```

## `config/hypr/hyprland.lua`

```lua
-- NOCTURNE / Hyprland 0.56 Lua configuration
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.env("XCURSOR_THEME", "Nocturne-Cursors")
hl.env("XCURSOR_SIZE", "28")
hl.env("HYPRCURSOR_SIZE", "28")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("GTK_THEME", "Breeze-Dark")
hl.config({
 cursor = { no_hardware_cursors = 1, enable_hyprcursor = false },
 general = { gaps_in = 6, gaps_out = 14, border_size = 2, resize_on_border = true, layout = "dwindle",
  col = { active_border = {colors = {"rgba(a78bfaee)", "rgba(6d28d9bb)"}, angle = 45}, inactive_border = "rgba(282333ff)" } },
 decoration = { rounding = 16, rounding_power = 2, active_opacity = 1, inactive_opacity = 0.97,
  shadow = {enabled = true, range = 24, render_power = 3, color = "rgba(00000066)"},
  blur = {enabled = true, size = 5, passes = 2, vibrancy = 0.15} },
 animations = {enabled = true},
 dwindle = {preserve_split = true},
 input = {kb_layout = "fr", follow_mouse = 1, sensitivity = 0, touchpad = {natural_scroll = true}},
 misc = {disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0},
})
hl.curve("nocturne", {type = "bezier", points = {{0.16, 1}, {0.3, 1}}})
hl.curve("soft", {type = "bezier", points = {{0.4, 0}, {0.2, 1}}})
for _, a in ipairs({
 {"windows", 4.5, "nocturne", "slide"}, {"windowsIn", 4, "nocturne", "popin 94%"},
 {"windowsOut", 3, "soft", "popin 96%"}, {"border", 5, "nocturne", nil},
 {"fade", 3, "soft", nil}, {"workspaces", 4.5, "nocturne", "slide"},
 {"layers", 3.5, "nocturne", "fade"}
}) do hl.animation({leaf=a[1], enabled=true, speed=a[2], bezier=a[3], style=a[4]}) end
local function exec(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd)) end
exec("SUPER + Return", "kitty")
exec("SUPER + Q", "kitty")
exec("SUPER + E", "dolphin")
exec("SUPER + R", "rofi -show drun")
exec("SUPER + space", "rofi -show drun")
exec("SUPER + M", "~/.local/bin/nocturne-power")
exec("SUPER + L", "loginctl lock-session")
exec("SUPER + N", "makoctl dismiss -a")
exec("SUPER + SHIFT + R", "~/.local/bin/nocturne-session restart")
exec("Print", "~/.local/bin/nocturne-shot")
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + V", hl.dsp.window.float({action="toggle"}))
hl.bind("SUPER + F", hl.dsp.window.fullscreen())
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
for _, d in ipairs({"left", "right", "up", "down"}) do hl.bind("SUPER + "..d, hl.dsp.focus({direction=d})) end
-- Physical keycodes keep workspace shortcuts usable on AZERTY.
for i=1,10 do
 hl.bind("SUPER + code:"..(i+9), hl.dsp.focus({workspace=i}))
 hl.bind("SUPER + SHIFT + code:"..(i+9), hl.dsp.window.move({workspace=i}))
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse=true})
hl.bind("SUPER + mouse_down", hl.dsp.focus({workspace="e+1"}))
hl.bind("SUPER + mouse_up", hl.dsp.focus({workspace="e-1"}))
for key,cmd in pairs({
 XF86AudioRaiseVolume="wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
 XF86AudioLowerVolume="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
 XF86AudioMute="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
 XF86AudioMicMute="wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
 XF86MonBrightnessUp="brightnessctl set +5%", XF86MonBrightnessDown="brightnessctl set 5%-",
 XF86AudioPlay="playerctl play-pause", XF86AudioNext="playerctl next", XF86AudioPrev="playerctl previous"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true, repeating=true}) end
hl.window_rule({name="settings", match={class="^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|qt6ct)$"}, float=true, size="820 540", center=true})
hl.window_rule({name="suppress-maximize", match={class=".*"}, suppress_event="maximize"})
hl.on("hyprland.start", function() hl.exec_cmd("~/.local/bin/nocturne-session") end)
```

## `config/hypr/hyprlock.conf`

```text
general {
    hide_cursor = true
    immediate_render = true
    screencopy_mode = 1
}
background {
    monitor =
    path = ~/.local/share/nocturne/wallpaper.png
    blur_passes = 2
    blur_size = 5
    brightness = 0.65
}
label {
    monitor =
    text = $TIME
    color = rgba(e9e1f5ff)
    font_size = 84
    font_family = Inter
    position = 0, 100
    halign = center
    valign = center
}
label {
    monitor =
    text = N O C T U R N E   /   $USER
    color = rgba(b69af7ff)
    font_size = 12
    font_family = Inter
    position = 0, 20
    halign = center
    valign = center
}
input-field {
    monitor =
    size = 310, 56
    outline_thickness = 2
    fade_on_empty = false
    dots_size = 0.2
    dots_spacing = 0.3
    outer_color = rgba(8e6ac8ff)
    inner_color = rgba(15101fee)
    font_color = rgba(e9e1f5ff)
    check_color = rgba(a5ccb3ff)
    fail_color = rgba(ef8fa4ff)
    placeholder_text = Enter password
    fail_text = Try again ($ATTEMPTS)
    rounding = 14
    position = 0, -65
    halign = center
    valign = center
}
```

## `config/kdeglobals`

```text
[General]
Name=Nocturne
ColorScheme=Nocturne
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0

[Colors:View]
BackgroundNormal=13,10,18
BackgroundAlternate=20,15,28
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Window]
BackgroundNormal=16,13,24
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Button]
BackgroundNormal=31,24,43
BackgroundAlternate=39,30,52
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Selection]
BackgroundNormal=145,109,207
BackgroundAlternate=118,85,174
ForegroundNormal=255,250,255
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Tooltip]
BackgroundNormal=22,17,31
BackgroundAlternate=28,21,39
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Complementary]
BackgroundNormal=13,10,18
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Header]
BackgroundNormal=20,15,28
BackgroundAlternate=26,19,36
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Icons]
Theme=Nocturne

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
widgetStyle=Breeze
SingleClick=false

[ColorEffects:Disabled]
Color=56,48,66
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[WM]
activeBackground=20,15,28
activeForeground=228,220,237
inactiveBackground=13,10,18
inactiveForeground=139,124,156

[UiSettings]
ColorScheme=Nocturne
```

## `config/kitty/kitty.conf`

```text
# NOCTURNE
shell /usr/bin/fish
font_family JetBrainsMono Nerd Font
bold_font auto
italic_font auto
font_size 11.0
window_padding_width 24
background #0d0a12
foreground #e4dced
background_opacity 0.8
dynamic_background_opacity yes
selection_background #563b7e
selection_foreground #ffffff
cursor #bb9af7
cursor_text_color #100b1b
cursor_shape beam
cursor_trail 3
cursor_trail_decay 0.12 0.35
cursor_blink_interval 0.6
url_color #c4a5ff
color0 #231d2e
color1 #ef8fa4
color2 #a5ccb3
color3 #e5c89a
color4 #a1a5e9
color5 #b69af7
color6 #9ccbd2
color7 #ded5e8
color8 #71637f
color9 #f7a3b6
color10 #b9e0c6
color11 #f4dab0
color12 #b8bdf5
color13 #ceb4ff
color14 #b4e0e5
color15 #faf5ff
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
active_tab_background #a78bfa
active_tab_foreground #110d19
inactive_tab_background #21192e
inactive_tab_foreground #9687aa
hide_window_decorations yes
enable_audio_bell no
confirm_os_window_close 0
remember_window_size yes
initial_window_width 100c
initial_window_height 28c
map ctrl+shift+enter new_window_with_cwd
map ctrl+shift+t new_tab_with_cwd
```

## `config/mako/config`

```text
font=Inter 11
background-color=#15101ff5
text-color=#e9e1f5
border-color=#8e6ac8
border-size=1
border-radius=14
padding=18
margin=14
width=340
height=160
default-timeout=6000
anchor=top-right
outer-margin=68,14,14
max-visible=4
icons=1
[urgency=critical]
border-color=#ef8fa4
default-timeout=0
```

## `config/qt5ct/qt5ct.conf`

```text
[Appearance]
color_scheme_path=@@HOME@@/.config/qt6ct/colors/Nocturne.conf
custom_palette=true
icon_theme=Nocturne
standard_dialogs=default
style=Breeze

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
general="Inter,10,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=0
buttonbox_layout=0
dialog_buttons_have_icons=1
menus_have_icons=true
toolbutton_style=4
```

## `config/qt6ct/colors/Nocturne.conf`

```text
[ColorScheme]
active_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
disabled_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
inactive_colors=#e4dced, #1f182b, #42344f, #33263f, #09070e, #59446a, #e4dced, #ffffff, #e4dced, #0d0a12, #100d18, #000000, #916dcf, #ffffff, #b69af7, #9c87c6, #140f1c, #000000, #16111f, #e4dced, #8b7c9c, #b69af7
```

## `config/qt6ct/qt6ct.conf`

```text
[Appearance]
color_scheme_path=@@HOME@@/.config/qt6ct/colors/Nocturne.conf
custom_palette=true
icon_theme=Nocturne
standard_dialogs=default
style=Breeze

[Fonts]
fixed="JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0"
general="Inter,10,-1,5,50,0,0,0,0,0"

[Interface]
activate_item_on_single_click=0
buttonbox_layout=0
dialog_buttons_have_icons=1
menus_have_icons=true
toolbutton_style=4
```

## `config/rofi/config.rasi`

```text
configuration {
 modi: "drun,run,window";
 show-icons: true;
 display-drun: "APPS";
 display-run: "RUN";
 display-window: "WINDOWS";
 drun-display-format: "{name}";
 font: "Inter 12";
 icon-theme: "Nocturne";
 terminal: "kitty";
}
@theme "nocturne"
```

## `config/rofi/nocturne.rasi`

```text
* { bg: #100d18; fg: #e9e1f5; muted: #8f809f; violet: #b69af7; selection: #292039;
 background-color: transparent; text-color: @fg; border-color: #443253; }
window { width: 640px; padding: 26px; border: 1px; border-radius: 22px; background-color: @bg; }
mainbox { spacing: 22px; children: [ inputbar, listview, mode-switcher ]; }
inputbar { padding: 16px; border-radius: 12px; background-color: #1c1528; spacing: 14px; children: [ prompt, entry ]; }
prompt { text-color: @violet; font: "Inter Bold 11"; vertical-align: 0.5; }
entry { placeholder: "Search your applications…"; placeholder-color: @muted; }
listview { lines: 6; columns: 1; spacing: 5px; fixed-height: true; }
element { padding: 12px; border-radius: 10px; spacing: 14px; }
element selected.normal { background-color: @selection; text-color: @violet; }
element-icon { size: 28px; }
element-text { vertical-align: 0.5; text-color: inherit; }
mode-switcher { spacing: 10px; }
button { padding: 8px; border-radius: 8px; text-color: @muted; font: "Inter 10"; }
button selected { text-color: @violet; background-color: #20172e; }
message { padding: 10px; }
```

## `config/starship.toml`

```toml
add_newline = true
format = "[󰣇 ](bold #b69af7)$directory$git_branch$git_status$cmd_duration$character"
right_format = "$time"
[directory]
style = "bold #b69af7"
truncation_length = 3
truncation_symbol = "…/"
[character]
success_symbol = "[❯](bold #b69af7)"
error_symbol = "[❯](bold #ef8fa4)"
[git_branch]
symbol = " "
style = "#9ccbd2"
[git_status]
style = "#e5c89a"
[cmd_duration]
min_time = 2000
format = "[ · $duration](#8f809f)"
[time]
disabled = false
time_format = "%H:%M"
format = "[󰥔 $time](#71637f)"
```

## `config/waybar/config.jsonc`

```json
{
  "layer": "top",
  "position": "top",
  "height": 40,
  "margin-top": 10,
  "margin-left": 14,
  "margin-right": 14,
  "spacing": 8,
  "modules-left": [
    "custom/launcher",
    "clock"
  ],
  "modules-center": [
    "hyprland/workspaces",
    "hyprland/window"
  ],
  "modules-right": [
    "cpu",
    "memory",
    "tray",
    "network",
    "custom/bluetooth",
    "pulseaudio",
    "custom/power"
  ],
  "custom/launcher": {
    "format": "󰣇",
    "tooltip-format": "Nocturne · Applications",
    "on-click": "rofi -show drun"
  },
  "hyprland/workspaces": {
    "format": "{name}",
    "on-click": "activate",
    "all-outputs": false,
    "sort-by": "number"
  },
  "clock": {
    "format": "{:%H:%M}",
    "format-alt": "{:%a, %d %b}",
    "tooltip-format": "<big>{:%A %d %B %Y}</big>\n<tt><small>{calendar}</small></tt>"
  },
  "cpu": {
    "format": "󰻠 {usage:2}%",
    "interval": 3,
    "on-click": "kitty --class nocturne-monitor htop",
    "tooltip": true
  },
  "memory": {
    "format": "󰍛 {percentage}%",
    "interval": 3,
    "tooltip-format": "{used:.1f} / {total:.1f} GiB",
    "on-click": "kitty --class nocturne-monitor htop"
  },
  "tray": {
    "icon-size": 16,
    "spacing": 8
  },
  "network": {
    "format-wifi": "󰤨",
    "format-ethernet": "󰈀",
    "format-disconnected": "󰤭",
    "tooltip-format-wifi": "{essid} · {signalStrength}%\n{ipaddr}",
    "tooltip-format-ethernet": "Wired · {ipaddr}",
    "tooltip-format-disconnected": "Network disconnected",
    "on-click": "~/.local/bin/nocturne-network",
    "on-click-right": "nm-connection-editor"
  },
  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟",
    "format-icons": {
      "default": [
        "󰕿",
        "󰖀",
        "󰕾"
      ]
    },
    "on-click": "pavucontrol",
    "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    "scroll-step": 5,
    "tooltip-format": "{desc}"
  },
  "custom/power": {
    "format": "󰐥",
    "on-click": "~/.local/bin/nocturne-power",
    "tooltip-format": "Session & power"
  },
  "custom/bluetooth": {
    "exec": "~/.local/bin/nocturne-bluetooth",
    "return-type": "json",
    "interval": 10,
    "on-click": "~/.local/bin/nocturne-bluetooth open"
  },
  "hyprland/window": {
    "format": "{title}",
    "max-length": 22,
    "separate-outputs": true,
    "tooltip": true
  }
}
```

## `config/waybar/style.css`

```css
/* NOCTURNE — individual floating capsules */
* { font-family: "JetBrainsMono Nerd Font", "Inter"; font-size: 12px; min-height: 0; border: none; }
window#waybar { background: transparent; color: #ded8ed; }
.modules-left, .modules-center, .modules-right { background: transparent; }
#custom-launcher, #clock, #window, #cpu, #memory, #tray,
#network, #custom-bluetooth, #pulseaudio, #custom-power {
    background: rgba(16, 13, 24, 0.96);
    border: 1px solid #352842;
    border-radius: 999px;
    padding: 0 13px;
    margin: 1px 0;
}
#custom-launcher { color: #c4a5ff; font-size: 22px; padding: 0 14px; }
#clock { font-family: "Inter"; font-weight: 700; font-size: 14px; color: #eee8ff; padding: 0 18px; }
#workspaces { background: transparent; padding: 0; margin: 0; }
#workspaces button {
    background: rgba(16, 13, 24, 0.96);
    border: 1px solid #352842;
    border-radius: 999px;
    margin: 1px 4px;
    padding: 0 12px;
    min-width: 12px;
    color: #aa97bf;
    transition: background-color 160ms ease, color 160ms ease;
}
#workspaces button.active { background: #b69af7; color: #100b1b; border-color: #c6aaff; font-weight: bold; }
#workspaces button:hover { background: #38264f; color: #eee8ff; box-shadow: none; }
#workspaces button.urgent { background: #ef8fa4; color: #100b1b; }
/* Empty desktops have zero visible/clickable width, even when focused. */
#workspaces button.empty, #workspaces button.empty * {
    min-width: 0; min-height: 0; padding: 0; margin: 0;
    border-width: 0; font-size: 0; opacity: 0; background: transparent;
}
#window { font-family: "Inter"; font-size: 12px; color: #c8b8dc; padding: 0 16px; }
window#waybar.empty #window { background: transparent; border: none; padding: 0; margin: 0; }
#cpu, #memory { color: #aaa0bb; font-size: 11px; padding: 0 12px; }
#tray { padding: 0 12px; }
#network, #custom-bluetooth, #pulseaudio { color: #c8bbde; }
#custom-bluetooth.unavailable, #network.disconnected, #pulseaudio.muted { color: #6c627b; }
#custom-power { color: #c4a5ff; font-size: 17px; padding: 0 14px; }
tooltip { background: #16111f; border: 1px solid #503a6d; border-radius: 16px; }
tooltip label { color: #e8e1f3; padding: 8px; }
```

## `config/xdg-desktop-portal/portals.conf`

```text
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.FileChooser=gtk
```

## `system/etc/sddm.conf.d/90-nocturne.conf`

```text
[Theme]
Current=nocturne
CursorTheme=Nocturne-Cursors
CursorSize=28
Font=Inter,10,-1,5,50,0,0,0,0,0

[General]
GreeterEnvironment=QT_SCREEN_SCALE_FACTORS=1,QT_QUICK_CONTROLS_STYLE=Basic,QT_QUICK_BACKEND=software
```

## `system/usr/share/icons/Nocturne-Cursors/index.theme`

```text
[Icon Theme]
Name=Nocturne Cursors
Comment=Original violet cursors with orbital busy animation
Inherits=breeze_cursors
```

## `system/usr/share/sddm/themes/nocturne/Main.qml`

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
 id: root
 width: 1280; height: 800; color: "#08070d"
 property string clockText: Qt.formatTime(new Date(), "HH:mm")
 property bool busy: false
 function login() { if (!busy && username.text.length) { busy = true; status.text = "Signing in…"; sddm.login(username.text, password.text, session.currentIndex); } }
 Image { anchors.fill: parent; source: "wallpaper.png"; fillMode: Image.PreserveAspectCrop }
 Rectangle { anchors.fill: parent; color: "#2008070d" }
 Timer { interval: 1000; repeat: true; running: true; onTriggered: root.clockText = Qt.formatTime(new Date(), "HH:mm") }
 Text { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 46; text: root.clockText; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 36 }
 Rectangle {
  id: card
  width: 380; height: 500; x: Math.max(36, parent.width * 0.09); anchors.verticalCenter: parent.verticalCenter
  radius: 24; color: "#ed100d18"; border.color: "#443253"; border.width: 1
  opacity: 0
  Component.onCompleted: entrance.start()
  NumberAnimation { id: entrance; target: card; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
  Rectangle { width: 42; height: 3; radius: 2; x: 32; y: 32; color: "#b69af7"
   SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation {to: 0.4; duration: 2200} NumberAnimation {to: 1; duration: 2200} }
  }
  ColumnLayout {
   anchors.fill: parent; anchors.margins: 32; anchors.topMargin: 55; spacing: 14
   Text { text: "N O C T U R N E"; color: "#b69af7"; font.family: "Inter"; font.pixelSize: 11; font.bold: true }
   Text { text: "Welcome back."; color: "#eee6fa"; font.family: "Inter"; font.pixelSize: 28; Layout.topMargin: 6 }
   Text { text: "Your space, after dark."; color: "#8f809f"; font.family: "Inter"; font.pixelSize: 12; Layout.bottomMargin: 10 }
   TextField {
    id: username; Layout.fillWidth: true; implicitHeight: 46; text: userModel.lastUser; placeholderText: "Username"
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: username.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: password.forceActiveFocus()
   }
   TextField {
    id: password; Layout.fillWidth: true; implicitHeight: 46; placeholderText: "Password"; echoMode: TextInput.Password
    color: "#e9e1f5"; placeholderTextColor: "#8f809f"; font.family: "Inter"; font.pixelSize: 14; leftPadding: 14
    background: Rectangle {color: "#1c1528"; radius: 10; border.color: password.activeFocus ? "#b69af7" : "#33263f"}
    onAccepted: root.login()
   }
   ComboBox {
    id: session; Layout.fillWidth: true; implicitHeight: 38; model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
    palette.button: "#1c1528"; palette.buttonText: "#b9abc9"; palette.text: "#e9e1f5"; palette.base: "#1c1528"; palette.highlight: "#694797"; palette.highlightedText: "#ffffff"; font.family: "Inter"; font.pixelSize: 11
    background: Rectangle {color: "#1c1528"; radius: 8; border.color: "#33263f"}
   }
   Button {
    Layout.fillWidth: true; implicitHeight: 46; text: root.busy ? "Signing in…" : "Sign in  →"; enabled: !root.busy
    contentItem: Text {text: parent.text; color: "#100b1b"; font.family: "Inter"; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter}
    background: Rectangle {color: parent.hovered ? "#cbb0ff" : "#b69af7"; radius: 10; Behavior on color { ColorAnimation {duration: 160} }}
    onClicked: root.login()
   }
   Text { id: status; text: ""; color: "#ef8fa4"; font.family: "Inter"; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.Wrap; Layout.minimumHeight: 16 }
   RowLayout {
    Layout.alignment: Qt.AlignHCenter; spacing: 22
    Button { text: "Restart"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "restart"; powerDialog.open()} }
    Button { text: "Shut down"; flat: true; palette.buttonText: "#9986ad"; font.family: "Inter"; onClicked: {powerDialog.action = "shutdown"; powerDialog.open()} }
   }
  }
 }
 Dialog {
  id: powerDialog; property string action: ""; anchors.centerIn: parent; title: action === "restart" ? "Restart computer?" : "Shut down computer?"; modal: true
  standardButtons: Dialog.Ok | Dialog.Cancel
  palette.window: "#16111f"; palette.windowText: "#e9e1f5"; palette.button: "#292039"; palette.buttonText: "#b69af7"
  onAccepted: { if (action === "restart") sddm.reboot(); else sddm.powerOff(); }
 }
 Connections {
  target: sddm
  function onLoginFailed() { root.busy = false; password.text = ""; status.text = "Sign-in failed. Please try again."; password.forceActiveFocus(); }
  function onLoginSucceeded() { status.text = "Welcome."; }
 }
 Component.onCompleted: { if (username.text.length) password.forceActiveFocus(); else username.forceActiveFocus(); }
}
```

## `system/usr/share/sddm/themes/nocturne/metadata.desktop`

```text
[SddmGreeterTheme]
Name=Nocturne
Description=An original black and violet orbital greeter
Author=lia
License=MIT
Type=sddm-theme
Version=1.0
MainScript=Main.qml
ConfigFile=theme.conf
Theme-Id=nocturne
Theme-API=2.0
QtVersion=6
```

## `system/usr/share/sddm/themes/nocturne/theme.conf`

```text
[General]
background=wallpaper.png
```

## `share/color-schemes/Nocturne.colors`

```text
[General]
Name=Nocturne
ColorScheme=Nocturne
font=Inter,10,-1,5,50,0,0,0,0,0
fixed=JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0

[Colors:View]
BackgroundNormal=13,10,18
BackgroundAlternate=20,15,28
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Window]
BackgroundNormal=16,13,24
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Button]
BackgroundNormal=31,24,43
BackgroundAlternate=39,30,52
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Selection]
BackgroundNormal=145,109,207
BackgroundAlternate=118,85,174
ForegroundNormal=255,250,255
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Tooltip]
BackgroundNormal=22,17,31
BackgroundAlternate=28,21,39
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Complementary]
BackgroundNormal=13,10,18
BackgroundAlternate=22,17,31
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Colors:Header]
BackgroundNormal=20,15,28
BackgroundAlternate=26,19,36
ForegroundNormal=228,220,237
ForegroundInactive=139,124,156
ForegroundActive=196,165,255
ForegroundLink=182,154,247
ForegroundVisited=156,135,198
ForegroundNegative=239,143,164
ForegroundNeutral=229,200,154
ForegroundPositive=165,204,179
DecorationFocus=182,154,247
DecorationHover=118,85,174

[Icons]
Theme=Papirus-Dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
widgetStyle=Breeze
SingleClick=false

[ColorEffects:Disabled]
Color=56,48,66
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[WM]
activeBackground=20,15,28
activeForeground=228,220,237
inactiveBackground=13,10,18
inactiveForeground=139,124,156

[UiSettings]
ColorScheme=Nocturne
```

## `share/icons/Nocturne/index.theme`

```text
[Icon Theme]
Name=Nocturne
Comment=Papirus violet folders
Inherits=Papirus-Dark,breeze-dark,hicolor
Directories=16x16/places,22x22/places,24x24/places,32x32/places,48x48/places,64x64/places

[16x16/places]
Size=16
Context=Places
Type=Fixed

[22x22/places]
Size=22
Context=Places
Type=Fixed

[24x24/places]
Size=24
Context=Places
Type=Fixed

[32x32/places]
Size=32
Context=Places
Type=Fixed

[48x48/places]
Size=48
Context=Places
Type=Fixed

[64x64/places]
Size=64
Context=Places
Type=Fixed
```

## `share/icons/default/index.theme`

```text
[Icon Theme]
Name=Nocturne cursor fallback
Inherits=Nocturne-Cursors
```

## `assets/wallpaper.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1600" viewBox="0 0 2560 1600">
<defs>
 <radialGradient id="bg" cx="73%" cy="49%" r="66%"><stop stop-color="#201031"/><stop offset=".47" stop-color="#100b19"/><stop offset="1" stop-color="#07070b"/></radialGradient>
 <linearGradient id="rim" x1="0" y1="1" x2="1" y2="0"><stop stop-color="#2b1547"/><stop offset=".37" stop-color="#7c3cc7"/><stop offset=".65" stop-color="#dabaff"/><stop offset=".8" stop-color="#8651c0"/><stop offset="1" stop-color="#1d102a"/></linearGradient>
 <radialGradient id="planet" cx="74%" cy="26%" r="75%"><stop stop-color="#41245c"/><stop offset=".3" stop-color="#1b102b"/><stop offset=".75" stop-color="#08080e"/><stop offset="1" stop-color="#08070c"/></radialGradient>
 <filter id="glow"><feGaussianBlur stdDeviation="18"/></filter>
 <filter id="soft"><feGaussianBlur stdDeviation="55"/></filter>
</defs>
<rect width="2560" height="1600" fill="url(#bg)"/>
<ellipse cx="1750" cy="820" rx="540" ry="480" fill="#6e2cb9" opacity=".1" filter="url(#soft)"/>
<g transform="translate(1730 790) rotate(-28)">
 <ellipse rx="720" ry="245" fill="none" stroke="#7e4ab4" stroke-width="1" opacity=".16"/>
 <ellipse rx="780" ry="290" fill="none" stroke="#7e4ab4" stroke-width="1" opacity=".08"/>
</g>
<circle cx="1730" cy="790" r="370" fill="url(#planet)" stroke="#362047" stroke-width="1"/>
<g transform="translate(1730 790) rotate(-28)">
 <ellipse rx="615" ry="188" fill="none" stroke="#a66ce9" stroke-width="12" filter="url(#glow)" opacity=".5"/>
 <ellipse rx="615" ry="188" fill="none" stroke="url(#rim)" stroke-width="4"/>
 <ellipse rx="626" ry="199" fill="none" stroke="url(#rim)" stroke-width="1" opacity=".4"/>
</g>
<g fill="#c8a2ef"><circle cx="2250" cy="430" r="3" opacity=".6"/><circle cx="1110" cy="1110" r="2" opacity=".5"/><circle cx="2080" cy="1260" r="2" opacity=".35"/></g>
<path d="M150 1330h56" stroke="#ad83e2" stroke-width="2"/>
<text x="150" y="1380" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#b8a4cf">NOCTURNE</text>
<text x="150" y="1414" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#635570">A QUIETER ORBIT.</text>
</svg>
```

## `config/fastfetch/config.jsonc`

```json
{
  "logo": {
    "type": "kitty-direct",
    "source": "~/.config/fastfetch/nocturne-arch.png",
    "width": 26,
    "height": 13,
    "padding": {
      "top": 1,
      "left": 0,
      "right": 4
    }
  },
  "display": {
    "separator": " : ",
    "color": {
      "keys": "#b69af7",
      "title": "#ceb4ff",
      "output": "#e4dced",
      "separator": "#71637f"
    },
    "key": {
      "width": 16
    }
  },
  "modules": [
    "break",
    {
      "type": "custom",
      "format": "  ◈  N O C T U R N E  ·  a quieter orbit."
    },
    {
      "type": "custom",
      "format": "╭────────────────────────────────────────────────╮"
    },
    {
      "type": "host",
      "key": "  󰌢 Host",
      "keyColor": "#9ccbd2",
      "format": "{name}"
    },
    {
      "type": "os",
      "key": "  󰣇 OS",
      "keyColor": "#b69af7"
    },
    {
      "type": "kernel",
      "key": "   Kernel",
      "keyColor": "#ceb4ff"
    },
    {
      "type": "packages",
      "key": "  󰏖 Packages",
      "keyColor": "#a5ccb3"
    },
    {
      "type": "display",
      "key": "  󰍹 Display",
      "keyColor": "#9ccbd2",
      "format": "{width}×{height} @ {refresh-rate} Hz"
    },
    {
      "type": "terminal",
      "key": "   Terminal",
      "keyColor": "#e5c89a"
    },
    {
      "type": "wm",
      "key": "   WM",
      "keyColor": "#b69af7"
    },
    {
      "type": "custom",
      "format": "╰────────────────────────────────────────────────╯"
    },
    "break",
    {
      "type": "title",
      "key": "  ",
      "keyColor": "#9ccbd2",
      "format": "{user-name} @ {host-name}"
    },
    {
      "type": "custom",
      "format": "╭────────────────────────────────────────────────╮"
    },
    {
      "type": "cpu",
      "key": "   CPU",
      "keyColor": "#a1a5e9"
    },
    {
      "type": "gpu",
      "key": "  󰢮 GPU",
      "keyColor": "#a1a5e9"
    },
    {
      "type": "gpu",
      "key": "   Driver",
      "keyColor": "#b69af7",
      "format": "{driver}"
    },
    {
      "type": "memory",
      "key": "   Memory",
      "keyColor": "#ceb4ff"
    },
    {
      "type": "disk",
      "key": "  󰋊 Disk",
      "keyColor": "#a5ccb3",
      "folders": "/"
    },
    {
      "type": "uptime",
      "key": "  󰔟 Uptime",
      "keyColor": "#ef8fa4"
    },
    {
      "type": "custom",
      "format": "╰────────────────────────────────────────────────╯"
    },
    {
      "type": "colors",
      "symbol": "circle",
      "paddingLeft": 2
    },
    "break"
  ]
}
```

## `config/fastfetch/nocturne-arch.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="640" viewBox="0 0 400 400">
<defs><mask id="arch"><path fill="white" d="M200 20 372 365 Q286 314 241 308 C246 249 232 222 204 222 C174 222 158 251 162 308 Q107 320 28 365 L146 130 181 153 151 119Z"/></mask></defs>
<g mask="url(#arch)"><path fill="#b69af7" d="M0 0H400V400H0z"/><path fill="#ceb4ff" d="M200 20 246 126 180 330 115 273Z"/><path fill="#71637f" d="M246 126 400 400 202 316Z"/><path fill="#a1a5e9" d="M28 365 115 273 159 314Z"/><path fill="#e4dced" d="M200 20 210 43 153 121 146 130Z"/><path fill="#231d2e" d="M286 269 339 290 318 258 400 400 231 313Z"/></g>
</svg>```
