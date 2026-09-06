# Nitrate — transmission à Codex

## Demande de l’utilisateur
Intégrer fidèlement l’intro et les boutons retenus dans l’application Nitrate, une application de suivi de films et séries, avec des clins d’œil anime/manga. Le projet est Flutter, dépôt tom06700/tracktime, code précédemment observé dans app/lib. Inspecter l’état actuel avant toute modification : le dépôt a pu évoluer. Aucun fichier du dépôt n’a été modifié pendant cette exploration ; les HTML fournis sont des prototypes visuels et comportementaux, pas une implémentation Flutter.

## Sources de vérité et priorité
1. `references/01-intro-envol.html` : référence définitive pour la page d’introduction, sa typographie et son bouton d’entrée. Fond noir pur, petits objets 3D montant dans un flux souple, titre blanc Inter 400/500, bouton blanc cassé « C’est parti ». Garder cette version.
2. `references/02-boutons-modernes.html` : référence des SIX familles de commandes de l’application. Style moderne, doux, tactile, inspiré Wabi/Corner ; carbone, lime, lilas, pêche et corail. Lire ses CSS et keyframes pour les valeurs exactes.
3. `references/03-a-reprendre.html` : référence du module « À reprendre », placement des contrôles et transitions dans un écran cohérent. Ce module combine affiches, progression, navigation et annulation du dernier visionnage.

L’accueil miniature après l’intro n’est qu’une démonstration de transition : la vraie destination doit être l’accueil existant de l’app. Pour les boutons de suivi, privilégier les références 02 et 03, et non ce mini-accueil.

Les anciennes propositions rétro (clap comme forme de bouton, tickets, filmstrips, serif vintage), le premier laboratoire de toggles et les précédentes intros à cartes ne sont pas retenus. Les références ici priment sur l’ancienne direction visuelle, tout en respectant les instructions techniques et de sécurité applicables au dépôt. Il ne faut pas recréer une autre direction artistique.

## Examiner et tester
Décompresser l’archive puis ouvrir `index.html` dans un navigateur. Si nécessaire, servir ce dossier avec `python3 -m http.server 8000` et ouvrir localhost:8000. Les trois aperçus sont séparés pour éviter les collisions de styles. Les fichiers `references/` sont des copies byte pour byte des prototypes retenus ; les pages `previews/` ajoutent uniquement un document HTML et la bibliothèque locale d’icônes.

Vérifier l’envol, l’appui sur « C’est parti », « Passer », « Rejouer », chaque bouton du laboratoire, puis marquer vu et annuler dans « À reprendre ». Tester aussi la réduction des animations.

## Intro : motion à conserver
- Canvas sur noir, flux ascendant de 21 objets dessinés à partir de 12 PNG transparents, tailles et rotations variées, trajectoire sinusoïdale, profondeur et fondu. Les objets sont fournis séparément dans `assets/objects/` et incorporés dans le HTML.
- Cycles d’environ 11 à 19 secondes, tailles de référence 31 à 63 pixels adaptées à la largeur. Reprendre les formules, coefficients et phases du JavaScript plutôt que reconstruire à partir d’une description.
- Petite sphère sombre en bas, étoiles discrètes, parallaxe souris légère. L’app mobile doit fonctionner sans survol.
- Texte exact : « Tes films. Tes séries. » / « Ton univers. » ; sous-texte « Garde le fil de ce que tu regardes. »
- CTA blanc cassé propre : hauteur de référence 59 px, reflet interne lent, flèche diagonale qui se remplace, léger appui. Lors de l’entrée, accélération de l’envol à 4,8×, fondu et progression interne ; accueil après 900 ms dans le prototype.
- Reprendre les valeurs CSS exactes pour le rendu. Adapter les dimensions au viewport et aux safe areas plutôt que figer un téléphone à bord arrondi dans l’app native.
- Aucun compte à ajouter. Vérifier que la promesse « Ta collection reste sur ton appareil » correspond toujours à l’architecture avant de la conserver.

