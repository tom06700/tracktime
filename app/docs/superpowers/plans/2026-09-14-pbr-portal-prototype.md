# Prototype du portail PBR

Direction approuvée : reprendre la porte lilas du prototype Three.js avec un
moteur PBR réel (Thermion / Filament), comparer sur iPhone avant remplacement.

Architecture : aperçu de développement dans Nitrate. Modèle glTF original
exporté de la géométrie Three.js ; charnière nommée pilotable ; matériau céramique
et métal, environnement de studio. Un seul viewer conservé de la pose au repos
à la traversée. Géométrie de caméra partagée avec le masque Flutter sur Explorer.
La version actuelle des états vides reste disponible pour comparaison.

- [ ] Préparer `app/assets/portal/portal.glb` et son générateur reproductible
  sous `design/interactive/empty-motion-lab/`. Exiger les noms PortalRoot et
  DoorPivot, les dimensions du prototype, les biseaux et la quincaillerie.
  Vérifier les buffers, les indices et les limites géométriques du GLB.
- [ ] Résoudre Thermion avec le SDK local sans modifier sa version. Lire le
  code du package réellement résolu pour la caméra, les matériaux, les assets,
  les textures transparentes et la destruction des ressources.
- [ ] Construire un aperçu PBR dédié (route de développement + entrée Réglages)
  : phase 7 s, porte toujours entrouverte, traversée 2,2 s, Explorer réel révélé
  derrière l'arche. Le contrôleur borne les mises à jour asynchrones à une en
  vol et arrête le rendu hors écran / arrière-plan. Erreur visible avec retour
  possible si le moteur ne peut pas démarrer ; animations réduites respectées.
- [ ] Analyser, tester les calculs et le cycle de vie, compiler iOS en profile,
  installer sur l'iPhone et vérifier la porte, l'entrée, le retour, les matériaux
  et la fluidité. Couper ensuite l'automation. Documenter les limites Android
  non mesurées et la compatibilité constatée.

Aucun effacement de collection, changement de SDK global, commit ni push.
