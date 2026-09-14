# Aperçu du loader Nitrate

Lecteur officiel diffusionstudio/lottie, base `3c72912fad543897f90045ed4d355813837927fc` (MIT).

## Ouvrir

Avec Node 22.12+ ou 24 :

```sh
npm install
npm run dev -- --host 127.0.0.1
```

Utiliser le port annoncé par Vite, puis ouvrir `/nitrate/scene-1`.
Le lecteur propose lecture/pause, déplacement image par image et vitesses 1×, 0,5×, 0,25×. Le zoom et la couleur lilas sont réglables.

## Animation

- `public/projects/nitrate/scene-1/lottie.json` : 256 × 256, 60 images/s, 144 images (2,4 s), fond transparent.
- Géométrie conservée depuis `app/assets/brand/symbol-lilac.svg` : 117 sommets et courbes cubiques d’origine, couleur #C5AEFD.
- Images 0–66 : dessin du ruban par masque progressif ; 66–92 : maintien ; 92–138 : effacement ; 138–143 : raccord transparent.
- Aucun texte, fond, police ou bitmap requis par le JSON. Le masque de révélation est vectoriel.
- `scripts/create-nitrate-loader.py` reconstruit la scène depuis le SVG ; il écrase ses réglages. Lire le JSON actuel avant de régénérer si la couleur a été modifiée dans le lecteur.

## Vérification

Rendu inspecté dans Skia Skottie aux images 0, 24, 44, 72, 112 et 143 ; silhouette complète comparée à l’identité Nitrate, début/fin transparents. Lecture/pause et ralenti vérifiés dans Brave. La scène figure dans `/__context`.

Adaptations du lecteur : contrôle de vitesse, libellés accessibles de lecture/timeline ; `skipLibCheck` ignore des erreurs dans les déclarations tierces Kobalte/Lucide, tout en conservant `strict` sur le code du lecteur. Aucune intégration Flutter à ce stade.
