"""Rebuild Nitrate's outlined SVG wordmark and native app icons.
Requires fonttools and Pillow. Typography licensed under the bundled OFL.
"""
from pathlib import Path
import json
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1]
fontpath=root/'app/assets/fonts/CormorantGaramond.ttf'
f=TTFont(fontpath); gs=f.getGlyphSet(); cmap=f.getBestCmap()
def paths(text):
 x=0;out=[]
 for c in text:
  g=gs[cmap[ord(c)]];pen=SVGPathPen(gs);g.draw(pen)
  out.append(f'<path transform="translate({x} 0)" d="{pen.getCommands()}"/>');x+=g.width
 return ''.join(out),x
brand=root/'app/assets/brand';brand.mkdir(parents=True,exist_ok=True)
p,w=paths('Nitrate')
for name,color in [('wordmark-ivory','#F3E7CF'),('wordmark-ink','#080C0B')]:
 (brand/f'{name}.svg').write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} 850"><title>Nitrate</title><g fill="{color}" transform="translate(0 720) scale(1 -1)">{p}</g></svg>')
n,nw=paths('N')
nx=(1024-nw*.70)/2
svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><title>Nitrate app icon</title><rect width="1024" height="1024" fill="#080C0B"/><rect x="192" y="148" width="640" height="728" rx="58" fill="none" stroke="#F3E7CF" stroke-width="18"/><g fill="#F3E7CF" transform="translate({nx} 734) scale(.70 -.70)">{n}</g></svg>'
(brand/'app-icon.svg').write_text(svg)
# Native raster exports use the very same font outline and brand geometry.
im=Image.new('RGB',(1024,1024),'#080C0B');d=ImageDraw.Draw(im)
d.rounded_rectangle((192,148,832,876),radius=58,outline='#F3E7CF',width=18)
font=ImageFont.truetype(str(fontpath),700)
d.text((nx,734),'N',font=font,fill='#F3E7CF',anchor='ls')
im.save(brand/'app-icon-1024.png')
ios=root/'app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((ios/'Contents.json').read_text())['images']:
 if 'filename' not in item: continue
 size=int(float(item['size'].split('x')[0])*float(item['scale'].rstrip('x')))
 im.resize((size,size),Image.Resampling.LANCZOS).save(ios/item['filename'])
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 path=root/f'app/android/app/src/main/res/mipmap-{density}/ic_launcher.png';path.parent.mkdir(parents=True,exist_ok=True)
 im.resize((size,size),Image.Resampling.LANCZOS).save(path)
print('SVG wordmarks and native icon exports ready')
