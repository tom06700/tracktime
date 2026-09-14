# Passage natif — 14 septembre 2026

La collection vide de Séries et de Films utilise désormais une porte lilas
entrouverte, en boucle de 7 secondes. La porte et le CTA lancent la même
traversée de 2,2 secondes vers l’instance existante d’Explorer.

Le rendu est reconstruit en Flutter : géométrie en perspective, porte articulée,
biseaux et gradients. Il reprend la caméra et les temps du prototype Three.js,
mais ne charge ni WebView ni séquence d’images. Les matériaux sont une adaptation
native du rendu WebGL, pas un moteur PBR. La même projection pilote le masque
sur Explorer et le dessin de l’arche.

Navigation : engagement unique, onglet sélectionné à la fin, annulation par
retour système, état d’Explorer conservé, commandes masquées pendant le trajet.
Réduction des animations : accès direct. Tickers suspendus pour les onglets
cachés et la porte lorsque l’app passe en arrière-plan.

Les collections de l’iPhone étant remplies, la version hors release propose
Réglages → Tester le portail. Cette route utilise la même coquille et le vrai
Explorer ; seule la présentation des deux collections est forcée à l’état vide.
Aucune collection ni donnée n’est effacée ou remplacée. L’entrée et la route
sont absentes d’un build release.

Vérifications : analyse statique sans problème ; 72 tests ciblés réussis
(portail, Séries, Films, navbar, Explorer, navigation des fiches). Les tests
couvrent la conservation de la recherche après deux traversées, l’activation
multiple, l’annulation, le démontage, la réduction des animations et le bouton
sur un écran de 320 × 640 avec du texte agrandi à 200 %.
Captures natives du modèle : app/build/audit/portal/.

Contrôle sur l’iPhone physique en mode profile : traversée depuis le bouton
Séries enregistrée dans /tmp/nitrate-portal-iphone-series/ (135 images).
Les planches montrent l’ouverture, le passage de l’arche et l’arrivée dans le
vrai Explorer. Cette inspection visuelle n’est pas une mesure de fréquence
d’images ni une garantie de performance sur tous les appareils.

La dernière version a aussi été vérifiée par activation directe de la porte
dans Films : arrivée dans Explorer confirmée par l’arbre d’accessibilité.
Enregistrement : /tmp/nitrate-portal-iphone-films/ (141 images) ; planche 03
inspectée pour le passage de l’arche et la stabilisation de la destination.

## Raffinement des matériaux

Le dessin par aplats est remplacé par un petit maillage conservé en mémoire :
biseaux en quatre subdivisions, normales lissées, lumière principale et reflet
large, éclairage de bord, panneau rapporté, deux charnières, poignée capsule
avec supports et seuil en volume. Les triangles sont interpolés par Canvas ;
les pièces sont ordonnées en profondeur, les faces cachées écartées et les
triangles coupés près de la caméra. La projection et la durée de traversée sont
conservées. Le halo chaud suit la respiration de la porte.

C’est toujours une adaptation native des matériaux du prototype, sans ses
réflexions d’environnement PBR. Exports visuels à 2× dans app/build/audit/portal/.
Les six tests de comportement du portail et l’export des quatre poses passent ;
analyse statique des fichiers du portail sans diagnostic.

Validation du raffinement sur iPhone en profile : entrée directe par la porte,
arrivée dans Explorer confirmée. Enregistrement de 184 images dans
/tmp/nitrate-portal-detailed-iphone/ ; planches 04 et 05 inspectées.
MobAI a recueilli cinq échantillons FPS en 4,68 s : 0 à l’initialisation du
collecteur (machAbsTime 267), puis 60, 60, 60 et 60. La moyenne brute 48 inclut
le premier zéro ; cette courte mesure système ne constitue pas une mesure
exhaustive des temps de trame Flutter ni une garantie pour Android.