## Boutons retenus et correspondances
| Référence | Usage Nitrate | Motion de référence |
| --- | --- | --- |
| Soft check | Marquer un épisode ou film vu | Disque lime, remplissage qui s’étend, coche élastique ; transitions 350–700 ms |
| Attach | Ajouter une œuvre à ma liste | Deux volumes lilas qui se rejoignent, plus qui se transforme ; environ 650 ms |
| Next up | Ouvrir/sélectionner la prochaine fiche d’épisode | Cartes empilées et passage au premier plan ; 700 ms, contenu vers 280 ms |
| Glide | À voir / À venir et filtres similaires | Capsule pêche qui glisse et se comprime légèrement ; environ 700 ms |
| Surprise me | Quoi regarder ce soir ? | Petite fleur corail qui tourne/s’ouvre, titre qui change ; environ 1 s |
| Navigation | Séries / Films / Explorer / Profil | Capsule claire qui suit l’onglet et léger mouvement d’icône ; environ 650 ms |

Palette source : fond #101113, carte #1a1b1f, texte #f2f3f5, secondaire #a6a7ae, lime #d4f5a0, lilas #cab7ff, pêche #f3b99d, corail #ff9989. Intro sur #000. Inter pour l’intro ; sans-serif système dans les références des boutons. Ne pas remplacer par une police serif ou ajouter des dégradés décoratifs partout.

Les fonctions retour, fermer, profil, recherche, historique, réglages, importer/exporter et confirmations existent aussi dans l’app : appliquer les mêmes composants et tokens selon leur rôle. Leurs nouvelles variantes ne sont pas toutes validées individuellement ; partir des six familles sans leur inventer une animation spectaculaire propre.

## Intégration Flutter attendue
- Lire les instructions du dépôt et inspecter widgets, navigation, thème, stockage et gestion d’état existants avant de choisir les fichiers à changer.
- Porter le rendu en widgets Flutter natifs et composants réutilisables. Ne pas embarquer toute la maquette dans une WebView.
- Utiliser les mécanismes d’animation déjà présents si adaptés. AnimationController/Tween/Transform/CustomPainter peuvent servir pour reproduire le flux et les interactions sans ajouter une grosse dépendance.
- Lier les états visuels aux données réelles. Marquer vu ne doit enregistrer qu’une fois et doit respecter la logique de rattrapage et d’annulation existante. « Suivant » ne marque pas un épisode vu. Ajouter à ma liste ne doit pas devenir supprimer par simple copie du toggle de démo.
- Le bouton de suivi ne lance pas une vidéo : Nitrate est une app de tracking. Garder les libellés et fonctions métier cohérents.
- Garder navigation, import/export, données locales, fournisseurs de métadonnées et fonctionnement existants. Les œuvres, nombres d’épisodes et historiques des prototypes sont fictifs : ne pas les transplanter comme données produit.
- Présenter les états chargement, succès, erreur et désactivé à partir des opérations réelles. Le délai d’animation ne doit pas simuler une sauvegarde réussie si elle a échoué.
- Réduire les animations lorsque le système le demande, arrêter les boucles hors écran et en arrière-plan, libérer controllers/timers. Éviter les rebuilds de tout l’écran à chaque frame.
- Zones tactiles suffisantes, sémantique accessible, focus, agrandissement du texte et safe areas. Transitions rapides et non bloquantes pour les tâches courantes.

## Vérification et livraison
Implémenter l’intro puis les composants partagés et les intégrer aux écrans concernés. Exécuter format/analyse et les tests pertinents du dépôt. Vérifier visuellement sur simulateur ou appareil si disponible : petits écrans, texte agrandi, double appui, navigation pendant animation, annulation, retour d’arrière-plan et réduction du mouvement. Comparer au prototype au repos ET pendant les transitions ; livrer captures/vidéo si l’environnement le permet. Signaler explicitement ce qui n’a pas pu être exécuté.

Tests déjà effectués sur les prototypes pendant la conception : syntaxe/DOM et logique d’entrée, rejouer, marquer vu et annuler, avec environnement simulé. Aucun test de rendu navigateur complet ou de fluidité sur téléphone n’est certifié. L’intégration native reste entièrement à effectuer.

## Assets et droits
Objets : Microsoft Fluent Emoji (MIT), licence jointe dans vendor/fluent-emoji-LICENSE.txt. Les objets sont des références génériques cinéma/anime, pas des personnages officiels. Icônes d’aperçu : Lucide 0.468.0, licence jointe. Inter est appelé depuis Google Fonts dans l’aperçu ; prévoir une intégration de police appropriée dans Flutter et sa licence si embarquée.
Affiches uniquement comme références de démonstration ; conserver leurs crédits dans les HTML. Dans l’app, utiliser les images et données du fournisseur déjà configuré selon ses conditions. Ne pas considérer les affiches comme des assets libres de droits livrés pour production.
