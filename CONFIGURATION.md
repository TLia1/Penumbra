# Complete Nocturne configuration

Full installer, cursor generator, scripts and authored text configuration. Compiled Xcursor binaries are under `system/usr/share/icons/Nocturne-Cursors/cursors/`; their original SVGs are under `assets/cursors/`. Both are included alongside this Markdown file.

## `install.sh`

```bash
#!/usr/bin/env bash
# Nocturne installer. Run as the desktop user: ./install.sh
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MODE=${1:-all}
case "$MODE" in all|--system-only|--user-only|--boot-only) ;; *) echo "Usage: $0 [--system-only|--user-only|--boot-only]" >&2; exit 2;; esac
if [[ "$MODE" == --boot-only ]]; then
    if [[ $EUID == 0 ]]; then
        exec python3 "$ROOT/tools/install-boot.py"
    else
        exec sudo python3 "$ROOT/tools/install-boot.py"
    fi
fi
STAMP=$(date +%Y%m%d-%H%M%S)
# Replaced by the Quickshell shell (bar, notifications, OSD) and awww (wallpaper).
legacy_packages=(waybar mako swaybg)
legacy_configs=(waybar mako)
ask() {
    if [[ ! -t 0 ]]; then printf '%s [y/N] — skipped (noninteractive)\n' "$1"; return 1; fi
    local answer; read -r -p "$1 [y/N] " answer
    [[ ${answer,,} == y || ${answer,,} == yes ]]
}
packages=(neovim git ripgrep wl-clipboard unzip nodejs npm pacman-contrib flatpak hyprland kitty fastfetch dolphin sddm quickshell awww rofi fish starship hyprlock hypridle breeze breeze-cursors breeze-icons breeze-gtk papirus-icon-theme qt6ct qt5ct qt5-wayland qt5-quickcontrols2 blueman network-manager-applet networkmanager pavucontrol pipewire-pulse wireplumber ttf-jetbrains-mono-nerd inter-font grim slurp satty hyprpicker cliphist python-pillow polkit-kde-agent bluez bluez-utils brightnessctl playerctl xdg-desktop-portal-hyprland xdg-desktop-portal-gtk htop libnotify librsvg xorg-xcursorgen)
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
    # Offer to remove components Nocturne no longer uses; set NOCTURNE_REMOVE_LEGACY=1 or 0 to skip the question.
    mapfile -t installed < <(pacman -Qq "${legacy_packages[@]}" 2>/dev/null || true)
    if (( ${#installed[@]} )); then
        if [[ ${NOCTURNE_REMOVE_LEGACY:-ask} == 1 ]] || { [[ ${NOCTURNE_REMOVE_LEGACY:-ask} == ask ]] && ask "Remove packages Nocturne no longer uses (${installed[*]})?"; }; then
            pacman -Q "${installed[@]}" > "$backup/removed-packages.txt"
            # -s also drops their now-unneeded dependencies, never explicitly installed packages.
            pacman -Rns --noconfirm "${installed[@]}" || echo "Could not remove ${installed[*]}; another package may still depend on them." >&2
        fi
    fi
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
    # Boot assets are deliberately outside system/: deploy only after opt-in.
    python3 "$ROOT/tools/install-boot.py" || echo 'Optional boot theming did not complete; see diagnostics above.' >&2
    echo "System backup: $backup"
    exit 0
fi
[[ $EUID != 0 ]] || { echo 'Run this installer as your regular desktop user.' >&2; exit 1; }
# sudo resets the environment, so hand the phase its options explicitly.
if [[ "$MODE" != --user-only ]]; then sudo NOCTURNE_SKIP_PACKAGES="${NOCTURNE_SKIP_PACKAGES:-0}" NOCTURNE_REMOVE_LEGACY="${NOCTURNE_REMOVE_LEGACY:-ask}" "$ROOT/install.sh" --system-only; fi
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
# Wallpapers are managed separately and backed up on subsequent installations.
for wallpaper in wallpaper.png wallpaper-clean.png wallpaper-dawn.png wallpaper-dawn-clean.png; do
 if [[ -e "$HOME/.local/share/nocturne/$wallpaper" ]]; then
  mkdir -p "$backup/.local/share/nocturne"
  cp -a "$HOME/.local/share/nocturne/$wallpaper" "$backup/.local/share/nocturne/"
 else printf '%s\n' "$HOME/.local/share/nocturne/$wallpaper" >> "$backup/new-files.txt"; fi
 cp "$ROOT/assets/$wallpaper" "$HOME/.local/share/nocturne/$wallpaper"
done
# The lock screen follows the chosen wallpaper; nocturne-wallpaper repoints this link.
[[ -e "$HOME/.local/share/nocturne/lock.png" ]] || ln -sfn "$HOME/.local/share/nocturne/wallpaper-clean.png" "$HOME/.local/share/nocturne/lock.png"
# Retire the previous bar, notification daemon and wallpaper setter: stop them and move their configs into the backup.
for process in "${legacy_packages[@]}"; do pkill -u "$UID" -x "$process" 2>/dev/null || true; done
for name in "${legacy_configs[@]}"; do
    if [[ -e "$HOME/.config/$name" ]]; then
        mkdir -p "$backup/.config"
        mv "$HOME/.config/$name" "$backup/.config/$name"
        printf 'Moved ~/.config/%s to the backup; it is no longer used.\n' "$name"
    fi
done
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
for stale in ASSETS.glob('*.svg'):stale.unlink()
shutil.rmtree(THEME/'cursors',ignore_errors=True)
ASSETS.mkdir(parents=True,exist_ok=True)
(THEME/'cursors').mkdir(parents=True,exist_ok=True)
# Palette: midnight outline, moonlit lavender body, Nocturne violet accents.
D='#100b1b'; F='url(#body)'; V='#b69af7'; A='#8a63e8'; C='#9a82c9'; R='#ef8fa4'; O=1.6
DEFS=('<defs><linearGradient id="body" gradientUnits="userSpaceOnUse" x1="0" y1="2" x2="0" y2="30">'
 '<stop offset="0" stop-color="#faf6ff"/><stop offset="1" stop-color="#d4c2ff"/></linearGradient>'
 '<filter id="shadow" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation=".9"/></filter></defs>')
def svg(*layers):
 # Every part gets a midnight rim; each layer's rims sit under its fills so overlapping parts merge into one silhouette.
 rims=''.join(r for layer in layers for r,_ in layer)
 body=''.join(''.join(r for r,_ in layer)+''.join(f for _,f in layer) for layer in layers)
 return (f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">{DEFS}'
  f'<g filter="url(#shadow)" opacity=".42" transform="translate(.4 1.1)">{rims}</g>'
  f'<g stroke-linejoin="round" stroke-linecap="round">{body}</g></svg>')
def shape(d,fill=F):return (f'<path d="{d}" fill="{D}" stroke="{D}" stroke-width="{2*O}"/>',f'<path d="{d}" fill="{fill}"/>')
def cap(x1,y1,x2,y2,w,fill=F):
 line=f'<path d="M{x1:.2f} {y1:.2f} L{x2:.2f} {y2:.2f}" fill="none" stroke="{{}}" stroke-width="{{}}"/>'
 return (line.format(D,w+2*O),line.format(fill,w))
def disc(cx,cy,r,fill=F):return shape(f'M{cx-r} {cy} a{r} {r} 0 1 0 {2*r} 0 a{r} {r} 0 1 0 {-2*r} 0 Z',fill)
def ring(cx,cy,r,w,fill=F):
 circle=f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{{}}" stroke-width="{{}}"/>'
 return (circle.format(D,w+2*O),circle.format(fill,w))
def mark(d,color=D,w=1.7):return ('',f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}"/>')
def rounded(points,r):
 """Closed polygon with every corner softened by a quadratic of radius r."""
 d='';n=len(points)
 for i,(x,y) in enumerate(points):
  ends=[]
  for px,py in (points[i-1],points[(i+1)%n]):
   k=r/math.hypot(px-x,py-y);ends.append((x+(px-x)*k,y+(py-y)*k))
  d+=('M' if not i else 'L')+f'{ends[0][0]:.2f} {ends[0][1]:.2f} Q{x} {y} {ends[1][0]:.2f} {ends[1][1]:.2f} '
 return d+'Z'
def turn(points,deg,cx=16,cy=16):
 a=math.radians(deg);c,s=math.cos(a),math.sin(a)
 return [(round(cx+(x-cx)*c-(y-cy)*s,3),round(cy+(x-cx)*s+(y-cy)*c,3)) for x,y in points]
# Soft sail-shaped arrow: straight left edge, gently scooped underside.
POINTER='M5 4.3 Q5 2.6 6.3 3.7 L19.2 14.9 Q20.6 16.3 18.6 16.6 Q12 17 8.1 22.6 Q5 26 5 22 Z'
pointer=[shape(POINTER)]
def hand(fingers,thumb,palm_top):
 parts=[cap(*f) for f in fingers]+[cap(*thumb),shape(f'M9.8 {palm_top} H27 V21.8 Q27 29.6 19.8 29.6 H15.2 Q12.2 29.6 10.2 26.6 Z')]
 # Creases run from the valley between two fingers down into the palm.
 for a,b in zip(fingers,fingers[1:]):
  top=max(a[1],b[1])+1.2
  parts.append(mark(f'M{(a[0]+b[0])/2:.2f} {top:.2f} V{max(top+1.6,palm_top+2.4):.2f}',C,.9))
 return parts
point=hand([(12.6,4.6,12.6,18,5.2),(17.4,12.6,17.4,18,4.8),(21.6,14,21.6,18,4.4),(25.1,15.8,25.1,18,3.8)],(6,19.4,10.6,24.6,5),16.4)
grab=hand([(12,7.4,12,17,4.6),(16.6,5,16.6,17,4.6),(21,6.4,21,17,4.4),(25,9.4,25,17.6,3.8)],(6.2,15.6,10.4,21.4,4.6),15)
fist=hand([(12,12.8,12,17,4.6),(16.6,11.8,16.6,17,4.6),(21,12.4,21,17,4.4),(25,13.8,25,17.6,3.8)],(8.6,19.2,13.4,21.4,4.4),15)
UP=[(16,3.6),(22.2,11.6),(9.8,11.6)]
def arrows(*angles,points=UP):return [shape(rounded(turn(points,a),1.9)) for a in angles]+[disc(16,16,1.7,V)]
SMALL=[(16,2.6),(21,8.6),(11,8.6)]
text=[cap(16,5.5,16,26.5,2.8)]
target=[ring(16,16,7.4,1.8)]+[cap(*(c for xy in turn([(16,2.6),(16,7.6)],a) for c in xy),1.8) for a in (0,90,180,270)]+[disc(16,16,2,V)]
def badge(symbol,fill=V):return [disc(23.2,23.2,6.2,fill),mark(symbol)]
marks={'copy':'M20 23.2 H26.4 M23.2 20 V26.4','alias':'M20.6 25.8 L25.4 21 M21.8 20.8 H25.6 V24.6',
 'help':'M21.1 21.8 Q21.4 19.4 23.4 19.4 Q25.6 19.5 25.5 21.4 Q25.3 22.8 23.4 23.6 V24.2 M23.4 26.6 V26.7','context-menu':'M20.4 21 H26 M20.4 23.2 H26 M20.4 25.4 H26'}
def lens(symbol):return [cap(19.6,18.6,27.2,26.2,4.2),disc(14,12.6,8.4),ring(14,12.6,8.4,0.01,A),mark(symbol,D,2)]
shapes={'left_ptr':([pointer],5,3),'hand2':([point],12.6,2.4),'xterm':([text],16,16),
 'ns-resize':([arrows(0,180)],16,16),'ew-resize':([arrows(90,270)],16,16),
 'nwse-resize':([arrows(-45,135)],16,16),'nesw-resize':([arrows(45,225)],16,16),
 'fleur':([arrows(0,90,180,270,points=SMALL)],16,16),'crosshair':([target],16,16),
 'openhand':([grab],16,16),'closedhand':([fist],16,16),'forbidden':([pointer,badge('M20.9 20.9 L25.5 25.5 M26.4 23.2 a3.2 3.2 0 1 0 -6.4 0 a3.2 3.2 0 1 0 6.4 0',R)],5,3),
 'vertical-text':([[cap(5.5,16,26.5,16,2.8)]],16,16),'cell':([[cap(16,5,16,27,5),cap(5,16,27,16,5)]],16,16),
 'zoom-in':([lens('M14 8.6 V16.6 M10 12.6 H18')],14,12.6),'zoom-out':([lens('M10 12.6 H18')],14,12.6)}
for kind,symbol in marks.items():shapes[kind]=([pointer,badge(symbol)],5,3)
def spinner(t,cx=16,cy=16,r=8.6,w=4.4):
 """Violet arc chasing round a lavender track; it stretches and shrinks once per turn and loops seamlessly."""
 length=24+232*math.sin(math.pi*t)**2;mid=720*t
 head,tail=[math.radians(mid+s*length/2) for s in (1,-1)]
 x1,y1,x2,y2=cx+r*math.sin(tail),cy-r*math.cos(tail),cx+r*math.sin(head),cy-r*math.cos(head)
 arc=f'<path d="M{x1:.3f} {y1:.3f} A{r} {r} 0 {int(length>180)} 1 {x2:.3f} {y2:.3f}" fill="none" stroke="{A}" stroke-width="{w-.6}"/>'
 track=ring(cx,cy,r,w)
 return [(track[0],track[1]+arc)]
FRAMES=24
frames={name:([svg(*layers)],x,y) for name,(layers,x,y) in shapes.items()}
frames['watch']=([svg(spinner(i/FRAMES)) for i in range(FRAMES)],16,16)
frames['left_ptr_watch']=([svg(pointer,spinner(i/FRAMES,23.4,23,5,3.2)) for i in range(FRAMES)],5,3)
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
    lines.append(f'{size} {round(hx*size/32)} {round(hy*size/32)} {png} {40 if len(images)>1 else 0}')
  cfg=tmp/(name+'.conf');cfg.write_text('\n'.join(lines)+'\n')
  subprocess.run(['xcursorgen',str(cfg),str(THEME/'cursors'/name)],check=True)
 for canonical,names in aliases.items():
  for alias in names.split():shutil.copyfile(THEME/'cursors'/canonical,THEME/'cursors'/alias)
(THEME/'index.theme').write_text('[Icon Theme]\nName=Nocturne Cursors\nComment=Soft lavender cursors with midnight outlines and a violet ring spinner\nInherits=breeze_cursors\n')
# SVG contact sheet, keeping the artwork editable and inspectable.
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="570" viewBox="0 0 960 570"><rect width="960" height="570" rx="24" fill="#100d18"/><text x="40" y="50" fill="#e4dced" font-family="Inter" font-size="24">NOCTURNE / CURSORS</text><text x="40" y="79" fill="#8f809f" font-family="Inter" font-size="13">Soft lavender silhouettes · midnight outlines · violet ring spinner</text>']
for n,(name,(images,_,_)) in enumerate(frames.items()):
 x=40+(n%6)*150;y=110+(n//6)*110
 inner=images[len(images)//3].split('>',1)[1].rsplit('</svg>',1)[0]
 parts.append(f'<rect x="{x}" y="{y}" width="132" height="82" rx="12" fill="#1a1324"/><g transform="translate({x+42} {y+7}) scale(1.5)">{inner}</g><text x="{x+66}" y="{y+99}" fill="#a99abb" font-family="Inter" font-size="11" text-anchor="middle">{name}</text>')
parts.append('</svg>')
p=ROOT/'previews/cursors.svg';p.write_text(''.join(parts))
subprocess.run(['rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
print(f'Built {len(frames)} original shapes / {len(list((THEME/"cursors").iterdir()))} cursor names, five sizes each.')
```

