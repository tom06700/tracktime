# TrackTime

Suivi de séries/films, 100 % local, métadonnées TMDB. Déployé sur Vercel
(statique, déploiement auto à chaque push sur `main` — le propriétaire veut
des pushs directs sur `main`, sans PR).

## Layout

- `index.html` — version web historique (vanilla JS + localStorage), servie à
  la racine du site. Ne pas casser : c'est l'app en production.
- `app/` — application Flutter (iOS/Android, cible stores). Source de vérité
  pour la suite du développement.
- `flutter/` — build web de l'app Flutter (artefacts commités), servi sur
  `/flutter/`. Régénéré manuellement, voir ci-dessous.

## Rebuild du build web Flutter (après chaque changement dans app/)

```bash
cd app
flutter build web --base-href=/flutter/
cd ..
rm -rf flutter && cp -r app/build/web flutter
# Allègement (renderer = canvaskit uniquement) :
rm -rf flutter/canvaskit/skwasm* flutter/canvaskit/wimp* \
  flutter/canvaskit/experimental_webparagraph flutter/canvaskit/*.symbols \
  flutter/canvaskit/chromium/*.symbols flutter/drift_worker.dart \
  flutter/drift_worker.js.deps flutter/drift_worker.js.map
```

Si `app/web/drift_worker.dart` ou la version de drift change, recompiler le
worker avant le build :
`cd app && dart compile js -o web/drift_worker.js -O4 web/drift_worker.dart`

## Notes web (drift/sqlite)

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
