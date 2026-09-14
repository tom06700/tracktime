# Transitions de collection natives — Implementation Plan

**Goal:** Intégrer les deux aperçus approuvés : Cascade ciné dans Séries et déplacement fluide dans Films.

**Architecture:** Un coordinateur mesure les affiches visibles avant/après le changement de disposition. Une couche temporaire déplace les affiches avec recadrage uniforme pendant que les vrais widgets restent montés à destination. Les listes restent paresseuses. Les demandes rapides sont mises en attente ; le mouvement réduit applique directement la disposition.

**Tech Stack:** Flutter, AnimationController, RenderBox, ImageFiltered, tests widget.

- [x] Ajouter un test écran qui passe de la grande carte Séries à la grille puis revient ; conserver sélection et accès aux épisodes.
- [x] Ajouter un coordinateur partagé et un sélecteur compact accessible. Séries : 780 ms, expo.inOut, décalage de 48 ms plafonné à 240 ms, flou 3 et luminosité 1.14 temporaires. Films : 640 ms, cubic(.22,1,.36,1), décalage de 22 ms plafonné à 65 ms.
- [x] Brancher les ancres des affiches, la grille Séries et les colonnes Films, conserver les actions existantes.
- [x] Tester le retour, les demandes rapides, le mouvement réduit et les textes agrandis ; analyser le code.
- [x] Recharger sur l’iPhone connecté. MobAI indisponible dans la session : vérifier la connexion Flutter et signaler la limite de validation visuelle physique.

Validation du design : demande explicite du 9 septembre 2026 après comparaison interactive. Films conserve le mouvement de collection-views ; Séries utilise 02, sans les variantes 02A/02B.


Navbar : l’indicateur prévisualise la destination pendant le drag ; le callback de navigation est appelé au relâchement uniquement. Une annulation du pointeur rétablit la sélection actuelle. Tests de parcours de plusieurs onglets, glissement rapide et annulation.

MobAI est devenu disponible pendant l’intégration. Il détecte l’UDID de l’iPhone cible, mais start_bridge renvoie une erreur de connexion demandant déverrouillage/confiance. Le hot reload Flutter a réussi ; validation visuelle physique en attente de connexion.

Validation : `flutter test --no-pub` : 381 tests réussis, 4 ignorés. `flutter analyze --no-pub` : aucun problème. Hot reload : 10 bibliothèques rechargées sur l’iPhone cible. Contrôle visuel physique non confirmé tant que le bridge MobAI ne démarre pas.


## Vérification du 9 septembre, après contrôle sur iPhone

- Sélecteurs : pictogrammes des dispositions réelles, sélection lilas, fond discret sans bordure extérieure.
- Animation : correction de l'arrondi flottant à la fin du flou ; interpolation des rayons des coins ; fondu de 120 ms entre l'image en déplacement et la vraie carte pour faire revenir ses titres et actions progressivement.
- Audit de la vraie interface Flutter : 24 captures par sens, Séries et Films, soit 96 frames ; audit réussi. Sortie locale : `/tmp/nitrate-collection-audit-final`.
- MobAI connecté après déverrouillage : installation du build signé via IPA, lancement debug, essais de bascule dans les deux sens sur Séries et Films. Les enregistrements MobAI ont une cadence variable et ne constituent pas une mesure de fluidité à 60/120 Hz. L'audit Flutter complète leurs frames manquantes.
- Compteur : le nombre de visionnages historiques incluait les spéciaux et références absentes du catalogue alors que le total de synchronisation les excluait. La progression compare désormais uniquement les épisodes réguliers du catalogue local à leurs visionnages correspondants. Les statistiques historiques conservent tous les visionnages. Le statut terminé utilise le même périmètre.
- One Piece observé sur l'iPhone après correction : **1154 / 1177, 98 %** ; aucun visionnage supprimé.
- Validation finale : **383 tests réussis, 4 ignorés**, analyse Flutter sans problème, build iOS debug signé et installé. Nitrate laissée ouverte sur Séries.