## `tools/build-wallpapers.py`

```python
#!/usr/bin/env python3
"""Render each wallpaper and a wordmark-free variant for the lock screen and greeter."""
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
assets = root / 'assets'
for name in ('wallpaper', 'wallpaper-dawn'):
    source = (assets / f'{name}.svg').read_text()
    # The wordmark blurs into a smudge on hyprlock and crowds the SDDM card.
    clean = re.sub(r'<g id="wordmark">.*?</g>\n', '', source, flags=re.S)
    assert clean.count('<text') == 0 and clean != source, f'wordmark group not found in {name}.svg'
    (assets / f'{name}-clean.svg').write_text(clean)
    for variant in (name, f'{name}-clean'):
        subprocess.run(['rsvg-convert', str(assets / f'{variant}.svg'), '-o', str(assets / f'{variant}.png')], check=True)
shutil.copyfile(assets / 'wallpaper-clean.png', root / 'system/usr/share/sddm/themes/nocturne/wallpaper.png')
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
# The Nocturne shell draws the session overlay; this rofi menu is the fallback without it.
quickshell -c nocturne ipc call panel session >/dev/null 2>&1 && exit
# One row of large icon tiles; rofi returns the selected index, so labels can change freely.
tiles='window { width: 620px; padding: 22px; } mainbox { children: [ listview ]; }
listview { columns: 5; lines: 1; spacing: 10px; fixed-columns: true; fixed-height: true; }
element { orientation: vertical; padding: 16px 0 10px; border-radius: 16px; }
element-text { horizontal-align: 0.5; font: "Inter 10"; }'
menu() {
 local -n labels=$1 icons=$2; local i
 for i in "${!labels[@]}"; do
  printf "<span font_desc='JetBrainsMono Nerd Font 26'>%s</span>\n<span alpha='75%%'>%s</span>|" "${icons[i]}" "${labels[i]}"
 done
}
pick() { rofi -dmenu -sep '|' -eh 4 -markup-rows -no-custom -format i -no-show-icons -p "$1" -theme-str "$tiles $2"; }
names=(Lock Suspend 'Log out' Restart 'Shut down')
glyphs=(󰌾 󰤄 󰍃 󰜉 󰐥)
choice=$(menu names glyphs | pick SESSION '') || exit 0
case "$choice" in
 0) loginctl lock-session; exit;;
 1) systemctl suspend; exit;;
 2) action=logout;;
 3) action=reboot;;
 4) action=poweroff;;
 *) exit;;
esac
confirm=(Cancel "${names[choice]}")
confirm_glyphs=(󰜺 "${glyphs[choice]}")
answer=$(menu confirm confirm_glyphs | pick CONFIRM 'window { width: 300px; } listview { columns: 2; }') || exit 0
[[ "$answer" = 1 ]] || exit 0
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
    pkill -x quickshell || true
    for attempt in {1..20}; do
        pgrep -u "$UID" -x quickshell >/dev/null || break
        sleep 0.1
    done
fi
start() {
 local process=$1; shift
 if ! pgrep -u "$UID" -x "$process" >/dev/null; then
  nohup "$@" >"$HOME/.local/state/nocturne/$process.log" 2>&1 9>&- &
 fi
}
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORMTHEME GTK_THEME XCURSOR_THEME XCURSOR_SIZE
hyprctl setcursor Nocturne-Cursors 28 >/dev/null
start awww-daemon awww-daemon
# Bar, notifications, OSD, control center and session overlay.
start quickshell quickshell -c nocturne
start hypridle hypridle
# Clipboard history for text and images.
if ! pgrep -u "$UID" -f "^wl-paste --type text --watch cliphist store" >/dev/null; then
 nohup wl-paste --type text --watch cliphist store >/dev/null 2>&1 9>&- &
 nohup wl-paste --type image --watch cliphist store >/dev/null 2>&1 9>&- &
fi
if ! pgrep -u "$UID" -f "^/usr/lib/polkit-kde-authentication-agent-1" >/dev/null; then
 nohup /usr/lib/polkit-kde-authentication-agent-1 >"$HOME/.local/state/nocturne/polkit.log" 2>&1 9>&- &
fi
nohup "$HOME/.local/bin/nocturne-wallpaper" restore >"$HOME/.local/state/nocturne/wallpaper.log" 2>&1 9>&- &
exec 9>&-
```

## `bin/nocturne-shot`

```bash
#!/usr/bin/env bash
# Region screenshot to ~/Pictures/Screenshots; "annotate" opens it in Satty first.
set -euo pipefail
mkdir -p "$HOME/Pictures/Screenshots"
region=$(slurp -b 100d18aa -c b69af7 -w 2) || exit 0
file="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
if [[ ${1:-} = annotate ]]; then
 grim -g "$region" - | satty --filename - --output-filename "$file"
 exit
fi
grim -g "$region" "$file"
wl-copy < "$file"
notify-send -a Nocturne -i "$file" 'Screenshot saved' "Copied to clipboard · ${file/#$HOME/\~}"
```

## `bin/nocturne-clipboard`

```bash
#!/usr/bin/env bash
# Clipboard history from cliphist, picked in the Nocturne launcher style.
set -euo pipefail
if [[ ${1:-} = clear ]]; then
 cliphist wipe
 notify-send -a Nocturne 'Clipboard cleared' 'History has been wiped.'
 exit
fi
choice=$(cliphist list | rofi -dmenu -i -p CLIPBOARD -display-columns 2 \
 -theme-str 'entry { placeholder: "Search clipboard history…"; } listview { lines: 8; } element { padding: 9px 12px; }') || exit 0
cliphist decode <<<"$choice" | wl-copy
```

## `bin/nocturne-picker`

```bash
#!/usr/bin/env bash
# Pick any on-screen color; the hex value is copied to the clipboard.
set -euo pipefail
color=$(hyprpicker --autocopy --format=hex --no-fancy --quiet 2>/dev/null) || exit 0
[[ -n "$color" ]] || exit 0
notify-send -a Nocturne "Color copied · $color" "<span foreground='$color'>██████</span>  $color"
```

## `bin/nocturne-wallpaper`

```bash
#!/usr/bin/env bash
# Switch Nocturne wallpapers with an awww transition; the lock screen follows the choice.
set -euo pipefail
dir="$HOME/.local/share/nocturne"
state="$HOME/.local/state/nocturne/wallpaper"
names=(wallpaper wallpaper-dawn)
current=$(cat "$state" 2>/dev/null || echo wallpaper)
[[ -e "$dir/$current.png" ]] || current=wallpaper
transition=(--transition-type grow --transition-duration 1.4 --transition-fps 120)
case "${1:-next}" in
 next)
  for i in "${!names[@]}"; do [[ ${names[i]} = "$current" ]] && break; done
  current=${names[(i + 1) % ${#names[@]}]}
  # Grow each scene out of its planet.
  [[ $current = wallpaper-dawn ]] && transition+=(--transition-pos 0.32,0.37) || transition+=(--transition-pos 0.68,0.51);;
 restore) transition=(--transition-type none);;
 *) echo "Usage: nocturne-wallpaper [next|restore]" >&2; exit 2;;
esac
mkdir -p "${state%/*}"
printf '%s\n' "$current" > "$state"
ln -sfn "$dir/$current-clean.png" "$dir/lock.png"
for _ in {1..50}; do awww query >/dev/null 2>&1 && break; sleep 0.1; done
exec awww img "$dir/$current.png" --resize crop "${transition[@]}"
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
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1.2" })
hl.env("XCURSOR_THEME", "Nocturne-Cursors")
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
 input = {kb_layout = "fr", follow_mouse = 1, sensitivity = 0, touchpad = {natural_scroll = true}},
 misc = {disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0},
})
hl.curve("nocturne", {type = "bezier", points = {{0.16, 1}, {0.3, 1}}})
hl.curve("soft", {type = "bezier", points = {{0.4, 0}, {0.2, 1}}})
hl.curve("linear", {type = "bezier", points = {{0, 0}, {1, 1}}})
for _, a in ipairs({
 {"windows", 4.5, "nocturne", "slide"}, {"windowsIn", 4, "nocturne", "popin 94%"},
 {"windowsOut", 3, "soft", "popin 96%"}, {"border", 5, "nocturne", nil},
 {"borderangle", 60, "linear", "loop"},
 {"fade", 3, "soft", nil}, {"workspaces", 4.5, "nocturne", "slide"},
 {"layers", 3.5, "nocturne", "fade"}
}) do hl.animation({leaf=a[1], enabled=true, speed=a[2], bezier=a[3], style=a[4]}) end
local function exec(key, cmd) hl.bind(key, hl.dsp.exec_cmd(cmd)) end
exec("SUPER + Return", "kitty")
exec("SUPER + Q", "kitty")
exec("SUPER + E", "dolphin")
exec("SUPER + R", "rofi -show drun")
exec("SUPER + space", "rofi -show drun")
exec("SUPER + B", "firefox")
exec("SUPER + M", "~/.local/bin/nocturne-power")
exec("SUPER + L", "loginctl lock-session")
exec("SUPER + N", "quickshell -c nocturne ipc call notifications clear")
exec("SUPER + A", "quickshell -c nocturne ipc call panel control")
exec("SUPER + SHIFT + V", "~/.local/bin/nocturne-clipboard")
exec("SUPER + SHIFT + C", "~/.local/bin/nocturne-picker")
exec("SUPER + W", "~/.local/bin/nocturne-wallpaper next")
exec("SUPER + SHIFT + R", "~/.local/bin/nocturne-session restart")
exec("Print", "~/.local/bin/nocturne-shot")
exec("SHIFT + Print", "~/.local/bin/nocturne-shot annotate")
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
 XF86AudioRaiseVolume="~/.local/bin/nocturne-osd volume up",
 XF86AudioLowerVolume="~/.local/bin/nocturne-osd volume down",
 XF86AudioMute="~/.local/bin/nocturne-osd volume mute",
 XF86AudioMicMute="~/.local/bin/nocturne-osd microphone mute",
 XF86MonBrightnessUp="~/.local/bin/nocturne-osd brightness up", XF86MonBrightnessDown="~/.local/bin/nocturne-osd brightness down",
 XF86AudioPlay="playerctl play-pause", XF86AudioNext="playerctl next", XF86AudioPrev="playerctl previous"
}) do hl.bind(key, hl.dsp.exec_cmd(cmd), {locked=true, repeating=true}) end
hl.window_rule({name="settings", match={class="^(org.pulseaudio.pavucontrol|pavucontrol|blueman-manager|nm-connection-editor|qt6ct)$"}, float=true, size="820 540", center=true})
hl.window_rule({name="annotate", match={class="^(com.gabm.satty)$"}, float=true, center=true})
-- Frosted glass behind every Nocturne shell surface and the launcher.
hl.layer_rule({name="glass", match={namespace="^(nocturne-.*|rofi)$"}, blur=true, ignore_alpha=0.3})
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
    path = ~/.local/share/nocturne/lock.png
    blur_passes = 2
    blur_size = 3
    brightness = 0.7
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

## `config/quickshell/nocturne/shell.qml`

```qml
//@ pragma UseQApplication
//@ pragma IconTheme Nocturne
// NOCTURNE shell: bar, control center, notifications, OSD, calendar and session overlay.
// Run with `quickshell -c nocturne`; scripts talk to it with `quickshell -c nocturne ipc call …`.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }

    ControlCenter {}
    CalendarPanel {}
    NotificationPopups {}
    Osd {}
    SessionMenu {}

    IpcHandler {
        target: "osd"
        function flash(kind: string, value: int, muted: bool): void {
            Ui.showOsd(kind, value, muted);
        }
    }

    IpcHandler {
        target: "panel"
        function control(): void { Ui.toggleControl(); }
        function wifi(): void { Ui.openControl("wifi"); }
        function bluetooth(): void { Ui.openControl("bluetooth"); }
        function calendar(): void { Ui.toggleCalendar(); }
        function session(): void { Ui.openSession(); }
        function close(): void { Ui.close(); Ui.sessionOpen = false; }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clear(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
    }

    IpcHandler {
        target: "updates"
        function refresh(): void { Sys.refreshUpdates(); }
    }
}
```

## `config/quickshell/nocturne/Bar.qml`

```qml
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

