# Audit préalable et portage global — en cours

Base : main d6a4763, avec les trois commits de la PR #10 (logo ruban approuvé,
carte entière cliquable, résumé automatique pour les épisodes vus). La PR #11
apporte uniquement les références. Aucune fusion dans main autorisée pour ce lot.

Le ZIP a été extrait et les empreintes des sept références contrôlées contre le
manifeste. `index.html` a été ouvert dans une session Brave isolée. Les références
06 et 07 ont été capturées à 390 px avec la police Inter embarquée : série,
épisodes, accès direct, film, Explorer, profil. Les images de démonstration ne
sont pas copiées dans les assets du produit. La planche du logo n’est pas une icône.

## État préexistant à préserver

- Intro : objets Fluent Emoji fournis, envol continu, départ et CTA animés,
  réduction du mouvement, suspension en arrière-plan et zones sûres corrigées.
- Notifications : vraie permission native ; absence de service d’envoi clairement
  indiquée. Aucun faux dialogue système issu du prototype.
- Boutons : familles Soft Check, Attach, Next Up, Surprise, Glide et CTA blanc.
  Les débordements des capsules ont été corrigés dans les PR précédentes.
- À reprendre : données locales, image de la vraie œuvre, sauvegarde réelle avant
  confirmation, carte entièrement cliquable et bouton vu indépendant.
- Épisode : numéros officiels, navigation sans écriture, sélection virtualisée,
  rattrapage confirmé et annulable qui protège les visionnages antérieurs.
- Série : ajout explicite avant suivi ; cible cochée d’abord puis proposition
  facultative des épisodes intermédiaires, différente du « Jusqu’ici » épisode.
- Film : un visionnage unique ; suppression avec confirmation.
- Explorer : traduction et classement des résultats, filtres, requêtes tardives
  ignorées, erreurs par source, ajout distinct de l’ouverture.
- Profil : statistiques, genres, activité, records, trophées, historique,
  bibliothèque, suggestions parmi la collection, import/export et réglages.

## Écarts identifiés avant portage

Fiche série héritée : onglets soulignés, pas de reprise, accordéons créant toutes
les lignes, pas de filtre non vus ni accès direct, spéciaux ignorés, action de
saison non attendue. Fiche film héritée : proportions et commandes différentes.
Explorer hérité : résultats en lignes et découvertes horizontales. Profil hérité :
fond animé et avatar central, prénom/avatar sauvegardés séparément immédiatement.

## Décisions de portage

06 prime sur la mini-fiche de 07. Les nouvelles surfaces utilisent les valeurs
CSS du pack, en widgets Flutter. Les grands titres restent les vrais noms ; pas
de slogan ni de sous-titre Dune inventé pour une autre œuvre. Les données absentes
sont signalées ou omises. Les épisodes spéciaux connus sont conservés comme saison
0, les trous et numéros à quatre chiffres restent officiels. La sélection est
virtualisée. Les informations supplémentaires du profil sont conservées sous le
bloc principal. L’identité est enregistrée en un document local lors de la
validation ; les anciennes clés restent lisibles pour préserver le profil.

## Vérification restante

Portage en cours : ce fichier ne certifie aucune validation native. Flutter local
ne s’exécute pas sur ce Mac avec le SDK courant ; analyse, tests et captures de
widgets passent par GitHub Actions. Captures et vidéos à produire et comparer ;
fluidité réelle, masques du lanceur et splash sur appareil restent à contrôler.
