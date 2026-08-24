# Nitrate

Suivi de séries/films, 100 % local, métadonnées TheTVDB.

**Le développement ne porte plus que sur l'app Flutter (iOS, livrée par
TestFlight via Codemagic).** Les deux cibles web ci-dessous sont gelées : ne
plus les reconstruire ni les faire évoluer. Les pushs vont directement sur
`main`, sans PR.

## Layout

- `index.html` — version web historique (vanilla JS + localStorage), gelée,
  encore sous l'ancien nom TrackTime.
- `app/` — application Flutter (iOS/Android, cible stores). Source de vérité
  pour la suite du développement.
- `flutter/` — ancien build web de l'app Flutter (artefacts commités), gelé.
  Ne plus le régénérer : la livraison passe par TestFlight.

## Livraison iOS

`codemagic.yaml` à la racine : build signé + envoi TestFlight, déclenché à la
main depuis Codemagic. Le numéro de build vient du compteur Codemagic.

## Notes web (drift/sqlite) — pour mémoire, cibles gelées

- `app/web/sqlite3.wasm` doit correspondre à la version du package Dart
  `sqlite3` (source : package npm `sqlite3-web`, généré depuis le même repo).
  Un mismatch donne `LinkError ... dispatch_xFunc` et un spinner infini.
- CanvasKit est auto-hébergé (config dans `app/web/index.html`), pas de CDN.

## Spécificités du conteneur Claude Code (remote)

- SDK Flutter : télécharger le tar.xz stable depuis
  storage.googleapis.com/flutter_infra_release, extraire dans `$HOME/flutter`.
- github.com est bloqué par le proxy → le hook natif du package `sqlite3`
  (téléchargement de libsqlite3) échoue avec un mismatch de hash. Pour
  `flutter test` : vendorer le package sqlite3 (copie du pub-cache), patcher
  `lib/src/hook/description.dart` (case null → `LookupSystem('sqlite3')`) et
  pointer dessus via `app/pubspec_overrides.yaml` (gitignoré). IMPORTANT :
  retirer l'override + `flutter pub get` avant tout commit, sinon
  `pubspec.lock` référence un chemin local.