// Floating capsules: launcher and clock left; workspaces and title centered; status right.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: 10; left: Theme.edge; right: Theme.edge }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight + 4
    color: "transparent"
    WlrLayershell.namespace: "nocturne-bar"

    IdleInhibitor {
        window: bar
        enabled: Ui.caffeine
    }

    Item {
    id: content
    anchors.fill: parent
    HoverHandler {
        onPointChanged: bar.updateTip(point.position)
        onHoveredChanged: if (!hovered) bar.updateTip(null)
    }

    // ── Left ────────────────────────────────────────────────────────
    RowLayout {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            padding: 14
            tip: "Applications"
            onClicked: Ui.run("rofi -show drun")
            Glyph { text: "󰣇"; size: 20; color: Theme.violetBright }
        }

        Capsule {
            id: clockCapsule
            padding: 18
            active: Ui.calendarOpen
            tip: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
            onClicked: Ui.toggleCalendar()
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
            Label {
                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: 14
                font.weight: Font.Bold
                color: Ui.calendarOpen ? Theme.violetInk : "#eee8ff"
            }
        }
    }

    // ── Center ──────────────────────────────────────────────────────
    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.gap

        Repeater {
            model: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor?.name === bar.screen.name && (w.toplevels.values.length > 0 || w.focused || w.active))
                .sort((a, b) => a.id - b.id)
            delegate: Capsule {
                required property var modelData
                readonly property bool current: modelData.active && modelData.monitor?.name === bar.screen.name
                implicitWidth: current ? 52 : Theme.barHeight
                padding: 0
                active: current
                color: current ? Theme.violet : modelData.urgent ? Theme.rose : (hovered ? Theme.hover : Theme.glass)
                onClicked: modelData.activate()
                Label {
                    text: modelData.name
                    color: current || modelData.urgent ? Theme.violetInk : hovered ? "#eee8ff" : "#aa97bf"
                    font.family: Theme.mono
                    font.weight: current ? Font.Bold : Font.Normal
                }
            }
        }

        Capsule {
            id: title
            // The Wayland toplevel protocol knows the focused window from startup; nothing is
            // activated on an empty workspace. Show it on the bar of the screen it is on.
            readonly property var client: ToplevelManager.activeToplevel
            readonly property bool shown: !!client && client.activated && client.title !== "" && client.screens.some(s => s.name === bar.screen.name)
            visible: shown
            interactive: false
            padding: 16
            tip: shown ? client.title : ""
            Label {
                text: title.shown ? title.client.title : ""
                Layout.maximumWidth: 260
                font.family: Theme.mono
                color: "#c8b8dc"
            }
        }
    }

    // ── Right ───────────────────────────────────────────────────────
    RowLayout {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.gap

        Capsule {
            visible: Sys.updates > 0
            padding: 12
            tip: Sys.updatesDetail
            onClicked: Ui.run(Ui.bin + "nocturne-updates open")
            Glyph { text: "󰚰"; color: Theme.violetBright }
            Label { text: Sys.updates; color: Theme.violetBright }
        }

        Capsule {
            padding: 12
            spacing: 12
            tip: `CPU ${Sys.cpu}% · Memory ${Sys.memoryDetail}`
            onClicked: Ui.run("kitty --class nocturne-monitor htop")
            RowLayout {
                spacing: 5
                Glyph { text: "󰻠"; size: 12; color: "#aaa0bb" }
                Label { text: Sys.cpu + "%"; font.pixelSize: 11; color: "#aaa0bb"; font.family: Theme.mono }
            }
            RowLayout {
                spacing: 5
                Glyph { text: "󰍛"; size: 12; color: "#aaa0bb" }
                Label { text: Sys.memory + "%"; font.pixelSize: 11; color: "#aaa0bb"; font.family: Theme.mono }
            }
        }

        Capsule {
            // nm-applet and blueman keep running for password and pairing prompts,
            // but the control center replaces their tray icons.
            readonly property var items: SystemTray.items.values.filter(i => !["nm-applet", "blueman"].includes(i.id))
            id: tray
            visible: items.length > 0
            interactive: false
            padding: 12
            spacing: 10
            Repeater {
                model: tray.items
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    implicitWidth: 18
                    implicitHeight: 18
                    IconImage {
                        id: trayIcon
                        anchors.fill: parent
                        source: trayItem.modelData.icon
                        visible: false
                    }
                    // Tinted to match the bar; full color on hover.
                    MultiEffect {
                        anchors.fill: parent
                        source: trayIcon
                        saturation: trayMouse.containsMouse ? 0 : -1
                        colorization: trayMouse.containsMouse ? 0 : 0.35
                        colorizationColor: Theme.violet
                        brightness: trayMouse.containsMouse ? 0 : 0.1
                        Behavior on saturation { NumberAnimation { duration: Theme.fast } }
                        Behavior on colorization { NumberAnimation { duration: Theme.fast } }
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: m => {
                            const item = trayItem.modelData;
                            if (m.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (m.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu) {
                                    const p = trayItem.mapToItem(bar.contentItem, 0, trayItem.height + 14);
                                    item.display(bar, p.x, p.y);
                                }
                            } else
                                item.activate();
                        }
                        onWheel: w => trayItem.modelData.scroll(w.angleDelta.y, false)
                    }
                }
            }
        }

        // Network, Bluetooth, audio, battery and notifications open the control center.
        Capsule {
            id: controls
            padding: 14
            spacing: 13
            active: Ui.controlOpen
            tip: `${Devices.networkName} · Bluetooth ${Devices.bluetoothName}` + (Devices.hasBattery ? `\n${Devices.batteryDetail}` : "")
            onClicked: m => m.button === Qt.RightButton ? Ui.run("pavucontrol") : Ui.toggleControl()
            onScrolled: delta => Ui.run(Ui.bin + "nocturne-osd volume " + (delta > 0 ? "up" : "down"))
            readonly property color tint: Ui.controlOpen ? Theme.violetInk : Theme.textSoft

            Glyph { text: Devices.networkGlyph; color: Devices.networkName === "Offline" && !Ui.controlOpen ? Theme.dim : controls.tint }
            Glyph { text: Devices.bluetoothGlyph; color: !Devices.bluetoothOn && !Ui.controlOpen ? Theme.dim : controls.tint }
            RowLayout {
                spacing: 5
                Glyph { text: Devices.volumeGlyph; color: Devices.muted && !Ui.controlOpen ? Theme.dim : controls.tint }
                Label {
                    visible: !Devices.muted
                    text: Devices.volume + "%"
                    font.family: Theme.mono
                    color: controls.tint
                }
            }
            RowLayout {
                visible: Devices.hasBattery
                spacing: 5
                Glyph { text: Devices.batteryGlyph; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
                Label { text: Devices.batteryPercent + "%"; font.family: Theme.mono; color: Ui.controlOpen ? Theme.violetInk : Devices.batteryColor }
            }
            Item {
                implicitWidth: bell.implicitWidth
                implicitHeight: bell.implicitHeight
                Glyph {
                    id: bell
                    text: Notifs.dnd ? "󰂛" : Notifs.count ? "󰂚" : "󰂜"
                    color: Ui.controlOpen ? Theme.violetInk : Notifs.dnd ? Theme.dim : Theme.textSoft
                }
                Rectangle {
                    visible: Notifs.count > 0 && !Notifs.dnd
                    width: 6; height: 6; radius: 3
                    color: Ui.controlOpen ? Theme.violetInk : Theme.violetBright
                    anchors { right: bell.right; top: bell.top; rightMargin: -2; topMargin: 1 }
                }
            }
        }

        Capsule {
            padding: 14
            tip: "Session & power"
            onClicked: Ui.openSession()
            Glyph { text: "󰐥"; size: 16; color: Theme.violetBright }
        }
    }

    }

    // ── Tooltip ─────────────────────────────────────────────────────
    property Item tipTarget: null
    function updateTip(pos) {
        const target = pos ? capsuleAt(pos) : null;
        if (target !== tipTarget) {
            tipTarget = target;
            tipWindow.visible = false;
            tipDelay.restart();
        }
    }
    // Innermost item under the pointer that declares a tooltip.
    function capsuleAt(pos) {
        let found = null, item = content, p = pos;
        for (let child = item.childAt(p.x, p.y); child; child = item.childAt(p.x, p.y)) {
            p = item.mapToItem(child, p.x, p.y);
            if (child.tip !== undefined)
                found = child;
            item = child;
        }
        return found;
    }
    Timer {
        id: tipDelay
        interval: 550
        onTriggered: tipWindow.visible = !!bar.tipTarget && bar.tipTarget.tip !== ""
    }
    PopupWindow {
        id: tipWindow
        anchor.item: bar.tipTarget ?? bar.contentItem
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: 8
        implicitWidth: tipText.implicitWidth + 24
        implicitHeight: tipText.implicitHeight + 16
        color: "transparent"
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusSmall
            color: Theme.glassStrong
            border.color: Theme.lineStrong
            Label {
                id: tipText
                anchors.centerIn: parent
                text: bar.tipTarget?.tip ?? ""
                color: "#e8e1f3"
                elide: Text.ElideNone
            }
        }
    }
}
```

## `config/quickshell/nocturne/CalendarPanel.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Month view under the clock.
Panel {
    id: root
    anchors { top: true; left: true }
    margins.left: Theme.edge
    sheetWidth: 320
    open: Ui.calendarOpen
    onDismissed: Ui.dismiss()

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    onOpenChanged: if (open) { today = new Date(); month = today.getMonth(); year = today.getFullYear(); }
    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        month = d.getMonth();
        year = d.getFullYear();
    }

    ColumnLayout {
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 10

        Label {
            text: Qt.formatDate(root.today, "dddd")
            font.pixelSize: 11
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
            color: Theme.violet
        }
        Label {
            text: Qt.formatDate(root.today, "d MMMM yyyy")
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Label {
                Layout.fillWidth: true
                text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
                font.weight: Font.DemiBold
                color: Theme.textSoft
            }
            Repeater {
                model: [{ glyph: "󰅁", delta: -1 }, { glyph: "󰅂", delta: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    color: navArea.containsMouse ? Theme.hover : "transparent"
                    Glyph { anchors.centerIn: parent; text: modelData.glyph; color: Theme.textSoft }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shift(modelData.delta)
                    }
                }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Label {
                required property string shortName
                text: shortName.slice(0, 2)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 34 + 5 * 2
            month: root.month
            year: root.year
            locale: Qt.locale()
            spacing: 2
            delegate: Rectangle {
                required property var model
                readonly property bool isToday: model.today
                implicitWidth: 34
                implicitHeight: 34
                radius: 17
                color: isToday ? Theme.violet : "transparent"
                Label {
                    anchors.centerIn: parent
                    text: model.day
                    font.weight: parent.isToday ? Font.Bold : Font.Normal
                    color: parent.isToday ? Theme.violetInk : model.month === root.month ? Theme.text : Theme.dim
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Capsule.qml`

```qml
import QtQuick
import QtQuick.Layouts

// A floating glass pill; children are laid out in a row.
Rectangle {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: 13
    property string tip: ""
    property bool interactive: true
    property bool active: false
    readonly property bool hovered: mouse.containsMouse

    signal clicked(var mouse)
    signal scrolled(int delta)

    implicitHeight: Theme.barHeight
    implicitWidth: row.implicitWidth + padding * 2
    radius: height / 2
    color: active ? Theme.violet : (interactive && hovered ? Theme.hover : Theme.glass)
    border.width: 1
    border.color: active ? Theme.violetBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

    // Declared before the row so it sits underneath: children with their own
    // mouse handling (tray icons) receive their clicks, plain contents fall through.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w.angleDelta.y)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
    }
}
```

## `config/quickshell/nocturne/ControlCenter.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Widgets

// Quick settings, sliders, media and notification history, under the status capsule.
Panel {
    id: root
    anchors { top: true; right: true }
    margins.right: Theme.edge
    sheetWidth: 400
    open: Ui.controlOpen
    onDismissed: Ui.dismiss()

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null

    property string uptime: ""
    onOpenChanged: if (open) { uptimeFile.reload(); Sys.refreshBrightness(); }
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const s = Number(text().split(" ")[0]), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60);
            root.uptime = h ? `up ${h} h ${m} min` : `up ${m} min`;
        }
    }

    // One page at a time: the main view, or Wi-Fi / Bluetooth settings.
    ColumnLayout {
        id: pages
        x: 18
        y: 18
        width: root.sheetWidth - 36
        spacing: 0

        Connections {
            target: Ui
            function onControlPageChanged() { pageIn.restart(); }
        }
        ParallelAnimation {
            id: pageIn
            NumberAnimation { target: pages; property: "opacity"; from: 0; to: 1; duration: Theme.normal; easing.type: Easing.OutCubic }
            NumberAnimation { target: pages; property: "x"; from: Ui.controlPage === "main" ? -6 : 42; to: 18; duration: Theme.slow; easing.type: Easing.OutExpo }
        }

        WifiPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "wifi"
            active: root.open && visible
        }

        BluetoothPage {
            Layout.fillWidth: true
            visible: Ui.controlPage === "bluetooth"
            active: root.open && visible
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: Ui.controlPage === "main"
            spacing: 14

            // Header: who, how long, and session shortcuts.
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: 21
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.violet }
                        GradientStop { position: 1; color: Theme.violetDeep }
                    }
                    Label {
                        anchors.centerIn: parent
                        text: Quickshell.env("USER").charAt(0).toUpperCase()
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: Theme.violetInk
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label { text: Quickshell.env("USER"); font.pixelSize: 14; font.weight: Font.DemiBold }
                    Label { text: root.uptime; font.pixelSize: 11; color: Theme.muted }
                }
                Repeater {
                    model: [
                        { glyph: "󰸉", tip: "Next wallpaper", run: () => Ui.run(Ui.bin + "nocturne-wallpaper next") },
                        { glyph: "󰌾", tip: "Lock", run: () => { Ui.close(); Ui.run("loginctl lock-session"); } },
                        { glyph: "󰐥", tip: "Session", run: () => Ui.openSession() }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: 36
                        implicitHeight: 36
                        radius: 18
                        color: headerArea.containsMouse ? Theme.hover : Theme.raised
                        border.color: Theme.line
                        Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 15; color: Theme.violetBright }
                        MouseArea {
                            id: headerArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.run()
                        }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.networkGlyph
                    title: Devices.wifiDevice ? "Wi-Fi" : "Network"
                    subtitle: Devices.networkName
                    on: Devices.wifiDevice ? Networking.wifiEnabled : Devices.wired
                    hasMore: true
                    onToggled: Devices.wifiDevice ? Networking.wifiEnabled = !Networking.wifiEnabled : Ui.controlPage = "wifi"
                    onMore: Ui.controlPage = "wifi"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Devices.bluetoothGlyph
                    title: "Bluetooth"
                    subtitle: Devices.bluetoothName
                    on: Devices.bluetoothOn
                    available: !!Devices.adapter
                    hasMore: true
                    onToggled: Devices.adapter.enabled = !Devices.adapter.enabled
                    onMore: Ui.controlPage = "bluetooth"
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Notifs.dnd ? "󰂛" : "󰂚"
                    title: "Do not disturb"
                    subtitle: Notifs.dnd ? "Only critical alerts" : "Off"
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
                Tile {
                    Layout.fillWidth: true
                    glyph: Ui.caffeine ? "󰅶" : "󰛊"
                    title: "Stay awake"
                    subtitle: Ui.caffeine ? "Idle lock paused" : "Off"
                    on: Ui.caffeine
                    onToggled: Ui.caffeine = !Ui.caffeine
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                SliderRow {
                    Layout.fillWidth: true
                    glyph: Devices.volumeGlyph
                    value: Devices.volume
                    muted: Devices.muted
                    onMoved: v => Devices.setVolume(v)
                    onGlyphClicked: if (Devices.sink) Devices.sink.muted = !Devices.sink.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: !!Devices.source
                    glyph: Devices.micMuted ? "󰍭" : "󰍬"
                    value: Devices.source ? Math.round(Devices.source.volume * 100) : 0
                    muted: Devices.micMuted
                    onMoved: v => { Devices.source.muted = false; Devices.source.volume = v / 100; }
                    onGlyphClicked: Devices.source.muted = !Devices.source.muted
                }
                SliderRow {
                    Layout.fillWidth: true
                    visible: Sys.brightness >= 0
                    glyph: "󰃟"
                    value: Sys.brightness
                    onMoved: v => Sys.setBrightness(v)
                }
            }

            // Media
            Rectangle {
                Layout.fillWidth: true
                visible: !!root.player
                implicitHeight: 76
                radius: Theme.radius
                color: Theme.raised
                border.color: Theme.line
                RowLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 12
                    ClippingRectangle {
                        implicitWidth: 56
                        implicitHeight: 56
                        radius: 12
                        color: Theme.hover
                        Image {
                            anchors.fill: parent
                            source: root.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        Glyph {
                            anchors.centerIn: parent
                            visible: !root.player?.trackArtUrl
                            text: "󰎆"
                            size: 22
                            color: Theme.violetBright
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { Layout.fillWidth: true; text: root.player?.trackTitle || root.player?.identity || ""; font.weight: Font.DemiBold }
                        Label { Layout.fillWidth: true; text: root.player?.trackArtist || root.player?.identity || ""; font.pixelSize: 11; color: Theme.muted }
                    }
                    Repeater {
                        model: [
                            { glyph: "󰒮", run: () => root.player.previous(), ok: root.player?.canGoPrevious },
                            { glyph: root.player?.isPlaying ? "󰏤" : "󰐊", run: () => root.player.togglePlaying(), ok: root.player?.canTogglePlaying, main: true },
                            { glyph: "󰒭", run: () => root.player.next(), ok: root.player?.canGoNext }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: modelData.main ? 38 : 30
                            implicitHeight: implicitWidth
                            radius: implicitWidth / 2
                            opacity: modelData.ok ? 1 : 0.4
                            color: modelData.main ? Theme.violet : mediaArea.containsMouse ? Theme.hover : "transparent"
                            Glyph { anchors.centerIn: parent; text: modelData.glyph; size: 16; color: modelData.main ? Theme.violetInk : Theme.text }
                            MouseArea {
                                id: mediaArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !!modelData.ok
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.run()
                            }
                        }
                    }
                }
            }

            // Notifications
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                Label {
                    Layout.fillWidth: true
                    text: Notifs.count ? `Notifications · ${Notifs.count}` : "Notifications"
                    font.pixelSize: 11
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: Theme.muted
                }
                Label {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    font.pixelSize: 11
                    color: clearArea.containsMouse ? Theme.violetBright : Theme.violet
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.clear()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Notifs.count ? Math.min(contentHeight, 340) : 0
                visible: Notifs.count > 0
                clip: true
                spacing: 8
                model: Notifs.history
                boundsBehavior: Flickable.StopAtBounds
                delegate: NotificationCard {
                    required property var modelData
                    width: ListView.view.width
                    notification: modelData
                    compact: true
                }
                add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.normal } }
                displaced: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                visible: Notifs.count === 0
                spacing: 4
                Glyph { Layout.fillWidth: true; text: "󰂜"; size: 26; color: Theme.dim }
                Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: "All caught up"; color: Theme.muted }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Devices.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Live device state, with the glyphs the bar and control center show for it.
Singleton {
    id: root

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null
    readonly property int volume: sink ? Math.round(sink.volume * 100) : 0
    readonly property bool muted: sink?.muted ?? true
    readonly property string volumeGlyph: muted ? "󰝟" : volume > 60 ? "󰕾" : volume > 25 ? "󰖀" : "󰕿"
    readonly property bool micMuted: source?.muted ?? true
    function setVolume(percent) {
        if (!sink)
            return;
        sink.muted = false;
        sink.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property string networkName: wifiNetwork ? wifiNetwork.name : wired ? "Wired" : "Offline"
    // Signal strength as 0–1, whichever scale the backend reports.
    function strength(network) {
        return network.signalStrength > 1 ? network.signalStrength / 100 : network.signalStrength;
    }
    function signalGlyph(network) {
        const s = strength(network);
        return s > 0.75 ? "󰤨" : s > 0.5 ? "󰤥" : s > 0.25 ? "󰤢" : "󰤟";
    }
    readonly property string networkGlyph: {
        if (wifiNetwork)
            return signalGlyph(wifiNetwork);
        return wired ? "󰈀" : Networking.wifiEnabled ? "󰤯" : "󰤭";
    }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property var bluetoothConnected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string bluetoothGlyph: !adapter ? "󰂲" : !bluetoothOn ? "󰂲" : bluetoothConnected.length ? "󰂱" : "󰂯"
    readonly property string bluetoothName: !adapter ? "No adapter" : !bluetoothOn ? "Off" : bluetoothConnected.length ? bluetoothConnected[0].name : "On"

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isPresent && battery.type === UPowerDeviceType.Battery
    readonly property int batteryPercent: !hasBattery ? 0 : Math.round(battery.percentage > 1 ? battery.percentage : battery.percentage * 100)
    readonly property bool charging: hasBattery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged || battery.state === UPowerDeviceState.PendingCharge)
    readonly property string batteryGlyph: charging ? "󰂄" : ["󰁺", "󰁼", "󰁾", "󰂀", "󰁹"][Math.min(4, Math.floor(batteryPercent / 20))]
    readonly property color batteryColor: charging ? Theme.green : batteryPercent <= 10 ? Theme.rose : batteryPercent <= 25 ? Theme.amber : Theme.textSoft
    readonly property string batteryDetail: {
        if (!hasBattery)
            return "";
        const seconds = charging ? battery.timeToFull : battery.timeToEmpty;
        if (!seconds)
            return charging ? "Charging" : "On battery";
        const h = Math.floor(seconds / 3600), m = Math.round(seconds % 3600 / 60);
        return `${h ? h + " h " : ""}${m} min ${charging ? "until full" : "left"}`;
    }
}
```

## `config/quickshell/nocturne/Glyph.qml`

```qml
import QtQuick

// A Nerd Font icon.
Text {
    property real size: 14
    color: Theme.textSoft
    font.family: Theme.mono
    font.pixelSize: size
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
```

## `config/quickshell/nocturne/Label.qml`

```qml
import QtQuick

Text {
    color: Theme.text
    font.family: Theme.sans
    font.pixelSize: 12
    font.features: { "tnum": 1 }
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    Behavior on color { ColorAnimation { duration: Theme.fast } }
}
```

## `config/quickshell/nocturne/NotificationCard.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// One notification: icon, app, summary, body and actions. Click runs the default action.
Rectangle {
    id: root

    required property var notification
    property bool compact: false
    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var actions: (notification?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property string iconSource: {
        const n = notification;
        if (!n)
            return "";
        if (n.image)
            return n.image;
        if (n.appIcon)
            return n.appIcon.startsWith("/") || n.appIcon.includes("://") ? n.appIcon : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    implicitHeight: layout.implicitHeight + 28
    radius: Theme.radius
    color: compact ? (area.containsMouse ? Theme.hover : Theme.raised) : Theme.glassStrong
    border.color: critical ? Theme.rose : compact ? Theme.line : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const n = root.notification;
            const action = n.actions.find(a => a.identifier === "default");
            if (action)
                action.invoke();
            n.dismiss();
        }
    }

    RowLayout {
        id: layout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource !== ""
                IconImage {
                    anchors.fill: parent
                    source: root.iconSource
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Theme.raised
                visible: root.iconSource === ""
                Glyph {
                    anchors.centerIn: parent
                    text: root.critical ? "󰀦" : "󰂚"
                    size: 17
                    color: root.critical ? Theme.rose : Theme.violetBright
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                Label {
                    Layout.fillWidth: true
                    text: root.notification?.appName || "Notification"
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    color: root.critical ? Theme.rose : Theme.violet
                }
                Glyph {
                    text: "󰅖"
                    size: 13
                    color: close.containsMouse ? Theme.text : Theme.dim
                    MouseArea {
                        id: close
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notification.dismiss()
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: root.notification?.summary ?? ""
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification?.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 4
                color: Theme.textSoft
                linkColor: Theme.violetBright
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 6
                visible: root.actions.length > 0
                spacing: 6
                Repeater {
                    model: root.actions
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: actionLabel.implicitWidth + 24
                        implicitHeight: 28
                        radius: 14
                        color: actionArea.containsMouse ? Theme.violet : Theme.raised
                        border.color: Theme.line
                        Label {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            font.pixelSize: 11
                            color: actionArea.containsMouse ? Theme.violetInk : Theme.text
                        }
                        MouseArea {
                            id: actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke();
                                root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
```

## `config/quickshell/nocturne/NotificationPopups.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland

// New notifications slide in at the top right, then retire to the control center.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 10 + Theme.gap; right: Theme.edge }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: Math.max(1, column.height)
    visible: Notifs.popups.length > 0 && !Ui.controlOpen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-popups"
    // Only the cards take input; the rest of the column passes clicks through.
    mask: Region { item: column }

    Column {
        id: column
        width: parent.width
        spacing: 8
        move: Transition { NumberAnimation { property: "y"; duration: Theme.normal; easing.type: Easing.OutCubic } }

        Repeater {
            model: Notifs.popups
            delegate: NotificationCard {
                id: card
                required property var modelData
                width: column.width
                notification: modelData
                opacity: 0
                x: 40
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: Theme.normal } }
                Behavior on x { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

                Timer {
                    interval: Notifs.timeout(card.modelData)
                    running: interval > 0 && !card.hoveredCard
                    onTriggered: Notifs.hidePopup(card.modelData)
                }
                readonly property bool hoveredCard: hover.hovered
                HoverHandler { id: hover }
            }
        }
    }
}
```

## `config/quickshell/nocturne/Notifs.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notification daemon: popups for new notifications, history for the control center.
Singleton {
    id: root

    property bool dnd: false
    property var popups: []
    // Newest first.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length

    function clear() {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
    }
    function hidePopup(n) {
        popups = popups.filter(p => p !== n);
    }
    // Milliseconds a popup stays up (expireTimeout is already in ms); critical ones wait for the user.
    function timeout(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        return n.expireTimeout > 0 ? Math.min(n.expireTimeout, 20000) : 6000;
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            n.closed.connect(() => root.hidePopup(n));
            if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                root.popups = [n, ...root.popups].slice(0, 4);
        }
    }
}
```

## `config/quickshell/nocturne/Osd.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Volume / microphone / brightness feedback, floating above the bottom edge.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors.bottom: true
    margins.bottom: 80
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 58
    visible: Ui.osdVisible || pill.opacity > 0
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-osd"

    readonly property string glyph: {
        if (Ui.osdKind === "brightness")
            return Ui.osdValue > 66 ? "󰃠" : Ui.osdValue > 33 ? "󰃟" : "󰃞";
        if (Ui.osdKind === "microphone")
            return Ui.osdMuted ? "󰍭" : "󰍬";
        return Ui.osdMuted ? "󰝟" : Ui.osdValue > 60 ? "󰕾" : Ui.osdValue > 25 ? "󰖀" : "󰕿";
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: Ui.osdVisible ? 1 : 0
        scale: Ui.osdVisible ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutBack } }

        RowLayout {
            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
            spacing: 14
            Glyph {
                text: root.glyph
                size: 19
                color: Ui.osdMuted ? Theme.dim : Theme.violetBright
                Layout.preferredWidth: 22
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Theme.raised
                Rectangle {
                    width: parent.width * (Ui.osdMuted ? 0 : Ui.osdValue / 100)
                    height: parent.height
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.violetDeep }
                        GradientStop { position: 1; color: Theme.violet }
                    }
                    Behavior on width { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                }
            }
            Label {
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
                text: Ui.osdMuted ? "Muted" : Ui.osdValue + "%"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.textSoft
            }
        }
    }
}
```

## `config/quickshell/nocturne/Panel.qml`

```qml
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A glass sheet that drops in under the bar and closes on Escape or a click outside.
PanelWindow {
    id: panel

    property bool open: false
    property int sheetWidth: 380
    default property alias content: sheet.data
    property alias sheet: sheet
    signal dismissed()

    screen: Ui.screen
    visible: open || sheet.opacity > 0
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: sheetWidth
    // A fixed-height surface; only the sheet takes input, so it can grow and shrink smoothly.
    implicitHeight: (screen?.height ?? 1080) - margins.top - Theme.edge
    mask: Region { item: sheet }
    margins.top: Theme.barHeight + 10 + Theme.gap
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nocturne-panel"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        windows: [panel]
        active: panel.open
        onCleared: panel.dismissed()
    }

    Rectangle {
        id: sheet
        width: parent.width
        // Content sits at x/y = 18; keep the same padding below it.
        implicitHeight: childrenRect.y + childrenRect.height + 18
        height: implicitHeight
        clip: true
        radius: Theme.radiusLarge
        color: Theme.glassStrong
        border.color: Theme.line
        opacity: panel.open ? 1 : 0
        y: panel.open ? 0 : -14
        focus: panel.open
        Keys.onEscapePressed: panel.dismissed()
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
    }
}
```

## `config/quickshell/nocturne/SessionMenu.qml`

```qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Full-screen session overlay. Destructive choices need a second press to confirm.
PanelWindow {
    id: root
    screen: Ui.screen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: Ui.sessionOpen || backdrop.opacity > 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nocturne-session"
    WlrLayershell.keyboardFocus: Ui.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var entries: [
        { glyph: "󰌾", label: "Lock", command: "loginctl lock-session" },
        { glyph: "󰤄", label: "Suspend", command: "systemctl suspend" },
        { glyph: "󰍃", label: "Log out", command: "hyprctl dispatch 'hl.dsp.exit()'", confirm: true },
        { glyph: "󰜉", label: "Restart", command: "systemctl reboot", confirm: true },
        { glyph: "󰐥", label: "Shut down", command: "systemctl poweroff", confirm: true }
    ]
    property int selected: 0
    property int armed: -1

    Connections {
        target: Ui
        function onSessionOpenChanged() {
            root.selected = 0;
            root.armed = -1;
        }
    }

    function choose(index) {
        const entry = entries[index];
        if (entry.confirm && armed !== index) {
            armed = index;
            selected = index;
            return;
        }
        Ui.sessionOpen = false;
        Ui.run(entry.command);
    }

    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(7 / 255, 7 / 255, 11 / 255, 0.62)
        opacity: Ui.sessionOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.normal } }

        focus: Ui.sessionOpen
        Keys.onEscapePressed: Ui.sessionOpen = false
        Keys.onLeftPressed: { root.selected = (root.selected + 4) % 5; root.armed = -1; }
        Keys.onRightPressed: { root.selected = (root.selected + 1) % 5; root.armed = -1; }
        Keys.onTabPressed: { root.selected = (root.selected + 1) % 5; root.armed = -1; }
        Keys.onReturnPressed: root.choose(root.selected)
        Keys.onEnterPressed: root.choose(root.selected)
        Keys.onSpacePressed: root.choose(root.selected)

        MouseArea {
            anchors.fill: parent
            onClicked: Ui.sessionOpen = false
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 26
            scale: Ui.sessionOpen ? 1 : 0.94
            Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "S E S S I O N"
                font.pixelSize: 12
                color: Theme.violet
            }

            RowLayout {
                spacing: 14
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool current: root.selected === index
                        readonly property bool isArmed: root.armed === index
                        implicitWidth: 132
                        implicitHeight: 140
                        radius: Theme.radiusLarge
                        color: isArmed ? Qt.rgba(239 / 255, 143 / 255, 164 / 255, 0.22) : current ? Theme.raised : Theme.glassStrong
                        border.width: current ? 2 : 1
                        border.color: isArmed ? Theme.rose : current ? Theme.violet : Theme.line
                        scale: current ? 1.04 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: Theme.fast } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Glyph {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.modelData.glyph
                                size: 34
                                color: tile.isArmed ? Theme.rose : tile.current ? Theme.violetBright : Theme.textSoft
                            }
                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                text: tile.isArmed ? "Confirm" : tile.modelData.label
                                font.pixelSize: 13
                                font.weight: tile.current ? Font.DemiBold : Font.Normal
                                color: tile.isArmed ? Theme.rose : Theme.text
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: if (root.armed !== tile.index) { root.selected = tile.index; root.armed = -1; }
                            onClicked: root.choose(tile.index)
                        }
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.armed >= 0 ? `Press again to ${root.entries[root.armed].label.toLowerCase()} · Esc to cancel` : "← → to choose · Enter to select · Esc to close"
                font.pixelSize: 11
                color: root.armed >= 0 ? Theme.rose : Theme.muted
            }
        }
    }
}
```

## `config/quickshell/nocturne/SliderRow.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Glyph button (mute) plus a soft violet slider, 0–100.
RowLayout {
    id: root

    property string glyph
    property real value: 0
    property bool muted: false
    signal moved(real value)
    signal glyphClicked()

    spacing: 10

    Rectangle {
        implicitWidth: 36
        implicitHeight: 36
        radius: 18
        color: button.containsMouse ? Theme.hover : Theme.raised
        Glyph {
            anchors.centerIn: parent
            text: root.glyph
            size: 16
            color: root.muted ? Theme.dim : Theme.violetBright
        }
        MouseArea {
            id: button
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.glyphClicked()
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: 0
        to: 100
        value: root.value
        onMoved: root.moved(value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 8
            radius: 4
            color: Theme.raised
            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: 4
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.violetDeep }
                    GradientStop { position: 1; color: root.muted ? Theme.dim : Theme.violet }
                }
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.pressed ? 18 : 16
            height: width
            radius: width / 2
            color: "#f3edff"
            border.color: Theme.violet
            border.width: 2
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    Label {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.value) + "%"
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.muted
    }
}
```

## `config/quickshell/nocturne/Sys.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Polled system state: CPU, memory, backlight and pending updates.
Singleton {
    id: root

    property int cpu: 0
    property int memory: 0
    property string memoryDetail: ""
    property int brightness: -1 // -1 when the machine has no backlight
    property int updates: 0
    property string updatesDetail: ""

    property var lastCpu: null

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4], total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? Math.round(100 * (1 - (idle - root.lastCpu.idle) / dt)) : 0;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = key => Number(text().match(new RegExp(key + ":\\s+(\\d+)"))[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memory = Math.round(100 * used / total);
            root.memoryDetail = `${(used / 1048576).toFixed(1)} / ${(total / 1048576).toFixed(1)} GiB`;
        }
    }

    // brightnessctl -m prints: device,class,current,percent%,max
    Process {
        id: backlight
        command: ["brightnessctl", "-m", "--class=backlight", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                root.brightness = parts.length >= 4 ? parseInt(parts[3]) : -1;
            }
        }
    }
    function refreshBrightness() {
        backlight.running = true;
    }
    function setBrightness(percent) {
        root.brightness = Math.max(1, Math.round(percent));
        brightnessDebounce.restart();
    }
    Timer {
        id: brightnessDebounce
        interval: 60
        onTriggered: Quickshell.execDetached(["brightnessctl", "--class=backlight", "--min-value=1", "set", root.brightness + "%"])
    }

    Process {
        id: updateCheck
        command: [Ui.bin + "nocturne-updates", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const status = JSON.parse(text);
                    root.updates = parseInt(status.text.replace(/\D/g, "")) || 0;
                    root.updatesDetail = status.tooltip.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">");
                } catch (e) {
                    root.updates = 0;
                }
            }
        }
    }
    function refreshUpdates() {
        updateCheck.running = true;
    }
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshUpdates()
    }
}
```

## `config/quickshell/nocturne/Theme.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell

