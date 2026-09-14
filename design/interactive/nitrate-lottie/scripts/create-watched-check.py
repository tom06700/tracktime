import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'public/projects/nitrate/scene-2'
out.mkdir(parents=True,exist_ok=True)
s=lambda k:{'a':0,'k':k}
def curve(beats):
 frames=[]
 for (t,a),(end,b) in zip(beats,beats[1:]):
  for f in range(t,end):
   u=(f-t)/(end-t);u=1-(1-u)**3
   frames.append({'t':f,'s':[round(a+(b-a)*u,5)],'h':1})
 frames.append({'t':beats[-1][0],'s':[beats[-1][1]],'h':1})
 return {'a':1,'k':frames}
color=[69/255,94/255,51/255,1]
stroke=lambda:{'ty':'st','c':{'a':0,'k':color,'sid':'checkColor'},'o':s(100),'w':s(3.5),'lc':2,'lj':2}
tr={'ty':'tr','p':s([0,0]),'a':s([0,0]),'s':s([100,100]),'r':s(0),'o':s(100),'sk':s(0),'sa':s(0)}
ring={'ty':'gr','nm':'Cercle qui s’ouvre','it':[{'ty':'el','p':s([24,24]),'s':s([34,34]),'d':1},stroke(),{'ty':'tm','s':curve([(0,0),(14,100),(29,100)]),'e':s(100),'o':s(-90),'m':1},tr]}
check={'ty':'gr','nm':'Coche de confirmation','it':[{'ty':'sh','ks':s({'c':False,'v':[[9,24],[20,34],[39,13]],'i':[[0,0]]*3,'o':[[0,0]]*3})},stroke(),{'ty':'tm','s':s(0),'e':curve([(0,0),(4,0),(24,100),(29,100)]),'o':s(0),'m':1},tr]}
anim={'v':'5.12.2','fr':60,'ip':0,'op':30,'w':48,'h':48,'nm':'Nitrate · Marquer vu','ddd':0,'assets':[],
 'slots':{'checkColor':{'p':s(color)}},
 'layers':[{'ddd':0,'ind':1,'ty':4,'nm':'Validation enregistrée','sr':1,'ks':{'o':s(100),'r':s(0),'p':s([0,0,0]),'a':s([0,0,0]),'s':s([100,100,100])},'ao':0,'shapes':[check,ring],'ip':0,'op':30,'st':0,'bm':0}]}
def names(items):
 for i,x in enumerate(items):
  x.setdefault('nm',f"{x['ty']} {i}")
  if x.get('it'): names(x['it'])
for layer in anim['layers']: names(layer['shapes'])
(out/'lottie.json').write_text(json.dumps(anim,separators=(',',':'))+'\n')
(out/'controls.json').write_text(json.dumps({'controls':[{'sid':'checkColor','label':'Couleur de la coche'}]},indent=2)+'\n')
print(out)
