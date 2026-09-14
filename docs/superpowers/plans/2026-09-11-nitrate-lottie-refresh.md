# Loader Nitrate intégré

Animation validée dans le lecteur Skottie : copie exacte de la scène `design/interactive/nitrate-lottie/public/projects/nitrate/scene-1/lottie.json` vers `app/assets/animations/nitrate-loader.json`.

`BoundedRefreshIndicator` conserve le geste et le seuil natifs via `RefreshIndicator.noSpinner`, avec une marque superposée de 44 px et une sortie en fondu. Le dessin boucle uniquement pendant le travail ; le geste préparatoire et le mode de réduction des animations utilisent le symbole fixe. Un repli statique assure sa lisibilité pendant le chargement de l’asset ou en cas d’erreur. Le délai maximal de 8 secondes, le partage de la requête et le traitement des erreurs sont conservés. Intégration sur Séries À voir / À venir et Films Ma liste.

Dépendance Lottie 3.3.3, compatible Flutter 3.41.9 / Dart 3.11.5. Lottie 3.5.1 requiert Dart 3.12 ; aucune mise à jour du SDK effectuée.

Validation : test d’apparition de la marque observé en échec avant implémentation, puis 23 tests des rafraîchissements et écrans réussis ; 7 tests ciblés supplémentaires/rejoués dont 2 nouveaux contrôlent le mode réduit et les pixels rendus par Flutter (masque, révélation, fondu, transparence aux deux extrémités). 25 tests distincts au total. Analyse Flutter sans problème. Captures sur iPhone dans `/tmp/nitrate-lottie-native` : affichage et fondu visibles sur À venir, arrêt au délai, gestes répétés réutilisant le travail en cours, retour rapide Films. MobAI arrêté à la fin. Hot restart effectué sur la session Flutter 69244.