// NOCTURNE palette, type and geometry, shared by every shell surface.
Singleton {
    readonly property color base: "#0d0a12"
    readonly property color surface: "#100d18"
    readonly property color glass: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.72)
    readonly property color glassStrong: Qt.rgba(16 / 255, 13 / 255, 24 / 255, 0.88)
    readonly property color raised: Qt.rgba(40 / 255, 30 / 255, 58 / 255, 0.55)
    readonly property color hover: "#38264f"
    readonly property color line: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16)
    readonly property color lineStrong: Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.34)
    readonly property color violet: "#b69af7"
    readonly property color violetBright: "#c4a5ff"
    readonly property color violetDeep: "#6d28d9"
    readonly property color violetInk: "#100b1b"
    readonly property color text: "#e9e1f5"
    readonly property color textSoft: "#c8bbde"
    readonly property color muted: "#8f809f"
    readonly property color dim: "#6c627b"
    readonly property color rose: "#ef8fa4"
    readonly property color green: "#a5ccb3"
    readonly property color amber: "#e5c89a"

    readonly property string sans: "Inter"
    readonly property string mono: "JetBrainsMono Nerd Font"

    readonly property int radiusLarge: 22
    readonly property int radius: 16
    readonly property int radiusSmall: 12
    readonly property int barHeight: 40
    readonly property int gap: 8
    readonly property int edge: 14

    readonly property int fast: 160
    readonly property int normal: 260
    readonly property int slow: 420
}
```

## `config/quickshell/nocturne/Tile.qml`

```qml
import QtQuick
import QtQuick.Layouts

