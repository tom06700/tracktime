# Intégration Flutter du Passage

Direction approuvée : porte lilas toujours entrouverte, respiration 7 s,
traversée perspective 2,2 s puis accès au véritable Explorer.

1. Porte native : CustomPainter à géométrie projetée, volumes biseautés et
   gradients ; un contrôleur local pour la respiration, arrêté hors écran.
   Remplacer seulement les états de collection initialement vide Séries/Films.
2. Transition dans HomeShell : conserver les instances des onglets, révéler
   Explorer par le masque de la même arche, effacer l’origine et sa navbar,
   puis sélectionner Explorer à la fin. Aucun WebView ni capture pleine page.
   Mesurer le rectangle réel de la porte, conserver sa phase au déclenchement.
3. Tests : porte et CTA, double activation, retour système pendant la traversée,
   réduction des animations, conservation de l’état d’Explorer et tailles écran.
4. Validation téléphone avec MobAI si disponible ; Android CLI en repli si
   limite de licence, comme dans le parcours de validation précédent.

Ne pas toucher aux collections, aux imports ni aux autres transitions validées.
