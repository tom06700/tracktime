"""Fetch catalogue artwork for the opt-in visual audit only; never user data.
The standard test suite remains offline. No token or key is persisted.
"""
import json,re,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'app/test/fixtures/cinema';out.mkdir(parents=True,exist_ok=True)
config=(root/'app/lib/tmdb/tvdb_config.dart').read_text()
key=re.search(r'[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}',config).group()
req=urllib.request.Request('https://api4.thetvdb.com/v4/login',data=json.dumps({'apikey':key}).encode(),headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req,timeout=30) as r:token=json.load(r)['data']['token']
credits=[]
for name,id in [('severance',371980),('one-piece',81797),('last-of-us',392256)]:
 req=urllib.request.Request(f'https://api4.thetvdb.com/v4/series/{id}/extended',headers={'Authorization':'Bearer '+token})
 with urllib.request.urlopen(req,timeout=30) as r:data=json.load(r)['data']
 urls=[(name,data['image'])]
 if name=='severance':
  art=next(a for a in data['artworks'] if a.get('type')==3)
  urls.append(('severance-backdrop',art['image']))
 for label,url in urls:
  with urllib.request.urlopen(url,timeout=30) as r:content=r.read()
  (out/f'{label}.jpg').write_bytes(content)
  credits.append(f'{label}: {url}')
(out/'SOURCES.txt').write_text('Images TheTVDB / ayants droit des œuvres. Captures de démonstration uniquement.\n'+'\n'.join(credits)+'\n')
print('Four catalogue images prepared for visual verification.')