// Quick-settings toggle: click the body to toggle, the chevron for more.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property bool on: false
    property bool available: true
    property bool hasMore: false
    signal toggled()
    signal more()

    implicitHeight: 62
    radius: Theme.radius
    color: on ? Theme.violet : body.containsMouse ? Theme.hover : Theme.raised
    border.color: on ? Theme.violetBright : Theme.line
    opacity: available ? 1 : 0.45
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: root.hasMore ? 6 : 14 }
        spacing: 11
        Glyph {
            text: root.glyph
            size: 19
            color: root.on ? Theme.violetInk : Theme.violetBright
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Label {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.DemiBold
                color: root.on ? Theme.violetInk : Theme.text
            }
            Label {
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: 11
                color: root.on ? Qt.rgba(16 / 255, 11 / 255, 27 / 255, 0.7) : Theme.muted
            }
        }
        Rectangle {
            visible: root.hasMore
            implicitWidth: 30
            implicitHeight: 44
            radius: Theme.radiusSmall
            color: more.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Glyph {
                anchors.centerIn: parent
                text: "󰅂"
                color: root.on ? Theme.violetInk : Theme.muted
            }
            MouseArea {
                id: more
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.available
                cursorShape: Qt.PointingHandCursor
                onClicked: root.more()
            }
        }
    }
}
```

## `config/quickshell/nocturne/Ui.qml`

```qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which surfaces are open, and the screen they open on.
Singleton {
    id: root

    property bool controlOpen: false
    property string controlPage: "main" // main, wifi or bluetooth
    property bool calendarOpen: false
    property bool sessionOpen: false
    property bool caffeine: false

    property string osdKind: "volume"
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdVisible: false

    // Panels follow the monitor that has focus.
    readonly property var screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    function close() {
        controlOpen = false;
        calendarOpen = false;
    }
    // A click outside a panel closes it; ignore that same click reopening it from the bar.
    property double closedAt: 0
    function dismiss() {
        closedAt = Date.now();
        close();
    }
    function toggleControl() {
        const reopen = !controlOpen && Date.now() - closedAt > 250;
        close();
        if (reopen)
            controlPage = "main";
        controlOpen = reopen;
    }
    function openControl(page) {
        close();
        controlPage = page;
        controlOpen = true;
    }
    function toggleCalendar() {
        const reopen = !calendarOpen && Date.now() - closedAt > 250;
        close();
        calendarOpen = reopen;
    }
    function openSession() {
        close();
        sessionOpen = true;
    }

    function showOsd(kind, value, muted) {
        osdKind = kind;
        osdValue = Math.max(0, Math.min(100, value));
        osdMuted = muted;
        osdVisible = true;
        osdTimer.restart();
    }
    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.osdVisible = false
    }

    function run(command) {
        Quickshell.execDetached(["bash", "-c", command]);
    }
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/"
}
```

## `config/quickshell/nocturne/BluetoothPage.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth

