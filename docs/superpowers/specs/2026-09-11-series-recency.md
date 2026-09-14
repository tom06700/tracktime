# Ordre de reprise des séries

La grande carte, le carrousel et la vue d’ensemble partagent désormais `SeriesFeed.resumeQueue` : dernier visionnage décroissant, puis séries jamais commencées par ajout décroissant. L’identifiant départage les dates identiques. Les sections historiques du feed gardent leur séparation récent/ancien ; leur concaténation ne dicte plus l’ordre de reprise.

`NextUp.lastWatchedAt` distingue un visionnage d’un ajout. Quand le premier élément ou sa dernière date de visionnage change, la grande carte reprend la priorité du fil. Une simple modification de métadonnées conserve la sélection manuelle, et la confirmation en cours termine sur la carte retenue.

Validation : 38 tests réussis dans feed_test et shows_screen_test ; analyse ciblée sans problème ; compilation profile réussie et installation iPhone. Deux régressions reproduites avant correction : ajout récent devant visionnage et égalités non déterministes. Test de réactivité avec sélection manuelle, synchronisation des métadonnées puis nouveau visionnage.

Contrôle physique : même ordre en grande carte/carrousel et vue d’ensemble. Ultimate Beastmaster, One Piece, Koh-Lanta, American Dad! apparaissent en premier. L’historique indique Ultimate Beastmaster S01E01 vu le 11 septembre 2026 après One Piece S23E03 : sa première place découle de cette date existante. Aucun visionnage modifié pendant ces essais. Automatisation arrêtée après validation.
