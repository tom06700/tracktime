# Vues de collection animées — aperçu local

Objectif : rendre testable le passage des vues actuelles à une vue d’ensemble dans Séries et Films, puis l’ouverture et le retour de fiche avec continuité de l’affiche.

Référence observée dans Brave : https://www.inspora.design/posts/8-4 (liste, cartes, pile ; mêmes images déplacées).

Direction : conserver les codes existants de Nitrate et proposer deux densités mémorisées séparément. Séries : grande carte sélectionnée et rotation → grille deux colonnes, avec épisode suivant. Films : grille deux colonnes → trois colonnes, titre et année. Taille tactile minimale 44 px ; réduction des animations système respectée. L’ouverture d’une carte Série garde la destination épisode actuelle ; Film ouvre sa fiche.

Alternative : grille permanente, plus directe mais supprime la présentation immersive appréciée. Un geste de pincement seul serait moins découvrable qu’un bouton explicite ; il n’est pas prévu.

- [x] Créer `design/interactive/collection-views/index.html`, `style.css`, `app.js` : deux aperçus mobiles avec les assets existants, changement de disposition sur les mêmes éléments DOM, ouverture et retour avec affiche partagée.
- [x] Ajouter ralenti, choix mémorisés, navigation dans la rotation, état « vu » de démonstration, navigation clavier et réduction des animations.
- [x] Servir sur localhost, vérifier dans Brave les deux dispositions, une fiche et le retour.

L’aperçu utilise des données de démonstration. L’intégration Flutter est l’étape suivante après retour sur cet aperçu. Aucun changement du code mobile dans cette étape.

Retour utilisateur : travailler la continuité et la fluidité, surtout dans Séries. Révision appliquée : animation du cadre et du recadrage uniforme de chaque image, textes en deux temps, arrêt progressif, léger décalage entre affiches. Aperçu servi sur http://127.0.0.1:8789/collection-views/.