// Bluetooth devices: discover, pair, connect, disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var adapter: Devices.adapter
    readonly property bool powered: adapter?.enabled ?? false
    readonly property var all: Bluetooth.devices.values
    readonly property var paired: all.filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // Unnamed devices only advertise their address; leave them out.
    readonly property var available: all.filter(d => !d.paired && !d.bonded && d.deviceName && !/^([0-9A-F]{2}[:-]){5}[0-9A-F]{2}$/i.test(d.name))
        .sort((a, b) => a.name.localeCompare(b.name))
    property string expanded: ""
    property string pairingAddress: ""

    spacing: 12

    // Discover only while the page is on screen.
    function updateDiscovery() {
        if (adapter && adapter.enabled && adapter.discovering !== active)
            adapter.discovering = active;
    }
    onActiveChanged: { updateDiscovery(); if (!active) expanded = ""; }
    onPoweredChanged: updateDiscovery()

    function glyphFor(device) {
        const icon = device.icon ?? "";
        if (icon.includes("headset") || icon.includes("headphone"))
            return "󰋋";
        if (icon.includes("audio") || icon.includes("speaker"))
            return "󰓃";
        if (icon.includes("mouse"))
            return "󰍽";
        if (icon.includes("keyboard"))
            return "󰌌";
        if (icon.includes("gaming") || icon.includes("joystick"))
            return "󰊴";
        if (icon.includes("phone"))
            return "󰏲";
        if (icon.includes("computer"))
            return "󰌢";
        return "󰂯";
    }
    function statusFor(device) {
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (device.connected)
            return device.batteryAvailable ? `Connected · ${Math.round(device.battery > 1 ? device.battery : device.battery * 100)}% battery` : "Connected";
        return "Not connected";
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Bluetooth"
        status: !root.adapter ? "No adapter" : !root.powered ? "Off" : root.adapter.discovering ? "On · searching for devices" : "On"
        showSwitch: !!root.adapter
        checked: root.powered
        onBack: Ui.controlPage = "main"
        onToggled: root.adapter.enabled = !root.adapter.enabled
    }

    component SectionTitle: Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    Flickable {
        id: scroller
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 400)
        visible: root.powered
        contentHeight: sections.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: scroller.contentHeight > scroller.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        ColumnLayout {
            id: sections
            width: scroller.width
            spacing: 4

            SectionTitle { visible: root.paired.length > 0; text: "My devices" }
            Repeater {
                model: root.paired
                delegate: ListRow {
                    id: row
                    required property var modelData
                    readonly property var dev: modelData
                    readonly property bool changing: dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: root.statusFor(dev)
                    highlighted: dev.connected
                    busy: changing
                    expanded: root.expanded === dev.address
                    onClicked: {
                        const open = root.expanded === dev.address;
                        root.expanded = open ? "" : dev.address;
                        // One click connects; the row stays open for Disconnect and Forget.
                        if (!open && !dev.connected && !changing)
                            dev.connect();
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        PillButton {
                            text: row.dev.connected ? "Disconnect" : "Connect"
                            primary: !row.dev.connected
                            available: !row.changing
                            onClicked: row.dev.connected ? row.dev.disconnect() : row.dev.connect()
                        }
                        PillButton {
                            text: "Forget"
                            danger: true
                            onClicked: { root.expanded = ""; row.dev.forget(); }
                        }
                    }
                }
            }

            SectionTitle {
                Layout.topMargin: root.paired.length ? 10 : 2
                text: root.available.length ? "Available devices" : "Searching for devices…"
            }
            Repeater {
                model: root.available
                delegate: ListRow {
                    id: candidate
                    required property var modelData
                    readonly property var dev: modelData
                    Layout.fillWidth: true
                    glyph: root.glyphFor(dev)
                    title: dev.name
                    subtitle: dev.pairing ? "Pairing…" : "Click to pair"
                    busy: dev.pairing
                    onClicked: {
                        if (dev.pairing)
                            return;
                        root.pairingAddress = dev.address;
                        dev.pair();
                    }
                    // Trust and connect as soon as pairing completes.
                    Connections {
                        target: candidate.dev
                        function onPairedChanged() {
                            if (candidate.dev.paired && root.pairingAddress === candidate.dev.address) {
                                root.pairingAddress = "";
                                candidate.dev.trusted = true;
                                candidate.dev.connect();
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.powered
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰂲"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.adapter ? "This computer has no Bluetooth adapter" : "Bluetooth is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        visible: !!root.adapter
        text: "Advanced Bluetooth settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("blueman-manager"); }
        }
    }
}
```

## `config/quickshell/nocturne/ListRow.qml`

```qml
import QtQuick
import QtQuick.Layouts

// A device or network row; `expanded` reveals the extra content below it.
Rectangle {
    id: root

    property string glyph
    property string title
    property string subtitle
    property string trailing: "" // glyph on the right, e.g. a lock
    property bool highlighted: false
    property bool busy: false
    property bool expanded: false
    property bool danger: false
    default property alias extra: extraColumn.data
    signal clicked()

    implicitHeight: column.implicitHeight + 16
    radius: Theme.radiusSmall
    color: highlighted ? Qt.rgba(182 / 255, 154 / 255, 247 / 255, 0.16) : area.containsMouse || expanded ? Theme.raised : "transparent"
    border.color: highlighted ? Theme.lineStrong : expanded ? Theme.line : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.fast } }
    Behavior on implicitHeight { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    clip: true

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8; leftMargin: 10; rightMargin: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 11
            Glyph {
                Layout.preferredWidth: 22
                text: root.glyph
                size: 17
                color: root.highlighted ? Theme.violetBright : Theme.textSoft
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { Layout.fillWidth: true; text: root.title; font.weight: root.highlighted ? Font.DemiBold : Font.Normal }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.subtitle
                    font.pixelSize: 11
                    color: root.danger ? Theme.rose : root.highlighted ? Theme.violet : Theme.muted
                }
            }
            Glyph {
                visible: root.busy
                text: "󰔟"
                size: 14
                color: Theme.violet
                RotationAnimation on rotation { running: root.busy; from: 0; to: 360; duration: 1200; loops: Animation.Infinite }
            }
            Glyph {
                visible: root.trailing !== "" && !root.busy
                text: root.trailing
                size: 13
                color: Theme.dim
            }
        }

        ColumnLayout {
            id: extraColumn
            Layout.fillWidth: true
            Layout.leftMargin: 33
            visible: root.expanded
            spacing: 8
        }
    }
}
```

## `config/quickshell/nocturne/PageHeader.qml`

```qml
import QtQuick
import QtQuick.Layouts

// Back arrow, title, optional status text and an on/off switch.
RowLayout {
    id: root

    property string title
    property string status
    property bool checked: false
    property bool showSwitch: true
    signal back()
    signal toggled()

    spacing: 10

    Rectangle {
        implicitWidth: 34
        implicitHeight: 34
        radius: 17
        color: backArea.containsMouse ? Theme.hover : Theme.raised
        border.color: Theme.line
        Glyph { anchors.centerIn: parent; text: "󰁍"; size: 15; color: Theme.textSoft }
        MouseArea {
            id: backArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.back()
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        // fillWidth on the labels lets the column (and so the row) stretch to the switch.
        Label { Layout.fillWidth: true; text: root.title; font.pixelSize: 15; font.weight: Font.DemiBold }
        Label { Layout.fillWidth: true; visible: text !== ""; text: root.status; font.pixelSize: 11; color: Theme.muted }
    }
    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: root.toggled()
    }
}
```

## `config/quickshell/nocturne/PillButton.qml`

```qml
import QtQuick

