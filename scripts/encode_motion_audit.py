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
