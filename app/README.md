# TrackTime (Flutter)

App iOS/Android de suivi de séries et films — données 100 % locales (SQLite),
métadonnées via l'API TMDB.

> Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB.

## Démarrer

```bash
cd app
flutter pub get
dart run build_runner build   # génère lib/db/database.g.dart (drift)
flutter run
```

## Architecture

- **État** : Riverpod (`lib/providers.dart`)
- **Base de données** : drift (SQLite) — schéma dans `lib/db/database.dart`
  - `shows` : séries suivies (id TMDB, affiche, nb d'épisodes, durée…)
  - `watched_episodes` : un enregistrement par épisode vu (équivalent des clés
    `S3E7` de la version web)
  - `movies` : films, `watched_at` null = watchlist
- **Écrans** : `lib/screens/` — Séries, Films, Stats, Import (onglets)
- **Thème** : `lib/theme.dart` — palette sombre ambre/teal reprise de la
  version web (`index.html` à la racine du repo)

## Feuille de route

1. ✅ Squelette 4 onglets + modèle de données SQLite
2. ✅ Import du backup JSON de la version web + export TV Time (CSV/JSON),
   réglages (clé API TMDB, attribution)
3. ⬜ Recherche/ajout TMDB, détail série, coche épisodes
4. ⬜ Stats avancées
5. ⬜ Polish (icône, splash, politique de confidentialité) → TestFlight → stores
