# Portage natif du pack 03

Le portage est sur `design/episode-detail-native` (PR #9). La PR #8 demeure la source de référence. Aucun changement du pack logo en attente de validation, aucun remplacement des assets de marque et aucune fusion dans main.

## Comportement

- Une seule lecture du catalogue pour la saison ; tri et dédoublonnage par numéro officiel. L’identité saison/épisode est distincte de la position dans le carrousel.
- Une feuille native, retour système et fermeture depuis l’image. Image et contenu défilent ensemble. Les contrôles restent bloqués pendant une écriture ou la préparation d’un rattrapage pour éviter les actions croisées.
- Le résumé n’est construit qu’après révélation explicite. Un changement de page le masque. Date, durée, titre et image proviennent du catalogue ; aucun vote ou crédit fictif.
- Visionnage : bouton Soft check, date réelle et éclair de confirmation après succès. Le visionnage ne change pas de page. Précédent, suivant et accès direct n’écrivent aucun visionnage.
- Accès direct : numéro recherché dans la liste réelle (pas dans une simple plage). Liste virtualisée, y compris pour une saison synthétique de 1200 épisodes. Aucun arc ni numéro absolu inventé.

## Rattrapage et annulation

Après synchronisation, `EpisodeCatchUp.prepare` prend un instantané des épisodes connus et non vus, jusqu’à la cible incluse : saisons précédentes et spéciaux en cache compris. Le dialogue précise cette portée et le nombre exact.

`apply` revalide l’ensemble en transaction. Toute différence exige une nouvelle confirmation ; les dates des épisodes déjà vus ne sont jamais réécrites.

Une table SQLite TEMP attribue les seules nouvelles lignes à un identifiant aléatoire d’opération. Des triggers TEMP sur `main.watched_episodes` invalident cette attribution après suppression, réinsertion ou modification, y compris par SQL direct. `undo` retire uniquement les lignes encore attribuées à ce reçu. Cela protège notamment un épisode décoché puis recoché dans la même seconde. Les reçus sont limités à la session ; aucune migration persistante ni historique utilisateur n’est modifié.

Le comportement antérieur de la fiche épisode est conservé : marquer vu ajoute la série si elle n’est pas suivie. L’ajout explicite demandé dans la fiche série reste un autre parcours.

## Vérification

Tests dédiés : `episode_catch_up_test.dart`, `episode_detail_test.dart`. Captures ciblées avec `NITRATE_EPISODE_AUDIT=1` et revue de la vraie app dans `visual_audit_test.dart`. Les données longues sont synthétiques ; l’illustration de démonstration de la référence n’est pas embarquée en production.

Les tests et captures Flutter ne certifient pas la fluidité, les gestes système et VoiceOver sur iPhone. La validation sur appareil reste à effectuer.
