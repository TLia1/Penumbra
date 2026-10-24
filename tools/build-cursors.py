#!/usr/bin/env python3
"""Build original SVG cursor artwork into a complete multi-size Xcursor theme.
Requires Python 3, librsvg (rsvg-convert), and xorg-xcursorgen.
Run from any directory. No downloaded cursor artwork is used.
"""
from pathlib import Path
import math, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/cursors'
THEME=ROOT/'system/usr/share/icons/Penumbra-Cursors'
for stale in ASSETS.glob('*.svg'):stale.unlink()
shutil.rmtree(THEME/'cursors',ignore_errors=True)
ASSETS.mkdir(parents=True,exist_ok=True)
(THEME/'cursors').mkdir(parents=True,exist_ok=True)
# Palette: midnight outline, moonlit lavender body, Penumbra violet accents.
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
with tempfile.TemporaryDirectory(prefix='penumbra-cursors-') as tmp:
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
(THEME/'index.theme').write_text('[Icon Theme]\nName=Penumbra Cursors\nComment=Soft lavender cursors with midnight outlines and a violet ring spinner\nInherits=breeze_cursors\n')
# SVG contact sheet, keeping the artwork editable and inspectable.
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="960" height="570" viewBox="0 0 960 570"><rect width="960" height="570" rx="24" fill="#100d18"/><text x="40" y="50" fill="#e4dced" font-family="Inter" font-size="24">PENUMBRA / CURSORS</text><text x="40" y="79" fill="#8f809f" font-family="Inter" font-size="13">Soft lavender silhouettes · midnight outlines · violet ring spinner</text>']
for n,(name,(images,_,_)) in enumerate(frames.items()):
 x=40+(n%6)*150;y=110+(n//6)*110
 inner=images[len(images)//3].split('>',1)[1].rsplit('</svg>',1)[0]
 parts.append(f'<rect x="{x}" y="{y}" width="132" height="82" rx="12" fill="#1a1324"/><g transform="translate({x+42} {y+7}) scale(1.5)">{inner}</g><text x="{x+66}" y="{y+99}" fill="#a99abb" font-family="Inter" font-size="11" text-anchor="middle">{name}</text>')
parts.append('</svg>')
p=ROOT/'previews/cursors.svg';p.write_text(''.join(parts))
subprocess.run(['rsvg-convert',str(p),'-o',str(p.with_suffix('.png'))],check=True)
print(f'Built {len(frames)} original shapes / {len(list((THEME/"cursors").iterdir()))} cursor names, five sizes each.')
