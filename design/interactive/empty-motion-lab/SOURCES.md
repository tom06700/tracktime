# Nitrate — nouvelle recherche de mouvement, 14 septembre 2026

Références consultées en ligne :
- https://www.rive.app/use-cases : animations interactives et états vides.
- https://www.rive.app/blog/how-state-machines-work-in-rive : séparation des
  états, interactions et transitions. Inspiration de comportement, pas de fichier Rive copié.
- https://transitions.dev/ : démos inspectées dans Brave, variation des rythmes,
  révélation, transformation, retour au repos. Aucun contenu Pro téléchargé.
- https://www.tonyward.dev/articles/roaming-shapes : mouvements secondaires
  discrets, applicables à plusieurs états vides. Article lu via recherche web.
- https://animations.dev/ : principes de motion UI, articulation des transitions.
- https://threejs.org/docs/ : rendu physique et environnement studio.

Trois créations originales, procédurales, réalisées dans sculptures.js :
- Le passage : arche extrudée, porte sur charnière, poignée métallique,
  intérieur éclairé et lumière au sol synchronisée à l’ouverture.
- Le rendez-vous : trois anneaux de matière et satellites sur trajectoires,
  ouverture puis réalignement avec vitesses nulles aux extrémités.
- Le fil des histoires : maillage d’un ruban déformé, faces lilas et pêche,
  variation de torsion, de largeur et de déploiement.

Boucle de 7 secondes avec mouvement principal et temps de repos ; pilotage
manuel par curseur, pause, ralenti, réactions pointeur et clavier. Les
illustrations précédentes, affiches, éventails, œil et clap ne sont pas repris.
Logo, typo et contexte de navigation restent ceux de Nitrate.

Affinage du Passage : porte toujours entrouverte (41° minimum), respiration
sinusoïdale sur 7 secondes avec lumière intérieure et au sol synchronisée.
Position et vitesse se raccordent au bouclage. Survol, focus et toucher
élargissent doucement l’ouverture sans remettre la boucle à zéro.
Le réglage de réduction des animations désactive la lecture automatique.

Ce prototype utilise WebGL/Three.js. Il n’est ni un fichier Lottie ni une
intégration Flutter. Le format final et les performances sur téléphone devront
être décidés et validés après sélection du concept. Aucun changement à la
collection réelle. Les interactions de recherche sont une simulation locale.

Lancement : python3 -m http.server 8768 --bind 127.0.0.1
Dépendance : npm ci (version verrouillée, Three.js licence MIT).

## Vérifications dans Brave

- Rendu des trois sculptures inspecté à 3 s et en fin de cycle, en vue
  d’ensemble et en grande taille ; modèles et matériaux visibles.
- Curseurs individuels, pause, ouverture des trois états et recherche locale
  vérifiés par l’interface ; retour depuis le formulaire sans erreur.
- En pause, rendu WebGL seulement lorsqu’un paramètre ou le pointeur change.
  Onglet masqué : rendu suspendu. Résolution plafonnée à 2×.
- Syntaxe JavaScript vérifiée par node --check. npm : aucune vulnérabilité
  rapportée à l’installation. Pas de mesure FPS sur téléphone.
- Passage : raccords de position et de vitesse vérifiés numériquement dans
  les trois états, lumière présente et porte ouverte sur tout le cycle.
  Rendu à 0 s et ouverture au toucher inspectés dans Brave ; le toucher
  conserve la position du curseur lorsque la lecture est en pause.

## Traversée interactive du Passage

Références supplémentaires :
- https://tympanus.net/Development/3DPortalCard/ : scène inspectée dans Brave,
  profondeur et encadrement d’un univers distinct, sans reprise de son modèle.
- https://discourse.threejs.org/t/how-to-create-a-portal-effect-or-how-to-fake-it/57752/5 :
  principe de masque et raccord vers une scène plein écran.
- https://tympanus.net/codrops/2026/05/27/whooshes-snaps-and-shaders-adrien-vanderpotte-and-the-feeling-of-the-interface/ :
  recherche sur les comportements optiques et la navigation spatiale.

Implémentation originale : caméra perspective, ouverture articulée, masque DOM
calculé à partir des points de l’arche projetés par la même caméra. Explorer
reste la même surface pendant et après la traversée ; aucune capture échangée
au dernier instant. Timeline 2,2 s, ralentissement global, pause/curseur dédiés.
La porte reste entrouverte au repos ; le clic lance désormais la navigation.
Retour, rejeu, recherche et fiches de démonstration locales. Aucun appel aux
comptes ni aux collections. Réduction des animations : accès sans travelling.
Les deux sculptures masquées ne sont plus rendues en mode Passage isolé.

Affiches publiques téléchargées via l’API TVmaze pour la destination uniquement :
- Severance : https://www.tvmaze.com/shows/44933/severance
- The Last of Us : https://www.tvmaze.com/shows/46562/the-last-of-us
- Shōgun : https://www.tvmaze.com/shows/37336/shogun
Ces affiches restent la propriété de leurs ayants droit ; usage dans l’aperçu local.

Vérification géométrique : expansion du canvas de 390×337 à 390×844,
projection apparente conservée à moins de 1e-8 pixel pour les points contrôlés.
Inspection Brave du repos, de l’ouverture (0,65 / 0,8 s), de l’approche (1,05 s)
et du franchissement (1,35 s). Aucun benchmark mobile effectué.

Parcours vérifié dans Brave : clic sur Explorer → arrivée à 2,2 s et focus sur
le titre ; recherche « Shōgun » → un résultat ; retour → porte entrouverte ;
activation de la porte avec Entrée → arrivée complète. Syntaxe JS revérifiée.
La branche réduction des animations est implémentée, sans test du réglage OS.
