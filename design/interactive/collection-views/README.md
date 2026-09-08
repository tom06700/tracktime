# Nitrate — vues de collection

Aperçu interactif local de la référence https://www.inspora.design/posts/8-4, dans le langage visuel de Nitrate.

Servir le dossier parent `design/interactive` avec `python3 -m http.server 8789 --bind 127.0.0.1 --directory design/interactive`, puis ouvrir http://127.0.0.1:8789/collection-views/.

Interactions : changement de disposition individuel ou simultané, ralenti, rotation Séries, ouverture d’une affiche, retour animé, simulation de visionnage. Préférences distinctes dans localStorage ; mouvement réduit si demandé par le système. Affiches et identité visuelle reprises des assets locaux existants, icônes Lucide existantes. Données et résumés fictifs ; aucune connexion à la bibliothèque réelle. Les onglets secondaires, la navigation et les icônes d’en-tête sont illustratifs.

Le changement de disposition anime les mêmes boutons d’affiche avec mesure avant/après. Révision mouvement : disparition des libellés sur 75 ms, déplacement et changement de cadre sur 640 ms avec freinage progressif, décalage de 22 ms entre les affiches (plafonné à 65 ms), puis retour des libellés à partir de 340 ms. Les images sont recadrées uniformément ; aucune mise à l’échelle anisotrope. Un changement demandé pendant une transition est conservé pour la fin de celle-ci. La transition de fiche utilise une copie visuelle temporaire, puis rend l’affiche destination visible. L’aperçu ne modifie pas le code Flutter. La navigation Série représente l’épisode suivant, destination actuelle de la grande carte.

Vérification : syntaxe JavaScript valide ; deux dispositions inspectées dans Brave ; ouverture et retour de fiche Film et Série vérifiés sur la première version ; nouvelle transition Séries vérifiée au ralenti et grille finale inspectée.
