# Ta pellicule — référence validée

Ce dossier transmet uniquement le module visuel « Ta pellicule » pour Nitrate. Il complète le pack global de la PR #11. Il ne remplace pas la bibliothèque et ne regroupe pas les onglets Films et Séries.

## Essayer
Ouvrir preview.html dans un navigateur. reference.html conserve exactement le fragment interactif validé en conversation. Les images sont intégrées ; la police Inter utilise Google Fonts et possède un repli système. La page de prévisualisation est générée avec le wrapper de conversation.

## Comportement retenu
- Chaque segment de pellicule est un vrai bouton : sélectionner une image sélectionne le genre correspondant.
- Les boutons de genres et les segments partagent un seul index de sélection. Le libellé, le pourcentage et la forme du panneau sont synchronisés.
- Un nouvel appui sur le genre actif rejoue le mouvement sans changer les données.
- Les largeurs restent proportionnelles au temps passé : 19 / 13 / 10 / 8 / 7 / 6 / 37 %, total 100 %. Ce sont les valeurs de la capture fournie, pas des données du compte.
- Les affiches servent de références visuelles de démonstration ; ne pas déduire les genres réels à partir de ces associations.

## Motion à reproduire en Flutter natif
Lire les keyframes et courbes exactes dans reference.html.
- Segment choisi : pression puis soulèvement, rotation X et léger rebond, 950 ms ; état final translateY(-8 px), rotateX(-7°).
- Voisins : ondulation de 800 ms, retard de 35 ms par distance à la sélection.
- Reflet diagonal : 1100 ms, délai 80 ms.
- Perforations : défilement de 850 ms.
- Pourcentage : rouleau ancien/nouveau, 850 ms, cubic-bezier(.16,1,.3,1).
- Panneau : lumière colorée discrète, 1000 ms ; forme de fond en rotation.
- Boutons : remplissage montant, 550 ms, avec pression tactile.

Ne pas introduire de lecture vidéo ni de WebView pour ce module. Garder les calculs de statistiques existants : lire leur règle de répartition des œuvres multigenres avant de brancher la vue, éviter de compter plusieurs fois la même durée. Ne pas copier les chiffres de démonstration en production.

## Accessibilité et limites
La sélection fonctionne au clic et au clavier via des boutons natifs. Annoncer le résultat final, pas les étapes du compteur. La réduction des animations supprime les effets et affiche immédiatement l'état final.
Les petits segments sont forcément étroits dans une barre proportionnelle : conserver les grands boutons de genres comme alternative tactile, sans agrandir artificiellement leurs parts ni créer des zones qui se chevauchent.
Dans le portage, gérer les genres absents, zéro durée, métadonnées inconnues, textes longs et les petites parts. La catégorie Autres reste une agrégation, pas un genre inventé.
La prévisualisation ne persiste rien. Vérifier sur appareil les tap rapides, la fluidité, les zones tactiles, la lisibilité et la réduction des animations.

## Validation effectuée
Simulation DOM des sept segments, appuis répétés, synchronisation des boutons, état numérique final et déclenchement des animations. Total vérifié à 100 %. Aucune validation visuelle sur appareil Flutter n'est revendiquée.

## Crédits des images
Affiches utilisées comme références de design, droits conservés par leurs ayants droit :
- One Piece : https://www.media-paten.com/sprecherkartei/synchronsprecher-filme/One-Piece/
- Severance : https://www.themoviedb.org/tv/95396-severance/images/posters
- Jujutsu Kaisen : https://www.formulatv.com/series/jujutsu-kaisen/
- Dune : https://www.olivewoodstudios.jo/
- Chainsaw Man : https://www.walmart.com/ip/Chainsaw-Man-Key-Art-Wall-Poster-22-375-x-34/3337944513

Utiliser les affiches fournies par les intégrations autorisées de l'application lors du portage.
