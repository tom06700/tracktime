# Vérification après corrections — 14 septembre 2026

Captures du vrai widget Flutter, données et images factices ; ce ne sont pas
une mesure de FPS ni des captures du Pixel. Même scénario que l’audit initial.

- Retour depuis la grille : bouton accessible à 581 px de défilement.
- Position découverte : 330,725 px avant et après, au lieu d’un retour à zéro.
- Champ de recherche : le logo reste monté ; la saisie préserve la position du
  champ, aussi bien à l’arrivée qu’une fois épinglé (tests de géométrie).
- Titres à texte doublé : action « Tout voir » sous le titre, sans écrasement
  horizontal du titre par le bouton.
- Retour système : ferme d’abord la recherche ou revient à la découverte ;
  interception désactivée lorsque l’onglet est caché par le TickerMode du shell.

Les captures 01 à 06 et mesures.json complètent les tests de navigation.

## Images

Toutes les images distantes passent par le cache partagé `nitrate_artwork_v1`.
Nettoyage configuré à 500 fichiers / 30 jours sans utilisation : limite en
nombre de fichiers, pas quota strict en Mo ; le système peut purger ce cache.
Le cache respecte aussi la fraîcheur HTTP des fichiers.

Les décodages sont regroupés par paliers de 64 pixels physiques, jusqu’à 2048
pixels de large, en conservant le ratio. Les grandes fiches réutilisent les
mêmes fichiers compressés. La validation de netteté du hero lit encore les
pixels source originaux ; l’extraction de palette utilise un décodage de 64 px,
puis libère les images et le Picture temporaires.

Tests du cache : requêtes simultanées dédupliquées, fichier réutilisé après
recréation du gestionnaire sans téléchargement, dimensions bornées et absence
de référence native conservée par l’extraction de couleurs.
