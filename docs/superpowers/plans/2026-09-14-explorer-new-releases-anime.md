# Explorer : nouveautés et animés

Direction demandée : privilégier de nouvelles œuvres plutôt que les classiques
déjà connus, avec quatre filtres Tout / Séries / Films / Animés dans Explorer.
Les autres onglets gardent leur organisation.

- [x] Charger les deux années calendaires les plus récentes ; vérifier les
  années localement car le filtre films TheTVDB déborde sur d'autres années.
- [x] Exclure les sorties futures et titres déjà présents dans la collection.
  Présenter les œuvres de l'année courante avant celles de l'année précédente,
  avec le classement de popularité à l'intérieur de chaque année.
- [x] Ajouter des sélections dédiées au genre Anime, demandé via /genres,
  et filtrer la recherche à partir des métadonnées, jamais du titre.
- [x] Préserver l'ajout, les fiches, la recherche asynchrone et Tout voir.
- [x] Tester dates/statuts, classement, classification, petits écrans et filtres.
- [x] Compiler, installer et lancer sur iPhone ; vérification UI MobAI indisponible (voir ci-dessous).

Source vérifiée : https://github.com/thetvdb/v4-api/blob/main/docs/swagger.yml
Sondes réelles du 14 septembre : /movies/filter?year=2026 contient des années
2006 à 2026 ; genres présents dans /search ; dates firstAired dans /series/filter.
Les films indiquent le statut Released sans date complète dans le filtre.

Validation : 79 tests ciblés réussis (découverte, réseau, parsing, Explorer et
navigation). Analyse ciblée sans problème. Vérification réelle du client :
985 séries récentes, 646 films récents, 388 séries animées et 70 films animés
avant exclusion de la collection et limitation à vingt affiches. Recherche
One Piece Animés : 39 résultats, série 81797 présente, adaptation 392276 absente.
Les titres japonais visibles demandent leur traduction française puis anglaise
paresseusement ; le nom d'origine reste le repli si aucune traduction n'existe.

Limite de validation UI : MobAI répond HTTP 402 device_limit_reached sur l’iPhone.
Les vérifications de données et widgets restent disponibles ; aucun test
visuel matériel n’est revendiqué. Build iOS profile réussi.

Installation et lancement confirmés par devicectl, sans automation, le 14 septembre.

Correction complémentaire : toutes les affiches de découverte demandent le titre
français, y compris les titres anglais. Le nom d’origine reste disponible si la
traduction française manque ; repli anglais pour les noms en écriture CJK.
Chargement paresseux et cache conservés. 27 tests Explorer/parsing réussis.
Aucun moteur de recommandation par affinité n’est encore implémenté : ordre
par année puis score, avec exclusion des œuvres déjà dans la collection.
