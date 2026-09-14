# Confirmation « Marquer vu »

Périmètre validé : bouton et coche Films/Séries, sans nouvelle transition de carte. Animation Lottie transparente de 500 ms (dessin résolu à 400 ms), cercle qui s’ouvre puis coche stable. Aucun succès avant l’écriture ; double appui bloqué ; erreur réessayable. Réduction des animations : état final immédiat.

1. Créer et inspecter scene-2 dans le lecteur officiel Skottie.
2. Partager un glyph Flutter piloté par l’état confirmé. L’activer dans la commande Série sans changer les autres commandes.
3. Faire attendre le bouton Film sur la vraie écriture ; retenir la carte 550 ms après succès pour lire la coche, puis laisser la grille existante se mettre à jour. Libérer la carte en cas d’erreur/démontage et bloquer les actions concurrentes sur ce film.
4. Tests : enregistrement immédiat, erreur et double appui, progression/réduction des animations, maintien puis retrait de carte ; analyse Flutter et vérification iPhone.

## Réalisation

- Scène `nitrate/scene-2` inspectée dans Skottie aux images 0, 12 et 29 ; version exportée dans `app/assets/animations/watched-check.json`.
- `WatchedCheck` reste monté pendant l’écriture pour jouer la transition uniquement au passage réel à confirmé. Mode réduit statique, pas de répétition sur un rebuild.
- `ModernCommand.animatedConfirmation` activé uniquement sur le héros Séries ; fin de la rotation de l’orbe pour ce bouton.
- Le bouton Film attend sa Future et gère échec/réessai. `_LibraryGrid` retient séparément les films en confirmation et conserve leurs états lors d’un changement d’index. Écriture déclenchée immédiatement, carte libérée 550 ms après succès ; menus bloqués pendant cette opération. Aucun changement de persistance.
- Test d’enregistrement immédiat observé en échec (0 écriture), puis passé après correction. 31 tests ciblés réussis : boutons de cartes, commandes, pages Séries/Films, progression de la coche et mode réduit. Analyse Flutter sans problème.
- Vérification physique effectuée sur Tom’s iPhone le 11 septembre : confirmation Séries capturée (cercle, coche et « Vu ! »), passage à l’épisode suivant puis Annuler. Retour vérifié à S23 E02 et 1155/1177 épisodes ; aucun visionnage de test conservé.
- Films : contrôle visuel du bouton. La couleur déléguée Lottie restait verte malgré la teinte demandée ; test pixel en échec (rouge 69 au lieu de 229), corrigé avec ColorFiltered. Test rendu et 13 tests de boutons/commandes passent, analyse sans problème. Contraste clair vérifié sur iPhone après hot reload. Le parcours d’enregistrement Films est couvert par les tests, sans modifier la bibliothèque utilisateur sur le téléphone.

Build iOS debug signé installé. Les lancements Flutter LLDB et Xcode ont bloqué ; lancement debug réussi via MobAI, puis connexion Flutter attach explicite pour le rechargement à chaud. MobAI arrêté après les contrôles ; session Flutter attach conservée pour travailler en direct.

Captures : `/tmp/nitrate-check-native/series/sheets/sheet_01.jpg` et `/tmp/nitrate-check-native/films-contrast-fixed.png`. L’enregistrement peu fréquent permet de vérifier les états, pas de mesurer la fluidité à 60/120 Hz.

## Corrections après retour utilisateur

- Le logo de rafraîchissement apparaissait dès `ScrollStartNotification`, y compris sur pointer-down immobile. Test reproduit en échec avant correction. Le statut drag ne rend maintenant le logo visible qu’après 24 points de tirage réel ; armement, lancement, limite de durée et gestion d’erreur conservés. Toucher immobile, scroll montant et tirages réels (physiques bouncing/clamping) couverts.
- La clé dépendant de `confirmed` démontait le lecteur Lottie précisément au début de la coche. Suppression de cette clé ; test d’identité du lecteur observé en échec puis réussi pour garantir sa conservation pendant la transition.
- 38 tests ciblés réussis, puis 8 tests de rafraîchissement incluant les 2 nouveaux gestes réels (40 tests distincts au total). Analyse des 6 fichiers sans problème.
- Corrections chargées par hot reload sur l’iPhone. Trois touchers immobiles ne montrent plus le logo. Action Séries suivie d’Annuler : Ultimate Beastmaster retrouvé à S01 E02, 1/29. La capture de faible fréquence ne permet pas de juger chaque image de la coche. MobAI arrêté après contrôle.
