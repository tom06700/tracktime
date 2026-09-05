# Nitrate — direction cinéma

## Identity

Ink `#080C0B`, ivory `#F3E7CF`. Cormorant Garamond Medium is bundled offline for the wordmark and editorial titles; the operating-system UI font remains the default for controls and metadata. The font license is included. Vector wordmarks contain outlined glyphs and do not require the font to display. Native app icons are exported from the same identity by `scripts/build_brand.py` (Pillow and fontTools).

## Images

The home uses the featured series backdrop, then episode still, then poster. Failed image requests advance to the next source. Actual catalogue art remains supplied by TheTVDB, not embedded as a fake generated series image. The original cinema illustration is reserved for an empty library. It is bundled as a 40 KB WebP. Audit fixtures are downloaded at runtime and excluded from git.

## Motion

- Artwork reveal: 220 ms opacity, ease-out.
- Featured series change: 620 ms crossfade.
- Vertical artwork parallax: 18% of scroll, capped at 90 px.
- Watched action: brief 240 ms confirmation before persistence; repeated presses blocked while saving; error feedback if persistence fails.
- Navigation selection: 150 ms color, 180 ms marker.
- Episode navigation uses the existing native route transition.

Reduced-motion settings disable the parallax, fades and episode slide. High contrast replaces navigation blur with an opaque surface. Enlarged text stacks the hero actions and increases the navigation height.

## Verification

`flutter analyze` and `flutter test` run in GitHub Actions. The UI screenshots workflow renders the real Flutter widgets at a 390 × 844 logical viewport, with fixture data and live catalogue image downloads. It also encodes a 3-second, 30 fps animation sequence from widget-test frames. This is an animation preview, not evidence of physical-device frame rate or an installed iOS build.

TestFlight still requires the project's Codemagic workflow. No web target is introduced.

## Refonte septembre 2026 — lot en cours

La branche `design/nitrate-cinema-motion` regroupe la refonte dans une seule PR.
Aucune fusion intermédiaire : Codemagic distribue uniquement le lot retenu après
les vérifications techniques. Le propriétaire inspecte le rendu et le mouvement
sur son iPhone ; les itérations locales reprendront sur son Mac M2.

Le nouveau générique utilise un iris de projection vectoriel peint en Flutter.
Son ouverture dure 1,4 s, une fois, sans boucle ni appel réseau. Le réglage de
réduction des animations montre immédiatement l'état final. L'intro s'affiche
une fois, persiste une préférence distincte des données de la collection, et
reste accessible via Réglages → Découvrir Nitrate.

Les collections et historiques reçoivent des titres de chapitre défilants.
Les commandes conservent une typographie système ; les titres éditoriaux restent
en Cormorant Garamond. Surfaces vert encre, texte blanc chaud, accent ivoire,
boutons en capsules, cartes arrondies à 22 px. Les surfaces secondaires sont
sobres ; le verre reste principalement réservé à la navigation flottante.
Le repère actif de navigation possède aussi une surface distincte.

L'accueil conserve uniquement les images de la véritable œuvre : le centre de
l'image est dégagé, avec une assise sombre sous le texte et un voile supérieur
pour les commandes. La variation de luminosité des catalogues doit encore être
contrôlée sur appareil ; ce traitement n'est pas une validation artistique.

Pas d'abonnement Appllama ou Rive, pas de nouveau package, pas de cible web,
pas de changement du stockage de la collection. Les tests ne remplacent pas
la revue du cadrage, du défilement, des transitions et de la fluidité sur iPhone.
