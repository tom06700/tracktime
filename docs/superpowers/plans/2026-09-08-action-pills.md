# Pastilles déployées — intégration native

**Goal:** Reproduire la variante Pastilles déployées validée sur localhost dans les menus pertinents de Nitrate.
**Architecture:** PopupRoute modale ancrée au bouton, pastilles arrondies en cascade, bouton de fermeture lilas, barrière floutée. Composant commun indépendant des actions métier, adaptateur MovieActionsMenu commun aux cartes, historique et fiches. Les callbacks existants continuent de gérer les données et confirmations.
**Tech Stack:** Flutter, Riverpod, Drift. Aucune dépendance ajoutée.

- [x] Composant `app/lib/widgets/action_pill_menu.dart` : route, disposition bornée par les zones sûres, navigation clavier, réduction des animations, sélection unique, fermeture extérieure/retour.
- [x] Adaptateur `app/lib/movies/widgets/movie_actions_menu.dart` : état vu/à voir, retrait, paramètres de taille pour carte et fiche. Export de MovieAction conservé depuis movie_poster_card.dart pour compatibilité.
- [x] Intégration dans movie_poster_card.dart, movie_history_screen.dart et movie_detail_screen.dart. Ajouter un emplacement de widget de gestion dans ValidatedDetailHero. Dans l’historique, remplacer le bouton de restauration par les deux actions proposées dans l’aperçu ; confirmer le retrait avec conservation d’une issue Annuler.
- [x] Tests ciblés : sélection et annulation sans ouvrir la carte ; restauration historique ; confirmation de retrait ; ancrage aux quatre coins avec texte agrandi ; fermeture Échap/retour ; aucune animation si réduction activée. Analyse Flutter et tests Films existants.
- [x] Capturer et inspecter le rendu Flutter local ; compiler la version iOS debug signée. MobAI absent de cette session : aucun test tactile automatisé sur le téléphone.
- [x] Installer et relancer sur iPhone après reconnexion : version debug lancée sur Tom’s iPhone, fichiers synchronisés et service Dart VM disponible. Session Flutter conservée pour le hot reload.

Périmètre : les actions directes uniques des fiches Série restent directes. Les sélecteurs de saison, réglages et feuilles de rattrapage ne sont pas des menus d’actions comparables.

Validation : analyse Flutter sans anomalie ; 35 tests ciblés réussis, dont le rendu natif. Vérification des quatre coins à 100 %, 200 % et 300 % de taille de texte, avec défilement des pastilles lorsque nécessaire. Capture inspectée : `app/build/films-preview/action-pills-native.png`.

Compilation iOS debug signée réussie (`flutter build ios --no-pub --debug`), sortie `app/build/ios/iphoneos/Runner.app`.