// Small text button used inside expanded rows.
Rectangle {
    id: root

    property string text
    property bool primary: false
    property bool danger: false
    property bool available: true
    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30
    radius: 15
    opacity: available ? 1 : 0.45
    color: primary ? (area.containsMouse ? Theme.violetBright : Theme.violet) : area.containsMouse ? Theme.hover : Theme.raised
    border.color: danger ? Qt.rgba(239 / 255, 143 / 255, 164 / 255, 0.5) : primary ? Theme.violetBright : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.primary ? Theme.violetInk : root.danger ? Theme.rose : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
```

## `config/quickshell/nocturne/Switch.qml`

```qml
import QtQuick

// Pill switch.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 44
    implicitHeight: 24
    radius: 12
    color: checked ? Theme.violet : Theme.raised
    border.color: checked ? Theme.violetBright : Theme.lineStrong
    Behavior on color { ColorAnimation { duration: Theme.fast } }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.violetInk : Theme.textSoft
        Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
```

## `config/quickshell/nocturne/WifiPage.qml`

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking

// Wi-Fi networks: scan, connect (with a password when needed), disconnect and forget.
ColumnLayout {
    id: root

    property bool active: false
    readonly property var device: Devices.wifiDevice
    readonly property var networks: (device?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (Devices.strength(b) - Devices.strength(a)))
    property string expanded: ""
    property var failures: ({}) // network name → message

    spacing: 12

    // Scan only while the page is on screen.
    function updateScanner() {
        if (device)
            device.scannerEnabled = active && Networking.wifiEnabled;
    }
    onActiveChanged: { updateScanner(); if (!active) expanded = ""; }
    onDeviceChanged: updateScanner()
    Connections {
        target: Networking
        function onWifiEnabledChanged() { root.updateScanner(); }
    }

    function fail(name, message) {
        failures = Object.assign({}, failures, { [name]: message });
    }
    function clearFailure(name) {
        const next = Object.assign({}, failures);
        delete next[name];
        failures = next;
    }

    PageHeader {
        Layout.fillWidth: true
        title: "Wi-Fi"
        status: !root.device ? "No Wi-Fi adapter" : !Networking.wifiEnabled ? "Off" : Devices.wifiNetwork ? `Connected to ${Devices.wifiNetwork.name}` : "Not connected"
        showSwitch: !!root.device
        checked: Networking.wifiEnabled
        onBack: Ui.controlPage = "main"
        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    }

    // Wired connection, while a cable is plugged in.
    ListRow {
        Layout.fillWidth: true
        visible: Devices.wired
        glyph: "󰈀"
        title: "Ethernet"
        subtitle: "Connected"
        highlighted: true
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: 2
        visible: !!root.device && Networking.wifiEnabled
        text: root.networks.length ? "Networks" : "Searching for networks…"
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        color: Theme.muted
    }

    ListView {
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: !!root.device && Networking.wifiEnabled
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.networks
        ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

        delegate: ListRow {
            id: row
            required property var modelData
            readonly property var net: modelData
            readonly property bool secured: net.security !== WifiSecurityType.Open
            readonly property bool connecting: net.stateChanging || net.state === ConnectionState.Connecting
            readonly property string failure: root.failures[net.name] ?? ""

            width: ListView.view.width
            glyph: Devices.signalGlyph(net)
            title: net.name
            subtitle: failure !== "" ? failure : net.connected ? "Connected" : connecting ? "Connecting…" : net.known ? "Saved" : secured ? "Secured" : "Open"
            danger: failure !== ""
            trailing: secured ? "󰌾" : ""
            highlighted: net.connected
            busy: connecting
            expanded: root.expanded === net.name

            function connect() {
                root.clearFailure(net.name);
                if (net.known || !secured)
                    net.connect();
                else if (password.text !== "")
                    net.connectWithPsk(password.text);
            }

            onClicked: {
                const open = root.expanded === net.name;
                root.expanded = open ? "" : net.name;
                // Saved and open networks connect straight away; the row stays open for Forget.
                if (!open && !net.connected && (net.known || !secured))
                    connect();
                if (!open && !net.known && secured)
                    password.forceActiveFocus();
            }

            Connections {
                target: row.net
                function onConnectionFailed(reason) {
                    const wrongKey = reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed;
                    root.fail(row.net.name, wrongKey ? "Wrong password, or the network refused the connection" : "Couldn't connect");
                    root.expanded = row.net.name;
                }
                function onConnectedChanged() {
                    if (row.net.connected) {
                        root.clearFailure(row.net.name);
                        password.text = "";
                    }
                }
            }

            // Password entry for new secured networks.
            RowLayout {
                Layout.fillWidth: true
                visible: !row.net.known && row.secured
                spacing: 8
                TextField {
                    id: password
                    Layout.fillWidth: true
                    placeholderText: "Password"
                    echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
                    color: Theme.text
                    placeholderTextColor: Theme.dim
                    selectionColor: Theme.violet
                    selectedTextColor: Theme.violetInk
                    font.family: Theme.sans
                    font.pixelSize: 12
                    leftPadding: 12
                    rightPadding: 34
                    background: Rectangle {
                        implicitHeight: 32
                        radius: 10
                        color: Theme.glassStrong
                        border.color: password.activeFocus ? Theme.violet : Theme.lineStrong
                    }
                    onAccepted: row.connect()
                    Glyph {
                        id: reveal
                        property bool checked: false
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        text: checked ? "󰈈" : "󰈉"
                        size: 14
                        color: Theme.muted
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: reveal.checked = !reveal.checked
                        }
                    }
                }
                PillButton {
                    text: "Connect"
                    primary: true
                    available: password.text !== "" && !row.connecting
                    onClicked: row.connect()
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: row.net.known || row.net.connected || !row.secured
                spacing: 6
                PillButton {
                    visible: !row.net.connected
                    text: row.connecting ? "Connecting…" : "Connect"
                    primary: true
                    available: !row.connecting
                    onClicked: row.connect()
                }
                PillButton {
                    visible: row.net.connected
                    text: "Disconnect"
                    onClicked: row.net.disconnect()
                }
                PillButton {
                    visible: row.net.known
                    text: "Forget"
                    danger: true
                    onClicked: { row.net.forget(); root.expanded = ""; }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        visible: !root.device || !Networking.wifiEnabled
        spacing: 4
        Glyph { Layout.fillWidth: true; text: "󰤭"; size: 28; color: Theme.dim }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: !root.device ? "This computer has no Wi-Fi adapter" : "Wi-Fi is off"
            color: Theme.muted
        }
    }

    Label {
        Layout.alignment: Qt.AlignRight
        text: "Advanced network settings"
        font.pixelSize: 11
        color: advancedArea.containsMouse ? Theme.violetBright : Theme.muted
        MouseArea {
            id: advancedArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Ui.close(); Ui.run("nm-connection-editor"); }
        }
    }
}
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
* { bg: #100d18c4; fg: #e9e1f5; muted: #8f809f; violet: #b69af7; selection: #2e2342b3;
 background-color: transparent; text-color: @fg; border-color: #b69af733; }
window { width: 640px; padding: 26px; border: 1px; border-radius: 22px; background-color: @bg; }
mainbox { spacing: 22px; children: [ inputbar, listview, mode-switcher ]; }
inputbar { padding: 16px; border-radius: 12px; background-color: #1c152899; spacing: 14px; children: [ prompt, entry ]; }
prompt { text-color: @violet; font: "Inter Bold 11"; vertical-align: 0.5; }
entry { placeholder: "Search your applications…"; placeholder-color: @muted; }
listview { lines: 6; columns: 1; spacing: 5px; fixed-height: true; }
element { padding: 12px; border-radius: 10px; spacing: 14px; }
element selected.normal { background-color: @selection; text-color: @violet; }
element-icon { size: 28px; }
element-text { vertical-align: 0.5; text-color: inherit; }
mode-switcher { spacing: 10px; }
button { padding: 8px; border-radius: 8px; text-color: @muted; font: "Inter 10"; }
button selected { text-color: @violet; background-color: #20172e99; }
message { padding: 10px; }
```

## `config/satty/config.toml`

```toml
# NOCTURNE — screenshot annotation (Shift+Print)
[general]
initial-tool = "arrow"
copy-command = "wl-copy"
annotation-size-factor = 1.5
corner-roundness = 12
early-exit = ["copy", "save"]
actions-on-enter = ["save-to-clipboard", "save-to-file"]
actions-on-escape = ["exit"]
primary-highlighter = "block"
default-round-caps = true
no-window-decoration = true
notification-thumbnail = "screenshot"

[font]
family = "Inter"
style = "Bold"

[color-palette]
palette = [
    "#b69af7ff",
    "#ef8fa4ff",
    "#a5ccb3ff",
    "#e5c89aff",
    "#9ccbd2ff",
    "#faf5ffff",
]
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
Comment=Soft lavender cursors with midnight outlines and a violet ring spinner
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
<g id="wordmark">
<path d="M150 1330h56" stroke="#ad83e2" stroke-width="2"/>
<text x="150" y="1380" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#b8a4cf">NOCTURNE</text>
<text x="150" y="1414" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#635570">A QUIETER ORBIT.</text>
</g>
</svg>
```

## `assets/wallpaper-dawn.svg`

```xml
<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="1600" viewBox="0 0 2560 1600">
<defs>
 <radialGradient id="bg" cx="30%" cy="68%" r="78%"><stop stop-color="#2c1232"/><stop offset=".42" stop-color="#130b1c"/><stop offset="1" stop-color="#07070b"/></radialGradient>
 <linearGradient id="ring" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#1d102a"/><stop offset=".25" stop-color="#8a3f9e"/><stop offset=".5" stop-color="#f3b4d6"/><stop offset=".72" stop-color="#9b6fe6"/><stop offset="1" stop-color="#1d102a"/></linearGradient>
 <linearGradient id="dawn" x1=".73" y1=".95" x2=".5" y2=".5"><stop stop-color="#ffd0e4"/><stop offset=".3" stop-color="#e48ac0" stop-opacity=".9"/><stop offset=".62" stop-color="#7c3cc7" stop-opacity="0"/></linearGradient>
 <radialGradient id="planet" cx="28%" cy="22%" r="80%"><stop stop-color="#3d1d4a"/><stop offset=".32" stop-color="#1a0f26"/><stop offset=".78" stop-color="#09080e"/><stop offset="1" stop-color="#08070c"/></radialGradient>
 <radialGradient id="moon" cx="30%" cy="30%" r="80%"><stop stop-color="#5a3d74"/><stop offset=".6" stop-color="#1c1328"/><stop offset="1" stop-color="#0d0a12"/></radialGradient>
 <clipPath id="front"><rect x="-900" y="0" width="1800" height="400"/></clipPath>
 <filter id="glow"><feGaussianBlur stdDeviation="16"/></filter>
 <filter id="soft"><feGaussianBlur stdDeviation="70"/></filter>
</defs>
<rect width="2560" height="1600" fill="url(#bg)"/>
<ellipse cx="760" cy="900" rx="640" ry="520" fill="#b04a8f" opacity=".11" filter="url(#soft)"/>
<ellipse cx="560" cy="700" rx="320" ry="260" fill="#f3a6cf" opacity=".07" filter="url(#soft)"/>
<g fill="#e9c8f2"><circle cx="1620" cy="300" r="2.5" opacity=".55"/><circle cx="2140" cy="760" r="2" opacity=".4"/><circle cx="1880" cy="1180" r="1.5" opacity=".35"/><circle cx="1290" cy="520" r="1.5" opacity=".3"/><circle cx="2380" cy="380" r="2" opacity=".45"/><circle cx="1500" cy="1420" r="1.5" opacity=".25"/></g>
<circle cx="1980" cy="430" r="28" fill="url(#moon)" stroke="#4a3260" stroke-width="1"/>
<g transform="translate(820 1010) rotate(16)">
 <ellipse rx="880" ry="230" fill="none" stroke="#8e5bc4" stroke-width="1" opacity=".12"/>
 <ellipse rx="760" ry="172" fill="none" stroke="#e48ac0" stroke-width="10" filter="url(#glow)" opacity=".35"/>
 <ellipse rx="760" ry="172" fill="none" stroke="url(#ring)" stroke-width="3"/>
</g>
<circle cx="820" cy="1010" r="430" fill="url(#planet)" stroke="#33203f" stroke-width="1"/>
<circle cx="820" cy="1010" r="430" fill="none" stroke="url(#dawn)" stroke-width="16" stroke-dasharray="950 1752" transform="rotate(162 820 1010)" filter="url(#glow)" opacity=".45"/>
<circle cx="820" cy="1010" r="429" fill="none" stroke="url(#dawn)" stroke-width="3" stroke-linecap="round" stroke-dasharray="950 1752" transform="rotate(162 820 1010)"/>
<g transform="translate(820 1010) rotate(16)" clip-path="url(#front)">
 <ellipse rx="760" ry="172" fill="none" stroke="#e48ac0" stroke-width="10" filter="url(#glow)" opacity=".35"/>
 <ellipse rx="760" ry="172" fill="none" stroke="url(#ring)" stroke-width="3"/>
 <ellipse rx="772" ry="182" fill="none" stroke="url(#ring)" stroke-width="1" opacity=".4"/>
</g>
<g id="wordmark">
<path d="M2354 1330h56" stroke="#e48ac0" stroke-width="2"/>
<text x="2410" y="1380" text-anchor="end" font-family="Inter, sans-serif" font-size="20" letter-spacing="9" fill="#d6b4d8">NOCTURNE</text>
<text x="2410" y="1414" text-anchor="end" font-family="Inter, sans-serif" font-size="12" letter-spacing="3" fill="#6d5574">BEFORE THE LIGHT.</text>
</g>
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
</svg>
```

## `bin/nocturne-osd`

```python
#!/usr/bin/env python3
"""Adjust desktop controls and show a single, replacing Nocturne popup."""
import fcntl
import os
from pathlib import Path
import subprocess
import sys


def run(*args):
    return subprocess.check_output(args, text=True, env={**os.environ, 'LC_ALL': 'C'}).strip()


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ('volume', 'microphone', 'brightness') or sys.argv[2] not in ('up', 'down', 'mute', 'show'):
        sys.exit('Usage: nocturne-osd volume|microphone|brightness up|down|mute|show')
    control, action = sys.argv[1:]
    if control == 'brightness' and action == 'mute':
        sys.exit('Brightness cannot be muted')
    directory = Path(os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')) / 'nocturne'
    directory.mkdir(parents=True, exist_ok=True)
    # Serialize repeat events so the last popup always reflects the latest value.
    with (directory / 'osd.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        muted = False
        if control == 'brightness':
            if action != 'show':
                run('brightnessctl', '--class=backlight', '--min-value=1', 'set', '+5%' if action == 'up' else '5%-')
            current = int(run('brightnessctl', '--class=backlight', 'get'))
            maximum = int(run('brightnessctl', '--class=backlight', 'max'))
            value = round(current * 100 / maximum)
            title = f'Brightness · {value}%'
        else:
            device = '@DEFAULT_AUDIO_SOURCE@' if control == 'microphone' else '@DEFAULT_AUDIO_SINK@'
            if action == 'mute':
                run('wpctl', 'set-mute', device, 'toggle')
            elif action != 'show':
                run('wpctl', 'set-volume', '-l', '1', device, '5%+' if action == 'up' else '5%-')
            status = run('wpctl', 'get-volume', device)
            value = round(float(status.split()[1]) * 100)
            label = 'Microphone' if control == 'microphone' else 'Volume'
            muted = '[MUTED]' in status
            title = f'{label} · Muted' if muted else f'{label} · {value}%'
        value = min(100, max(0, value))
        # The Nocturne shell draws the popup; fall back to a plain notification without it.
        try:
            shown = subprocess.run(['quickshell', '-c', 'nocturne', 'ipc', 'call', 'osd', 'flash',
                                    control, str(value), 'true' if muted else 'false'],
                                   capture_output=True).returncode == 0
        except OSError:
            shown = False
        if not shown:
            run('notify-send', '--app-name=Nocturne OSD', '--urgency=low', '--expire-time=1500',
                '--hint=int:value:' + str(0 if muted else value),
                '--hint=string:x-canonical-private-synchronous:nocturne-osd', title)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f'nocturne-osd: {error}')
```


## Neovim workspace

The editor-only installer backs up an existing configuration and restores the locked plugin versions. See README.md for usage and language-server setup.

### `tools/install-neovim.sh`

```bash
#!/usr/bin/env bash
# Install only the Neovim configuration; no desktop or system changes.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v nvim >/dev/null
command -v git >/dev/null
config_root=${XDG_CONFIG_HOME:-$HOME/.config}
state_root=${XDG_STATE_HOME:-$HOME/.local/state}
destination="$config_root/nvim"
backup=$(mktemp -d "$state_root/nocturne/backups/neovim-XXXXXXXX" 2>/dev/null) || {
    mkdir -p "$state_root/nocturne/backups"
    backup=$(mktemp -d "$state_root/nocturne/backups/neovim-XXXXXXXX")
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
```

### `config/nvim/colors/nocturne.lua`

```lua
-- Original Nocturne palette, shared with the desktop.
vim.cmd('highlight clear')
if vim.g.syntax_on then vim.cmd('syntax reset') end
vim.o.background = 'dark'
vim.g.colors_name = 'nocturne'
local c = { bg = '#0d0a12', panel = '#100d18', raised = '#1b1526', border = '#352a46',
  violet = '#b69af7', fg = '#e4dced', muted = '#8f809f', green = '#a6d4bc',
  rose = '#ed9cad', gold = '#e5c49a', blue = '#a3c5e9', pink = '#d5a4dc' }
local groups = {
  Normal = { fg = c.fg, bg = c.bg }, NormalNC = { fg = c.fg, bg = c.bg },
  NormalFloat = { fg = c.fg, bg = c.panel }, FloatBorder = { fg = c.violet, bg = c.panel },
  FloatTitle = { fg = c.violet, bg = c.panel, bold = true },
  CursorLine = { bg = c.raised }, CursorLineNr = { fg = c.violet, bold = true },
  LineNr = { fg = c.muted }, SignColumn = { bg = c.bg }, EndOfBuffer = { fg = c.border },
  WinSeparator = { fg = c.border }, Visual = { bg = '#3d2d54' },
  Search = { fg = c.bg, bg = c.gold }, IncSearch = { fg = c.bg, bg = c.violet },
  Pmenu = { fg = c.fg, bg = c.panel }, PmenuSel = { fg = c.bg, bg = c.violet },
  PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.muted },
  StatusLine = { fg = c.fg, bg = c.panel }, StatusLineNC = { fg = c.muted, bg = c.panel },
  TabLine = { fg = c.muted, bg = c.panel }, TabLineSel = { fg = c.violet, bg = c.raised, bold = true },
  TabLineFill = { bg = c.panel }, Directory = { fg = c.violet },
  Title = { fg = c.violet, bold = true }, Comment = { fg = c.muted, italic = true },
  Constant = { fg = c.gold }, String = { fg = c.green }, Character = { fg = c.green },
  Number = { fg = c.gold }, Boolean = { fg = c.gold }, Float = { fg = c.gold },
  Identifier = { fg = c.fg }, Function = { fg = c.blue }, Statement = { fg = c.violet },
  Keyword = { fg = c.violet }, Operator = { fg = c.pink }, PreProc = { fg = c.pink },
  Type = { fg = c.gold }, Special = { fg = c.pink }, Delimiter = { fg = c.muted },
  Underlined = { fg = c.blue, underline = true }, Todo = { fg = c.gold, bold = true },
  Error = { fg = c.rose }, ErrorMsg = { fg = c.rose }, WarningMsg = { fg = c.gold },
  MatchParen = { fg = c.violet, bg = c.border, bold = true }, NonText = { fg = c.border },
  Folded = { fg = c.muted, bg = c.panel }, FoldColumn = { fg = c.muted },
  DiffAdd = { bg = '#1c3029' }, DiffDelete = { bg = '#38202d' },
  DiffChange = { bg = '#27243f' }, DiffText = { bg = '#403457' },
  GitSignsAdd = { fg = c.green }, GitSignsChange = { fg = c.violet }, GitSignsDelete = { fg = c.rose },
  DiagnosticError = { fg = c.rose }, DiagnosticWarn = { fg = c.gold },
  DiagnosticInfo = { fg = c.blue }, DiagnosticHint = { fg = c.violet },
  NvimTreeNormal = { fg = c.fg, bg = c.panel }, NvimTreeNormalNC = { fg = c.fg, bg = c.panel },
  NvimTreeEndOfBuffer = { fg = c.panel, bg = c.panel },
  NvimTreeRootFolder = { fg = c.violet, bold = true }, NvimTreeFolderName = { fg = c.violet },
  NvimTreeOpenedFolderName = { fg = c.pink, bold = true }, NvimTreeFolderIcon = { fg = c.violet },
  TelescopeBorder = { fg = c.border }, TelescopeSelection = { bg = c.raised },
  TelescopeMatching = { fg = c.violet, bold = true },
  WhichKey = { fg = c.violet }, WhichKeyGroup = { fg = c.blue }, WhichKeyDesc = { fg = c.fg },
}
for name, value in pairs(groups) do vim.api.nvim_set_hl(0, name, value) end
for _, severity in ipairs({ 'Error', 'Warn', 'Info', 'Hint' }) do
  vim.api.nvim_set_hl(0, 'DiagnosticUnderline' .. severity, { sp = groups['Diagnostic' .. severity].fg, undercurl = true })
end
local terminal = { c.panel, c.rose, c.green, c.gold, c.violet, c.pink, c.blue, c.fg,
  c.muted, '#f5b4c1', '#bce6ce', '#f2d7b3', '#cbb4ff', '#e6bce9', '#bddbf5', '#f7f0ff' }
for i, color in ipairs(terminal) do vim.g['terminal_color_' .. (i - 1)] = color end
```

### `config/nvim/init.lua`

```lua
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.mouse = 'a'
o.clipboard = 'unnamedplus'
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.signcolumn = 'yes'
o.cursorline = true
o.wrap = false
o.scrolloff = 6
o.splitright = true
o.splitbelow = true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 400
o.completeopt = { 'menu', 'menuone', 'noselect' }
o.laststatus = 3
vim.cmd.colorscheme('nocturne')
local path = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(path) then
  local result = vim.fn.system({ 'git', 'clone', '--filter=blob:none', '--branch=stable',
    'https://github.com/folke/lazy.nvim.git', path })
  if vim.v.shell_error ~= 0 then
    vim.notify('Plugin download failed. Check your connection and restart Neovim.\n' .. result, vim.log.levels.ERROR)
    return
  end
end
vim.opt.rtp:prepend(path)
require('lazy').setup('nocturne.plugins', {
  change_detection = { notify = false },
  checker = { enabled = false },
  local_spec = false,
  ui = { border = 'rounded' },
})
require('nocturne.keys')
vim.diagnostic.config({ virtual_text = false, float = { border = 'rounded' }, severity_sort = true })
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() > 1 then return end
    local arg = vim.fn.argv(0)
    if vim.fn.argc() == 0 or vim.fn.isdirectory(arg) == 1 then
      if vim.fn.isdirectory(arg) == 1 then vim.cmd.cd(vim.fn.fnameescape(arg)) end
      require('nvim-tree.api').tree.open()
    end
  end,
})
```

### `config/nvim/lazy-lock.json`

```json
{
  "bufferline.nvim": { "branch": "main", "commit": "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3" },
  "gitsigns.nvim": { "branch": "main", "commit": "683137003522aebd6948358334164a6ba2ca7cd5" },
  "lazy.nvim": { "branch": "main", "commit": "85c7ff3711b730b4030d03144f6db6375044ae82" },
  "lualine.nvim": { "branch": "master", "commit": "221ce6b2d999187044529f49da6554a92f740a96" },
  "mason.nvim": { "branch": "main", "commit": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d" },
  "nvim-autopairs": { "branch": "master", "commit": "3172f40c16563db871a58f20d205c710ad782311" },
  "nvim-lspconfig": { "branch": "master", "commit": "77b7432d4770d23b277d37923e5a08a442d8bb07" },
  "nvim-tree.lua": { "branch": "master", "commit": "9a2e0006d42f292eb3ade7dfdff201a7429a780c" },
  "nvim-web-devicons": { "branch": "master", "commit": "ec309a0eaff6ea967e58c275996155ab5c16938d" },
  "plenary.nvim": { "branch": "master", "commit": "74b06c6c75e4eeb3108ec01852001636d85a932b" },
  "telescope.nvim": { "branch": "master", "commit": "40aedd8a68c78a656a10a8d62d80c54af59420fb" },
  "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" }
}
```

### `config/nvim/lua/nocturne/keys.lua`

```lua
local function map(key, action, desc, mode)
  vim.keymap.set(mode or 'n', key, action, { silent = true, desc = desc })
end
local function find(name)
  return function() require('telescope.builtin')[name]() end
end
map('<leader>e', '<cmd>NvimTreeToggle<cr>', 'Toggle file tree')
map('<leader>o', '<cmd>NvimTreeFindFile<cr>', 'Reveal current file')
map('<leader><space>', find('find_files'), 'Find project file')
map('<C-p>', find('find_files'), 'Find project file')
map('<leader>ff', find('find_files'), 'Find files')
map('<leader>fg', find('live_grep'), 'Search project text')
map('<leader>fr', find('oldfiles'), 'Recent files')
map('<leader>fb', find('buffers'), 'Open buffers')
map('<leader>fh', find('help_tags'), 'Search help')
map('<S-l>', '<cmd>bnext<cr>', 'Next file')
map('<S-h>', '<cmd>bprevious<cr>', 'Previous file')
map('<leader>bn', '<cmd>bnext<cr>', 'Next file')
map('<leader>bp', '<cmd>bprevious<cr>', 'Previous file')
map('<leader>bd', '<cmd>bdelete<cr>', 'Close file (protect unsaved changes)')
map('<leader>s', '<cmd>write<cr>', 'Save file')
map('<C-s>', '<cmd>write<cr>', 'Save file', { 'n', 'i' })
map('<leader>q', '<cmd>confirm qall<cr>', 'Quit (ask about unsaved files)')
map('<Esc>', '<cmd>nohlsearch<cr>', 'Clear search highlight')
map('<leader>?', function() require('which-key').show({ global = true }) end, 'Show shortcuts')
map('<leader>wl', '<C-w>l', 'Focus right window')
map('<leader>wh', '<C-w>h', 'Focus left window')
map('<leader>wj', '<C-w>j', 'Focus lower window')
map('<leader>wk', '<C-w>k', 'Focus upper window')
map('<leader>wv', '<cmd>vsplit<cr>', 'Split vertically')
map('<leader>ws', '<cmd>split<cr>', 'Split horizontally')
map('<leader>gg', find('git_status'), 'Git changed files')
map('<leader>gp', function() require('gitsigns').preview_hunk() end, 'Preview Git change')
map('<leader>cm', '<cmd>Mason<cr>', 'Install language tools')
map('<leader>cd', vim.diagnostic.open_float, 'Line diagnostics')
map('<leader>cl', find('diagnostics'), 'Project diagnostics')
map('<leader>cr', vim.lsp.buf.rename, 'Rename symbol')
map('<leader>ca', vim.lsp.buf.code_action, 'Code action')
map('<leader>cf', function() vim.lsp.buf.format({ async = true }) end, 'Format with language server')
map('gd', vim.lsp.buf.definition, 'Go to definition')
map('grr', vim.lsp.buf.references, 'Find references')
map('K', vim.lsp.buf.hover, 'Documentation')
map('<leader>t', '<cmd>botright 12split | terminal<cr>', 'Open terminal')
map('<Esc><Esc>', '<C-\\><C-n>', 'Leave terminal mode', 't')
map('<leader>p', '<cmd>Lazy<cr>', 'Manage plugins')
```

### `config/nvim/lua/nocturne/plugins.lua`

```lua
return {
  { 'nvim-tree/nvim-web-devicons', opts = {} },
  { 'nvim-tree/nvim-tree.lua', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    view = { width = 32, side = 'left' },
    renderer = { group_empty = true, highlight_git = 'name' },
    update_focused_file = { enable = true },
    filters = { dotfiles = false, custom = { '^.git$' } },
    actions = { open_file = { quit_on_open = false } },
  } },
  { 'folke/which-key.nvim', opts = { preset = 'modern', delay = 350, spec = {
    { '<leader>f', group = 'Find' }, { '<leader>b', group = 'Buffers' },
    { '<leader>c', group = 'Code' }, { '<leader>g', group = 'Git' },
    { '<leader>w', group = 'Windows' },
  } } },
  { 'nvim-telescope/telescope.nvim', dependencies = { 'nvim-lua/plenary.nvim' }, opts = {
    defaults = { sorting_strategy = 'ascending', layout_config = { prompt_position = 'top' },
      file_ignore_patterns = { 'node_modules/', '%.git/' } },
    pickers = { find_files = { hidden = true } },
  } },
  { 'akinsho/bufferline.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' }, opts = {
    options = { diagnostics = 'nvim_lsp', separator_style = 'thin',
      offsets = { { filetype = 'NvimTree', text = 'NOCTURNE · Files', text_align = 'center' } } },
  } },
  { 'nvim-lualine/lualine.nvim', opts = {
    options = { theme = {
      normal = { a = { fg = '#0d0a12', bg = '#b69af7', gui = 'bold' }, b = { fg = '#e4dced', bg = '#292035' }, c = { fg = '#8f809f', bg = '#100d18' } },
      insert = { a = { fg = '#0d0a12', bg = '#a6d4bc' } },
      visual = { a = { fg = '#0d0a12', bg = '#d5a4dc' } },
      replace = { a = { fg = '#0d0a12', bg = '#ed9cad' } },
      inactive = { a = { fg = '#8f809f', bg = '#100d18' }, b = { fg = '#8f809f', bg = '#100d18' }, c = { fg = '#8f809f', bg = '#100d18' } },
    }, globalstatus = true },
  } },
  { 'lewis6991/gitsigns.nvim', opts = {} },
  { 'windwp/nvim-autopairs', opts = {} },
  { 'mason-org/mason.nvim', opts = { ui = { border = 'rounded' } } },
  { 'neovim/nvim-lspconfig', dependencies = { 'mason-org/mason.nvim' }, config = function()
    -- Enable only installed servers; Mason adds its executables to PATH.
    local servers = {
      lua_ls = 'lua-language-server', pyright = 'pyright-langserver',
      ts_ls = 'typescript-language-server', bashls = 'bash-language-server',
      clangd = 'clangd', rust_analyzer = 'rust-analyzer', gopls = 'gopls',
    }
    vim.lsp.config('lua_ls', { settings = { Lua = { diagnostics = { globals = { 'vim' } } } } })
    for server, executable in pairs(servers) do
      if vim.fn.executable(executable) == 1 then vim.lsp.enable(server) end
    end
    vim.api.nvim_create_autocmd('LspAttach', { callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if client and client:supports_method('textDocument/completion') then
        vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
      end
    end })
  end },
}
```

