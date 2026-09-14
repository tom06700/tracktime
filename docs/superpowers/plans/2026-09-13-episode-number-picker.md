# Sélecteur de numéro d’épisode

Objectif : remplacer l’AlertDialog par un panneau cohérent avec les saisons.
Architecture : composant Flutter autonome renvoyant uniquement un numéro officiel ; la fiche conserve la navigation et aucune écriture d’historique n’est ajoutée.

- [x] Créer `episode_number_picker.dart` : panneau sombre arrondi, saison et nombre d’épisodes, saisie numérique, précédent/suivant parmi les numéros officiels, aperçu du titre, validation et ouverture explicite.
- [x] Remplacer `_jump` dans `show_detail_screen.dart`, conserver les routes et la position de lecture.
- [x] Vérifier les trous de numérotation, les limites, les spéciaux, l’annulation, le clavier et le texte agrandi ; exécuter les tests de navigation existants et l’analyse ciblée.
- [x] Compiler en profile, installer et contrôler sur iPhone sans modifier les visionnages ; arrêter l’automation ensuite.

Direction : même surface, coins de 28 et accent lilas que le sélecteur de saisons. L’entrée du panneau utilise Motion.slow et son retour Motion.normal. L’aperçu change par fondu court ; réduction des animations respectée. Une roue demanderait trop de défilement pour les longues séries ; une grille dupliquerait la liste existante.

Validation : 25 tests Flutter passent (sélecteur, navigation, saisons). Analyse ciblée sans problème ; `git diff --check` propre. Build iOS profile installé. Sur iPhone : flèche 1 → 2, saisie de 4 avec clavier, bouton accessible et ouverture de S23E4 vérifiés. Aucun contrôle de visionnage actionné. Rendu et enregistrement de 6 images inspectés ; échantillonnage trop faible pour mesurer finement la fluidité. Capture clavier : `/var/folders/1w/tyr6zbqn3bx9nz2wyqt3mpc80000gn/T/mobai/screenshots/00008150-000609C23C40401C-1789313630.jpeg`.
