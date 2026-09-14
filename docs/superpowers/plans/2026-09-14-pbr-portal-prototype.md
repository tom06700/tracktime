# Prototype du portail PBR

Direction approuvée : reprendre la porte lilas du prototype Three.js avec
Thermion / Filament et comparer sur iPhone avant remplacement.

Architecture : aperçu dédié hors release dans Nitrate, glTF original avec
charnière nommée, matériaux PBR et studio. Un viewer conservé du repos au passage.
La projection pilote aussi le masque Flutter sur le véritable Explorer.

- [x] Exporter app/assets/portal/portal.glb et son générateur reproductible :
  mêmes dimensions, biseaux, quincaillerie ; PortalRoot et DoorPivot nommés.
  Valider les indices, buffers et matériaux dans le GLB.
- [x] Résoudre thermion_flutter 0.5.0 avec Flutter local 3.41.9 ; contrôler les
  changements de dépendances et lire les interfaces du package résolu.
- [x] Construire un aperçu PBR dédié accessible depuis Réglages : boucle 7 s,
  traversée 2,2 s, retour/rejeu, réduction des animations, erreur visible,
  arrêt en arrière-plan et destruction du viewer en quittant l’aperçu.
- [ ] Vérifier géométrie/cycle de vie, analyse et build iOS profile. Tester sur
  téléphone les matériaux et la traversée, mesurer la fluidité, puis couper
  l’automation. Documenter les limites non mesurées sur Android.

Aucun effacement de collection, changement de SDK global, commit ni push.
