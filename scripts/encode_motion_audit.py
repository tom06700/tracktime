#!/usr/bin/env python3
"""Encode rendered Flutter frames at their test sampling interval, not device FPS."""
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else 'app/build/modern-audit').resolve()
sequences = [('motion-intro-', 1000 / 33), ('motion-departure-', 1000 / 33),
             ('episode-motion-', 20)]
sequences += [(f'motion-control-{name}-', 20) for name in ['softCheck', 'attach', 'nextUp', 'surprise']]
sequences += [(f'edge-{name}-', 20) for name in ['Profil', 'Séries', 'À venir', 'À voir']]
sequences += [('global-series-enter-', 20), ('global-series-tabs-', 20)]
for prefix, fps in sequences:
    frames = sorted(root.glob(prefix + '*.png'), key=lambda p: int(p.stem.removeprefix(prefix)))
    if not frames:
        continue
    with tempfile.TemporaryDirectory(prefix='nitrate-motion-') as tmp:
        for index, frame in enumerate(frames):
            pathlib.Path(tmp, f'{index:04d}.png').symlink_to(frame)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(fps),
                        '-i', str(pathlib.Path(tmp, '%04d.png')), '-c:v', 'libx264',
                        '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                        str(root / (prefix.rstrip('-') + '.mp4'))], check=True)
(root / 'VIDEO-README.txt').write_text('Séquences Flutter rendues par widget tests à temps simulé.\nCes vidéos montrent les transitions, pas les performances ni les FPS d’un appareil iOS/Android.\n')

# Portable review gallery, bundled with the original PNG frames and MP4s.
import html
stills = ['01-intro', '05-notifications', '01-series', '02-series-a-venir',
          '09-fiche-serie', '10-fiche-serie-episodes', '11-fiche-serie-non-vus',
          'episode-1155', '07-fiche-film', '12-fiche-film-titre-long',
          '04-explorer', '20-explorer-recherche', '05-profil', '06-profil-bas']
page = ['<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
        '<title>Nitrate — revue Flutter</title><style>body{margin:24px;background:#101113;color:#f5f1fa;font:15px system-ui}h1{font-weight:500}p{max-width:800px;line-height:1.6}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;width:min(390px,100%)}img,video{width:100%;border-radius:20px}figcaption{padding:12px 0;color:#cab7ff}a{color:#cab7ff}</style>',
        '<h1>Nitrate · Revue native Flutter</h1><p>Captures de widgets à 390 px logiques, avec zones sûres. Les œuvres et dates servent de fixtures déterministes aux services réels. Vidéos rendues à temps simulé : elles montrent les transitions, pas les performances d’un téléphone. La validation sur appareil reste nécessaire.</p><h2>Écrans</h2><div class="grid">']
for name in stills:
    if (root / (name + '.png')).exists():
        page.append(f'<figure><a href="{name}.png"><img loading="lazy" src="{name}.png" alt="{name}"></a><figcaption>{name}</figcaption></figure>')
page.append('</div><h2>Animations</h2><div class="grid">')
for video in sorted(root.glob('*.mp4')):
    name = html.escape(video.name, quote=True)
    page.append(f'<figure><video controls muted playsinline loop preload="metadata" src="{name}"></video><figcaption>{name}</figcaption></figure>')
page.append('</div></html>')
(root / 'index.html').write_text(''.join(page))
