# Animation du sélecteur d’épisode

Objectif : intégrer la V2 validée de l’aperçu local dans Flutter.

- [x] Ajouter des rouleaux indépendants dans `episode_number_reels.dart` : un contrôleur, transitions interrompables, saisie immédiate et réduction des animations.
- [x] Ajouter `episode_number_ruler.dart` : liste horizontale paresseuse de numéros officiels, sélection en glissant, calage physique et sémantique d’ajustement.
- [x] Relier ces contrôles dans `episode_number_picker.dart`, conserver la validation et fixer la place de l’aperçu pour stabiliser le bouton.
- [x] Partager le contrôleur du panneau avec la fiche série pour le recul du fond, sans reconstruire la liste à chaque frame. Conserver les gestes natifs de la feuille modale.
- [x] Tester trous, grandes saisons, appuis successifs, glissement, clavier, accessibilité et fermeture ; analyser puis installer le build profile sur iPhone et arrêter l’automation après contrôle.

Le panneau reste consultatif : aucun visionnage modifié. Références de mouvement : NumberFlow (https://number-flow.barvian.me/) et Vaul (https://emilkowal.ski/ui/building-a-drawer-component). Reproduction Flutter originale sans nouvelle dépendance.

Validation : 29 tests Flutter passent ; analyse ciblée sans problème et `git diff --check` propre. Build iOS profile installé sur l’iPhone connecté. Saisie, aller-retour 9 ↔ 10, réglette 9 → 13 et fermeture par glissement vérifiés. Enregistrements `/tmp/nitrate-picker-motion/flow` (15 images, planche inspectée) et `/tmp/nitrate-picker-motion/sheet` (2 images, échantillonnage insuffisant pour évaluer toute la fermeture). Le bouton conserve sa position entre les titres ; aucun visionnage modifié. Automation arrêtée après contrôle. Android partage ces widgets Flutter mais n’a pas été testé sur matériel dans cette session.
