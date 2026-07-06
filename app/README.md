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
- **Écrans** : `lib/screens/` — onglets Séries, Films, Explorer, Profil.
  Nav bar « liquid glass » flottante (`lib/widgets/liquid_glass_nav_bar.dart`,
  Scaffold en `extendBody`). L'import n'est plus un onglet : il vit dans une
  section des Réglages (et un raccourci du Profil) via `ImportPage`.
- **Profil** : identité locale (nom + avatar emoji, `lib/profile/`), chiffres
  de visionnage et gestion des données (export/backup, `lib/backup/`)
- **Thème** : `lib/theme.dart` — palette sombre ambre/teal reprise de la
  version web (`index.html` à la racine du repo)

## Feuille de route

1. ✅ Squelette 4 onglets + modèle de données SQLite
2. ✅ Import du backup JSON de la version web + export TV Time (CSV/JSON),
   réglages (clé API TMDB, attribution)
3. ✅ Recherche/ajout TMDB (multi), détail série (saisons + épisodes,
   coche unitaire et par saison), suppression
4. ✅ Page Profil v1 : identité locale (nom + avatar), chiffres de
   visionnage, export/sauvegarde des données
5. ⬜ Polish (icône, splash, politique de confidentialité) → TestFlight → stores
