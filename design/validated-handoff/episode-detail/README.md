# Fiche épisode Nitrate — référence validée, pack 03

L’utilisateur a validé cette proposition et demandé sa transmission à sa session Codex pour intégration Flutter. Cette PR livre une référence, pas un portage Flutter. Préserver les travaux des packs intro, boutons et notifications.

## Point de départ vérifié
Dépôt tom06700/tracktime, branche main, commit c9a1840cb0710dd63dfb25b13ca69786882d57d9.
Lire l’état actuel avant d’intégrer si le projet a évolué.

- `app/lib/screens/episode_detail_screen.dart` : EpisodeSheet, _EpisodePage, _Hero, carrousel PageView par saison, fermeture verticale/bouton, accès série, _toggleWatched, _markUpTo.
- `app/lib/router.dart` : /episode/:showId/:season/:episode, route modale non opaque ; /show/:id.
- `app/lib/tmdb/tvdb.dart` : seriesEpisodes, numérotation officielle season/episode ; name, overview, image, aired, runtime nullable. Aucun champ de numéro absolu ni découpage en arcs dans cette normalisation.
- `app/lib/providers.dart` : watchedEpisodeProvider (inclut watchedAt), watchedKeysProvider.
- `app/lib/db/database.dart` : setEpisodeWatched, setEpisodeUnwatched, markWatchedUpTo, setEpisodesWatched.
- `app/lib/series/catch_up.dart` et `series/widgets/catch_up_sheet.dart` : autre logique de rattrapage, utilisée depuis la fiche série. Ne pas la confondre avec « Jusqu’ici » de la fiche épisode.

## Ouvrir la référence
`reference.html` contient le fragment exact validé (HTML/CSS/JS et affiche embarquée).
`preview.html` ajoute seulement un document autonome et les icônes Lucide incorporées. Ouvrir ce fichier dans un navigateur pour tester.
Inter vient de Google Fonts ; police système en repli hors connexion. Pas de vraie donnée ni de requête API dans cette démo. Utiliser les assets et fontes du projet lors du portage.

## Design validé
Conserver l’image et le fondu cinématique, la surface carbone, le bouton lime Soft check, les accents lilas et Next up. Reprendre les valeurs CSS, courbes et keyframes de la référence.
Le numéro devient une capsule compacte « ÉP. 1155 » ; le titre reste indépendant et peut occuper plusieurs lignes. Gérer quatre chiffres et davantage avec contraintes de largeur/texte, sans couper le numéro.
Séparer numéro officiel, saison et position dans la liste : « 1155 sur 1200 » est un index de carrousel, pas une identité métier.
Conserver la présentation native en feuille modale, fermeture au geste vertical, retour système et balayage horizontal dans une saison. Le prototype ne reproduit pas toute la mécanique native.
Le bouton One Piece du prototype ouvre un simple état illustratif ; en Flutter il doit utiliser la vraie route série.
Marquer vu ne change pas d’épisode. Suivant/précédent ne change pas le visionnage. Les bornes suivent la liste officielle triée, jamais numéro + 1 supposé présent.
Afficher runtime/date seulement si présents, ou un état sobre comme dans la démo. Afficher la vraie date watchedAt quand vu. Ne pas inventer votes, casting ou équipe : non alimentés par le mapping courant.
Résumé masqué par défaut et révélation explicite proposée. Sans résumé : « Pas de résumé disponible. ».

## Longues séries
« Tous les épisodes » ouvre une liste courte, paginée dans le prototype, et un accès direct par numéro dans la saison. Flutter peut utiliser un builder/liste virtualisée ; ne pas construire 1200 widgets à l’ouverture.
Valider l’existence du numéro recherché dans la liste, pas uniquement une plage numérique. Garder les saisons officielles ; pas d’arcs inventés, pas de conversion en numérotation absolue sans source explicite.
La fixture synthétique contient une saison de 1200 épisodes et démarre sur 1155. Ce n’est PAS le découpage réel de One Piece. Durées, titres, résumé, dates et progression sont fictifs. L’affiche est une illustration de série, pas un still d’épisode. En production, utiliser le vrai still et le repli MediaImage prévu.

## « Jusqu’ici » : portée et nouveautés proposées
Le code actuel _markUpTo appelle syncShowEpisodes puis markWatchedUpTo. La base marque les épisodes connus des saisons antérieures ET ceux de la saison courante jusqu’à la cible incluse. Cela peut aussi inclure des spéciaux présents en base ; inspecter cette portée et la rendre explicite, ne pas appliquer en silence la règle différente de findMissingEpisodesBetween (même saison, hors spéciaux).
La référence ajoute une confirmation avec un nombre d’épisodes concernés puis une annulation. Ces deux éléments sont des AMÉLIORATIONS proposées et validées visuellement, pas des fonctions déjà implémentées.
Calculer le nombre et l’ensemble exact depuis les données réellement synchronisées avant confirmation ; si cet ensemble évolue, ne pas appliquer un lot différent de celui confirmé.
Pour annuler, retirer uniquement les visionnages créés par cette opération. Préserver les anciennes dates et les autres visionnages. Utiliser une transaction/identités d’opération adéquates dans le code réel ; ne pas copier le Map simplifié de la démo.
Succès et animation dépendent d’une écriture réussie ; gérer erreur, double appui, démontage et navigation en cours d’opération.

## Incohérence existante à traiter explicitement
La fiche épisode _toggleWatched ajoute la série via addShowFromTvdb avant de marquer vu, tandis que ShowDetailScreen._requireFollowed exige un ajout explicite à la liste. La référence illustre une série DÉJÀ suivie et ne tranche pas ce désaccord produit. Conserver le comportement attendu de la session en cours ou le signaler ; ne pas prétendre que les deux écrans font déjà la même chose.

## Vérification du portage
Respecter réduction du mouvement, contraste, texte agrandi, safe areas, sémantique des contrôles, lifecycle des animations, et état chargement/erreur de la fiche.
Tester numéro 1155/1200, numéro introuvable, trous dans la numérotation, première/dernière page, saison 0 si accessible, dates/résumé/image absents, navigation sans écriture, marquer/décocher, confirmation et annulation du lot.
Comparer le rendu à la référence sur petit écran et pendant l’animation, pas seulement flutter analyze.
Déjà vérifié ici : tests DOM simulés de la référence pour numéro 1155 et 1200, 10 lignes rendues, navigation sans mutation, confirmation/annulation préservant les 1144 visionnages initiaux, résumé absent, fermeture/réouverture.
Pas de vérification de rendu navigateur ou de performance sur appareil, pas de test Flutter effectué dans cette transmission.

## Crédits
Affiche de démonstration : https://www.media-paten.com/sprecherkartei/synchronsprecher-filme/One-Piece/
Ne pas la considérer comme un asset libre de droits pour production. Réutiliser les fournisseurs du projet.
Icônes Lucide 0.468.0 dans l’aperçu : licence jointe. Inter à intégrer selon le dispositif et les licences déjà présents dans le dépôt.
