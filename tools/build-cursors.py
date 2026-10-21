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
