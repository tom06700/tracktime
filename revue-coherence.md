# Revue de cohérence — septembre 2026

Périmètre : revue du code de l’app Flutter iOS/Android et tests automatiques.
Ce document n’est pas une visite visuelle de l’app installée. Aucun nouveau
rendu natif n’a été inspecté sur ce Mac ; cadrage, toucher, gestes système et
fluidité restent à vérifier dans TestFlight, puis localement sur Mac M2.

| Parcours | Constat fondé sur le code | Traitement dans ce lot |
| --- | --- | --- |
| Démarrage | LaunchScreen iOS blanc et images de lancement du modèle Flutter ; Android blanc également | Splash encre avec l’icône Nitrate existante, styles Android 12+, relais Flutter pendant lecture de la préférence |
| Introduction | L’iris s’arrêtait après 1,4 s | Ouverture puis boucle de 18 s : rotation, respiration, reflet. Arrêt en arrière-plan et avec réduction des animations ; texte et bouton immobiles |
| Accueil / À venir | Fond placé hors du contenu des onglets, visible derrière les commandes de À venir | Opacité liée au contrôleur des onglets, y compris pendant le balayage |
| Images de l’accueil | Premier fond choisi sans comparer la taille, puis petite image d’épisode agrandie | Tri par résolution des fonds du bon type ; contrôle des pixels décodés selon viewport et densité, repli vers une affiche de la même œuvre. Miniatures trop petites refusées ; pas d’image d’une autre œuvre |
| Films | Grille adaptée aux grands textes et actions de bibliothèque existantes | Parcours conservé ; couvert par les tests existants. Inspection visuelle encore nécessaire |
| Explorer | Filtres en ligne rigide et zones tactiles petites | Filtres pouvant revenir à la ligne, zones tactiles agrandies. Requête obsolète déjà ignorée par le jeton existant |
| Bibliothèque | Filtres de genre de 34 px, sélection non annoncée, grille fixe pour texte agrandi | Cibles ≥44 px, sélection sémantique, hauteur adaptée et grille élargie ; réduction des animations respectée |
| Fiche série | Commande de saison de 40 px sans libellé explicite | Cible 44 px et annonce de son action, état désactivé appliqué |
| Fiche film | Retour présent en chargement et erreur, retry disponible, actions isolées | Parcours conservé, tests de navigation et actions existants ; pas de validation visuelle revendiquée |
| Épisode | Fermeture explicite, balayage, états chargement/erreur présents | Parcours conservé ; gestes, hauteur avec clavier/texte agrandi et transition iOS à contrôler sur téléphone |
| Historiques | Actions asynchrones sans blocage des doubles taps ni erreur visible | Bouton occupé pendant l’écriture, erreur compréhensible, nouvel essai possible |
| Profil | Erreur technique brute pour identité, statistiques disparues en cas d’erreur | Messages lisibles et actions de réessai ; message d’export harmonisé |
| Quoi regarder ce soir | Tirage animé même avec réduction des animations | Résultat immédiat quand demandé ; liste vide gérée sans tirage impossible |
| Réglages | Échec d’effacement non signalé | Message d’échec ; confirmation destructrice existante conservée |
| Import | Sélecteur/restauration non protégés contre les erreurs et ouvertures répétées | Une sélection à la fois, vérification du montage après attente, état restauré en cas d’échec et message permettant de réessayer |
| Navigation intro | Relecture supposait toujours un écran précédent | Retour conditionnel, accueil si la route a été ouverte directement |

## Vérifications

- XML Android et storyboard iOS parsés ; catalogue JSON valide. Cela ne remplace
  pas la compilation Android ni la compilation iOS par Codemagic.
- Tests ajoutés : passage À voir/À venir, contrôle de résolution, sélection du
  fond, boucle/arrêt/reprise/réduction du mouvement, action d’écriture en échec.
- Analyse et suite Flutter à exécuter en CI sur la branche avant livraison.
- La boucle animée ne peut plus être testée avec un `pumpAndSettle` permanent :
  les tests avancent l’horloge explicitement avant de quitter l’intro.

## À vérifier sur iPhone

1. Démarrage à froid : splash encre, absence de flash blanc, passage à l’app.
2. Intro : laisser tourner au moins 40 s, passer l’app en arrière-plan puis
   revenir ; comparer aussi avec Réduire les animations.
3. Accueil : titre exact de la série et qualité du fond ; À venir par tap puis
   balayage ; retour À voir. Pas de promesse de netteté si le catalogue ne
   fournit aucune source suffisante : le repli sans photo reste volontaire.
4. Films/Explorer/bibliothèque : petits textes puis taille d’accessibilité,
   recherche, filtres, accès aux fiches.
5. Fiches/épisodes : ouvrir, revenir, fermer, marquer vu, passer à l’épisode
   suivant ; vérifier que gestes et actions restent cohérents.
6. Historique/profil/réglages/import : annuler vu, export et import d’une copie,
   messages d’erreur si un service échoue. Ne pas effacer la collection pour
   une simple vérification graphique.

Aucun verdict « toute l’app validée » sur la seule base de cette revue.
