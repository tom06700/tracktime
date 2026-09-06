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

## Ajustements issus de la revue

- Bouton Attach compact recalculé pour garder « Ajouté » entier ; variante
  marque-page autonome pour la fiche film. Onglets denses et filtres lilas des
  références 06/07, sans modifier les identifiants de navigation.
- Titres et commandes en Inter. Cadrage vertical des images à 30/33 %, zoom et
  révélation à 900/1 100 ms ; hauteur du hero mesurée pour les titres longs.
- Ajout série/film explicite, séparé du visionnage. L’ancienne auto-inscription
  depuis une fiche épisode est remplacée par une proposition d’ajout confirmée.
  Annuler laisse la base intacte ; ajouter ne marque aucun épisode ou film vu.
- Reprise sur le premier épisode régulier non vu déjà diffusé si la date est
  connue ; spéciaux consultables séparément, puis proposés si aucun régulier ne
  reste. Numéros officiels, sans comblement artificiel des trous.
- Saison complète : confirmation avant passage vu/non vu ; marquer vu conserve
  les dates existantes. Le rattrapage facultatif et celui de la fiche épisode
  gardent leurs portées respectives.
- Historique du profil réunit films et épisodes et ouvre leurs fiches ; les
  historiques spécialisés et leurs actions restent accessibles via les stats.
- Identité locale enregistrée en un document, lecture des anciennes préférences
  conservée. Les préférences mal formées ne remplacent pas une identité valide.

## Preuves reproductibles

Le workflow Flutter produit une galerie `index.html`, les captures PNG originales
et 13 MP4 dans l’artefact `nitrate-modern-reference`. Les séquences couvrent
l’envol continu et le départ, les quatre familles de commandes, les déplacements
aux extrémités des capsules, la confirmation épisode et la fiche série.
`scripts/encode_motion_audit.py` encode les PNG selon le pas temporel des tests.
Ce sont des animations Flutter échantillonnées, pas une mesure de FPS native.
Les captures du navigateur sont des références HTML, pas une cible web de l’app.

Écarts volontaires avec les fixtures : œuvres, compteurs, dates et durées réels ;
logo ruban approuvé à la place du simple texte ; onglet À venir, bibliothèque,
réglages et statistiques supplémentaires conservés ; navigation des fiches
plein écran conservée ; avatars existants conservés. Les 6 lignes de la démo
sont remplacées par une liste virtualisée. Les titres longs peuvent augmenter
la hauteur du hero. Aucun sous-titre propre à Dune n’est inventé pour un autre film.
L’autorisation de notifications utilise le canal natif ; aucun service d’envoi
n’est ajouté par cette refonte. Les copies restent explicites à ce sujet.

La comparaison a révélé et fait corriger le texte coupé d’Attach, les hauteurs
excessives des onglets 06/07 et les arrière-plans masquant les effets tactiles.
Les vidéos ont été examinées par séquences de frames : envol jusqu’au bord haut,
déplacement et retour de Next Up, capsule restant dans son rail. La revue sur
appareil doit encore vérifier la fluidité, le clavier, VoiceOver/TalkBack, le
vrai dialogue de permission, les masques des lanceurs et le splash.
