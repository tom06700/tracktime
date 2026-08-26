# Nitrate

Suivi de séries/films, 100 % local, métadonnées TheTVDB.

**Le développement ne porte que sur l'app Flutter (iOS et Android).** Les
pushs vont directement sur `main`, sans PR.

## Layout

- `app/` — application Flutter (iOS et Android). Seul contenu du dépôt avec la
  configuration de build.

Les cibles web ont été supprimées : ancienne app vanilla à la racine, build
Flutter commité dans `flutter/`, et dossier plateforme `app/web/`. Tout reste
récupérable dans l'historique git si besoin.

## Livraison iOS

`codemagic.yaml` à la racine : build signé + envoi TestFlight, déclenché à la
main depuis Codemagic. Le numéro de build vient du compteur Codemagic.

Prérequis déjà en place côté Codemagic : clé App Store Connect
« chez-nous-asc », certificat de distribution partagé au niveau de l'équipe,
et profil « Nitrate App Store » importé dans Code signing identities.
`ios_signing` récupère les profils depuis ce magasin, pas depuis Apple : un
profil créé sur developer.apple.com doit y être importé pour être vu.

## Spécificités du conteneur Claude Code (remote)

- SDK Flutter : télécharger le tar.xz stable depuis
  storage.googleapis.com/flutter_infra_release, extraire dans `$HOME/flutter`.
- `flutter test` passe tel quel depuis Flutter 3.47 : le contournement qu'on
  documentait ici (vendorer le package `sqlite3` via `pubspec_overrides.yaml`
  parce que son hook natif échouait, github.com étant bloqué par le proxy)
  n'est plus nécessaire. S'il le redevenait, ne jamais commiter l'override :
  `pubspec.lock` référencerait un chemin local.
- Pas de simulateur iOS ici (conteneur Linux). Pour un contrôle visuel, passer
  par des tests golden plutôt que par un build web, désormais supprimé.
