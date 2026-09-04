# Nitrate

Application Flutter iOS/Android de suivi de séries et de films. Bibliothèque
et historique stockés localement dans SQLite (Drift), métadonnées TheTVDB.

## Développement

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

La configuration TheTVDB se trouve dans `lib/tmdb/tvdb_config.dart`.
Le dossier `tmdb/` conserve son nom historique ; le client actif est TheTVDB.
Après modification du schéma Drift : `dart run build_runner build`.

## Parcours

- **Séries** : prochain épisode, reprise, historique, accès direct à la
  bibliothèque. Calendrier de 90 jours avec dépliage des épisodes plus lointains.
- **Films** : liste à voir, films vus et sorties ; les affiches ouvrent les fiches.
- **Explorer** : recherche, filtres séries/films, découverte et ajout. Une rubrique
  indisponible affiche une action de reprise.
- **Fiche série** : informations, ajout/retrait, saisons. Le titre d'un épisode
  ouvre sa fiche ; la coche change le statut. Le rattrapage conserve sa confirmation.
- **Fiche film** : informations, ajout, marquage vu/non vu et retrait confirmé.
- **Fiche épisode** : navigation dans la saison, progression, accès à la série,
  fermeture visible et reprise après erreur.
- **Profil** : identité, statistiques, genres, activité, trophées et liste de
  lecture. Films et séries ouvrent leur fiche, y compris après un tirage « ce soir ».
- **Bibliothèque** : recherche, filtres et tri ; remise à zéro des filtres et accès
  au catalogue si vide.
- **Historiques** : consultation des fiches et remise à voir.
- **Import / Réglages** : restauration, export et suppression confirmée.

L'état des onglets est conservé par `IndexedStack`. Les animations des onglets
cachés sont suspendues. Thème partagé dans `lib/theme.dart`, navigation dans
`lib/router.dart` et `lib/shell.dart`.

## Captures de contrôle

```sh
NITRATE_AUDIT=1 \
NITRATE_AUDIT_FONTS="$FLUTTER_ROOT/bin/cache/artifacts/material_fonts" \
flutter test test/visual_audit_test.dart --timeout 20m
```

Les PNG et le relevé d'exceptions se trouvent dans `build/audit/`. Ce sont des
rendus des widgets Flutter avec des données de test et des images synthétiques,
à une taille de téléphone. Ils ne remplacent pas une recette sur iPhone/Android,
notamment pour les gestes système, le clavier et le partage natif.

La CI standard exécute l'analyse et les tests. Le workflow de captures sur la
branche de revue UI exporte également les PNG comme artefact GitHub Actions.
Le build iOS signé et l'envoi TestFlight sont configurés dans `../codemagic.yaml`.

Metadata provided by TheTVDB. Nitrate n'est ni approuvé ni certifié par TheTVDB.
