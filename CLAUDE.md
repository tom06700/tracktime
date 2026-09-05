# Nitrate

Suivi de séries/films, 100 % local, métadonnées TheTVDB.

**Le développement ne porte que sur l'app Flutter (iOS et Android).** Les
changements sont regroupés en PR cohérentes vers `main`. La CI vérifie les
branches et PR ; après fusion, Codemagic construit et publie sur TestFlight.

## Layout

- `app/` — application Flutter (iOS et Android). Seul contenu du dépôt avec la
  configuration de build.

Les cibles web ont été supprimées : ancienne app vanilla à la racine, build
Flutter commité dans `flutter/`, et dossier plateforme `app/web/`. Tout reste
récupérable dans l'historique git si besoin.

## Livraison iOS

`codemagic.yaml` à la racine : build signé + envoi TestFlight automatique sur
push dans `main` pour les changements de l'app ou du workflow. Les changements
uniquement documentaires sont exclus. Un push direct dans `main` déclenche
aussi le workflow ; utiliser les PR pour regrouper les évolutions. Le numéro
de build vient du compteur Codemagic. Analyse et tests bloquent la publication
en cas d'échec. Le lancement manuel reste disponible.

La liaison nécessite un webhook GitHub actif : dans l'application Codemagic,
onglet Webhooks, utiliser « Update webhook » si nécessaire. Vérifier ensuite
la livraison du webhook, le build `ios-testflight` et son arrivée dans TestFlight.
Une configuration YAML seule ne confirme pas que cette liaison est active.

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

## Autorisation de livraison

Le propriétaire autorise la fusion dans `main` des PR terminées, vérifiées et
regroupant un lot cohérent, sans nouvelle confirmation à chaque fois. Les
limites de validation visuelle doivent rester explicites ; la CI verte ne
constitue pas une validation artistique. Éviter les petites livraisons répétées
qui consomment inutilement des minutes Codemagic.
