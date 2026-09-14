# Images et continuité d’Explorer

Demande validée : appliquer les corrections de l’audit, puis lancer Android.

1. Cache disque partagé des images distantes (500 fichiers, nettoyage après
   30 jours sans utilisation), décodage adapté à la taille affichée, sources
   alternatives et fondus conservés. Bibliothèques Baseflow vérifiées sur
   pub.dev ; versions compatibles verrouillées par pub.
2. Libérer les références d’images utilisées pour les palettes ; garder les
   calculs et téléchargements partagés. Tests de réutilisation et de taille.
3. Restaurer la position de découverte après Tout voir, retour épinglé dans
   la grille et retour système Android. Stabiliser la recherche et adapter
   les titres/actions aux grands textes. Tests de navigation et de géométrie.
4. Vérifier les parcours existants, refaire les captures locales et compiler
   Android. Installer et lancer sur Pixel 6 sans effacer les données existantes.

MobAI retourne HTTP 402 sur Pixel (iPhone actuellement actif). Ne pas arrêter
l’autre appareil ; utiliser les outils Android pour installer/lancer si le
blocage subsiste. Ne pas prétendre avoir mesuré les FPS ou la consommation
réelle sans accès aux mesures. Aucun changement d’historique pour les tests.

Sources : https://pub.dev/packages/cached_network_image et
https://pub.dev/packages/flutter_cache_manager (configuration et limites).

## État de validation

- Cache, adaptation du décodage et libération des références : implémentés.
- Explorer : retour épinglé, position restaurée, recherche stable et grands
  textes adaptés ; retour système limité à l’onglet actif.
- Tests ciblés cache + Explorer : 20 réussis. Tests des autres parcours
  Séries/Films/fiches/profil et ajout/retrait exécutés ; leurs cas ont réussi
  (un cas déjà ignoré dans la suite). Tests artwork/hero/palette exécutés.
- Audit visuel renouvelé : docs/audits/2026-09-14-explorer-scroll-after.
- Analyse finale : aucune anomalie. Compilation Android profil réussie.
- Pixel 6 (24201FDF600AKW) : adb install -r → Success ; démarrage à froid
  Status: ok, activité com.thomasgomez.tracktime/.MainActivity au premier plan,
  PID 23459. Aucune désinstallation ni suppression de données.
- MobAI indisponible (402) : aucun test de gestes ou mesure FPS sur appareil.
  Capture de lancement : /tmp/nitrate-pixel-launch.png.
