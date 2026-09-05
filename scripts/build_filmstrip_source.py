"""Editable SVG study of the authored Flutter ribbon. No catalogue imagery."""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
curves = [((-65,190),(75,258),(90,45),(225,93)),
          ((225,93),(300,120),(316,185),(465,74))]
points=[]
for curve in curves:
    for i in range(501):
        t=i/500; u=1-t
        points.append(tuple(u**3*curve[0][j]+3*u*u*t*curve[1][j]+3*u*t*t*curve[2][j]+t**3*curve[3][j] for j in range(2)))
distances=[0]
for a,b in zip(points,points[1:]): distances.append(distances[-1]+math.dist(a,b))
length=distances[-1]
def position(d):
    import bisect
    i=min(max(bisect.bisect_right(distances,d),1),len(points)-1)
    a,b=points[i-1],points[i]
    angle=math.atan2(b[1]-a[1],b[0]-a[0])
    return b[0],b[1],angle
edges=[]
for side, indices in [(-43,range(101)),(43,range(100,-1,-1))]:
    for i in indices:
        x,y,a=position(length*i/100)
        edges.append((x-math.sin(a)*side,y+math.cos(a)*side))
path='M'+' L'.join(f'{x:.3f},{y:.3f}' for x,y in edges)+' Z'
svg=['<svg xmlns="http://www.w3.org/2000/svg" width="400" height="280" viewBox="0 0 400 280">',
'<defs><linearGradient id="stock" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#888571"/><stop offset="52%" stop-color="#ddd3b8"/><stop offset="100%" stop-color="#666c5f"/></linearGradient>',
f'<clipPath id="film"><path d="{path}"/></clipPath></defs>',
'<rect width="400" height="280" fill="#080c0b"/>',
f'<path d="{path}" fill="url(#stock)" stroke="#f3e7cf" stroke-width=".7"/>',
'<g clip-path="url(#film)">']
pitch=length/8
for i in range(8):
    x,y,a=position(i*pitch)
    svg.append(f'<rect x="{-pitch/2+4.5:.3f}" y="-28" width="{pitch-9:.3f}" height="56" rx="2" fill="#111713" stroke="#5c5e50" stroke-width=".6" transform="translate({x:.3f} {y:.3f}) rotate({math.degrees(a):.3f})"/>')
for i in range(48):
    x,y,a=position(i*length/48)
    for side in [-35,35]:
        svg.append(f'<rect x="-2.5" y="{side-3.5}" width="5" height="7" rx="1.1" fill="#080c0b" transform="translate({x:.3f} {y:.3f}) rotate({math.degrees(a):.3f})"/>')
svg+=['</g>','</svg>']
out=ROOT/'design/motion/filmstrip.svg';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text('\n'.join(svg))
print(out)
