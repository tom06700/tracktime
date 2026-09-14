"""Build the approved Nitrate SVG as exact cubic paths with a draw-on matte."""
import json
import re
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
source = root.parents[2] / 'app/assets/brand/symbol-lilac.svg'
out = root / 'public/projects/nitrate/scene-1'
out.mkdir(parents=True, exist_ok=True)
svg = ET.parse(source).getroot()
d = svg.find('{http://www.w3.org/2000/svg}path').attrib['d']
tokens = re.findall(r'[MCZ]|-?\d+(?:\.\d+)?', d)
v, incoming, outgoing = [], [], []
p = 0
while p < len(tokens):
    cmd = tokens[p]; p += 1
    if cmd == 'M':
        v.append([float(tokens[p]), float(tokens[p+1])]); p += 2
        incoming.append([0, 0]); outgoing.append([0, 0])
    elif cmd == 'C':
        a, b, x = [list(map(float, tokens[p+i:p+i+2])) for i in (0, 2, 4)]
        p += 6
        outgoing[-1] = [a[j]-v[-1][j] for j in (0,1)]
        v.append(x); incoming.append([b[j]-x[j] for j in (0,1)]); outgoing.append([0,0])
    elif cmd != 'Z':
        raise ValueError(cmd)
if v[-1] == v[0]:
    incoming[0] = incoming.pop(); v.pop(); outgoing.pop()
shape = {'v':v, 'i':incoming, 'o':outgoing, 'c':True}
static = lambda k: {'a':0, 'k':k}

def keys(beats):
    # Baked smoothstep removes ambiguity between Lottie easing implementations.
    frames=[]
    for (start,a),(end,b) in zip(beats,beats[1:]):
        for t in range(start,end):
            u=(t-start)/(end-start); u=u*u*(3-2*u)
            frames.append({'t':t,'s':[round(a+(b-a)*u,5)],'h':1})
    frames.append({'t':beats[-1][0],'s':[beats[-1][1]],'h':1})
    return {'a':1,'k':frames}

def transform(opacity=None):
    return {'o':opacity or static(100), 'r':static(0), 'p':static([128,128,0]),
            'a':static([117,112,0]),'s':{'a':0,'k':[82,82,100]}}

def layer(index,name,shapes):
    return {'ddd':0,'ind':index,'ty':4,'nm':name,'sr':1,'ks':transform(),
            'ao':0,'shapes':shapes,'ip':0,'op':144,'st':0,'bm':0}

# Broad animated stroke clips the exact filled SVG. No logo geometry is morphed.
spine={'c':False,'v':[[44,288],[44,58],[83,47],[183,100],[185,288]],
       'i':[[0,0],[0,65],[-24,-15],[-27,-18],[0,-72]],
       'o':[[0,-65],[0,-34],[24,15],[2,45],[0,0]]}
matte=layer(1,'Tracé du ruban · masque',[
    {'ty':'sh','nm':'Trajet du ruban','ks':static(spine)},
    {'ty':'st','c':static([1,1,1,1]),'o':static(100),'w':static(112),'lc':2,'lj':2},
    {'ty':'tm','s':static(0),'e':keys([(0,0),(66,100),(143,100)]),'o':static(0),'m':1}
])
matte['td']=1
logo=layer(2,'Symbole Nitrate · tracé SVG original',[
    {'ty':'sh','nm':'Silhouette originale','ks':static(shape)},
    {'ty':'fl','c':{'a':0,'k':[197/255,174/255,253/255,1],'sid':'nitrateLilac'},'o':static(100),'r':2}
])
logo['tt']=1
logo['ks']=transform(keys([(0,100),(92,100),(138,0),(143,0)]))
anim={'v':'5.12.2','fr':60,'ip':0,'op':144,'w':256,'h':256,
      'nm':'Nitrate · Le ruban se dessine','ddd':0,'assets':[],
      'markers':[{'tm':0,'cm':'Tracé','dr':66},{'tm':66,'cm':'Pause sur le logo','dr':26},{'tm':92,'cm':'Effacement doux','dr':46}],
      'slots':{'nitrateLilac':{'p':static([197/255,174/255,253/255,1])}},
      'layers':[matte,logo]}
(out/'lottie.json').write_text(json.dumps(anim,separators=(',',':'))+'\n')
(out/'controls.json').write_text(json.dumps({'controls':[{'sid':'nitrateLilac','label':'Lilas Nitrate'}]},indent=2)+'\n')
(out/'source-logo.svg').write_text(source.read_text())
print(f'{out}/lottie.json — {len(v)} cubic vertices, 144 frames / 2.4 s, transparent')
