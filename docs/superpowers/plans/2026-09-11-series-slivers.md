# Fiche Série : en-tête compact et commandes persistantes

**Objectif validé :** affiche qui se compacte au défilement, titre et retour toujours accessibles, saison et filtre Non vus épinglés au-dessus des épisodes, position conservée après une fiche épisode. Films reste l’étape suivante.

**Architecture :** conserver le CustomScrollView et la liste paresseuse des épisodes. Un SliverAppBar réutilise le visuel existant, sans doubles boutons. Les commandes d’épisodes sont un en-tête persistant dont la hauteur suit le texte et la largeur. Une clé de page par série conserve le scroll ; le route push existant conserve le filtre et la saison. Pas de changement de données.

1. En-tête : extraire la mesure existante de ValidatedDetailHero et permettre de masquer sa navigation intégrée ; créer SeriesDetailSliverHeader avec titre compact, safe area et navigation. Tester la présence du retour après scroll, les longues chaînes et le texte agrandi ; compiler en profile et inspecter l’iPhone.
2. Commandes : isoler la barre saison/filtres dans un composant ; l’épingler sous le titre. Garder les erreurs et états vides dans le flux, préserver les actions de saison. Tester deux tailles, changement de saison à scroll avancé et filtres, puis installer et inspecter.
3. Navigation : tester le scroll d’une longue saison, ouverture d’un épisode et retour à la même position avec la même sélection, sans écriture de visionnage. Analyse ciblée et tests detail_navigation/media_detail. Relevé visuel final et arrêt de MobAI.

Validation : `flutter test --no-pub test/detail_navigation_test.dart test/media_detail_test.dart`, puis `flutter analyze --no-pub` sur les fichiers concernés. Mode profile pour les essais iPhone, car le mode debug avait produit les pauses signalées par l’utilisateur.

## Réalisé et vérifié le 11 septembre 2026

- En-tête compact avec retour, titre et gestion persistants ; visuel développé existant conservé.
- Commandes dans un `PinnedHeaderSliver` à hauteur naturelle. `SliverLayoutBuilder` fournit leur position pour revenir au premier épisode lors d’un changement de saison ou de filtre.
- Navigation testée sur une saison de 1 236 épisodes, avec trous et spéciaux ; retour à la même position sans écriture de visionnage. Petits écrans et texte agrandi couverts.
- 31 tests réussis ; analyse ciblée de cinq fichiers sans problème ; compilation profile signée réussie et installée sur l’iPhone.
- Vérification physique sur Ultimate Beastmaster : titre et commandes épinglés, changement de saison, filtre Non vus conservé, ouverture de S02E06 puis retour. Les lignes 4 à 10 retrouvent exactement leurs coordonnées (épisode 6 à y=379), avec Saison 2 et Non vus toujours sélectionnés. Aucun bouton de marquage utilisé. Automatisation iPhone arrêtée après les essais.
