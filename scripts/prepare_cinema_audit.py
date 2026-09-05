"""Fetch catalogue artwork for the opt-in visual audit only; never user data.
The standard test suite remains offline. No token or key is persisted.
"""
import json,re,urllib.request,urllib.parse
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
# Movie ids below are test-fixture aliases, resolved to real TVDB records by title/year.
for alias,title,year in [(1406,'Dune','2021'),(496243,'Parasite','2019'),(27205,'Inception','2010'),(157336,'Interstellar','2014'),(603,'Oppenheimer','2023'),(872585,'Once Upon a Time in Hollywood','2019'),(1,'The Assassination of Jesse James by the Coward Robert Ford','2007')]:
 query=urllib.parse.urlencode({'query':title,'type':'movie','year':year})
 req=urllib.request.Request('https://api4.thetvdb.com/v4/search?'+query,headers={'Authorization':'Bearer '+token})
 with urllib.request.urlopen(req,timeout=30) as r:hits=json.load(r)['data']
 hit=next(h for h in hits if str(h.get('year'))==year)
 url=hit.get('image_url') or hit.get('thumbnail')
 with urllib.request.urlopen(url,timeout=30) as r:content=r.read()
 (out/f'movie-{alias}.jpg').write_bytes(content)
 credits.append(f'movie-{alias} ({title}, {year}): {url}')
(out/'SOURCES.txt').write_text('Images TheTVDB / ayants droit des œuvres. Captures de démonstration uniquement.\n'+'\n'.join(credits)+'\n')
print('Catalogue images prepared for visual verification.')
