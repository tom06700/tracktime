# Explorer — recherche et découverte

Direction retenue : recherche rapide et découverte, affiches au premier plan.

Constat sur iPhone : le titre, sa description et une bannière non identifiée
repoussent les premières affiches sous 630 px. Les sélections sont concaténées,
ce qui enterre les films sous les séries. La recherche conserve cette introduction.

- [x] Rechercher et filtrer depuis un en-tête épinglé, sans introduction générique.
- [x] Séparer séries populaires, films populaires et sorties annoncées en rangées.
- [x] Ouvrir chaque sélection en grille et revenir aux rangées.
- [x] Préserver navigation, ajout, réponses réseau obsolètes et états d'erreur.
- [x] Vérifier tests ciblés, petits écrans et texte agrandi.
- [x] Installer en profil et vérifier les parcours sur iPhone ; arrêter l'automation.

Références de structure : recherche et sélections de MUBI
(https://help.mubi.com/article/261-how-do-i-find-what-to-watch), filtres de
recherche Netflix (https://help.netflix.com/en/node/47765).

Validation : 30 tests Explorer/navigation réussis ; les 9 tests Explorer ont été
rejoués après ajout de la clé conservant le focus. Analyse ciblée sans problème.
Build iOS profile installé sur l’iPhone connecté. Recherche Dune avec clavier,
filtre Films, grille Séries/Films, fiche Titanic et retour vérifiés sans écriture
de collection. Recherche épinglée confirmée après défilement.

Captures locales :
- avant : /var/folders/1w/tyr6zbqn3bx9nz2wyqt3mpc80000gn/T/mobai/screenshots/00008150-000609C23C40401C-1789315833.jpeg
- découverte : /var/folders/1w/tyr6zbqn3bx9nz2wyqt3mpc80000gn/T/mobai/screenshots/00008150-000609C23C40401C-1789316448.jpeg
- recherche finale : /var/folders/1w/tyr6zbqn3bx9nz2wyqt3mpc80000gn/T/mobai/screenshots/00008150-000609C23C40401C-1789316679.jpeg
- défilement : /var/folders/1w/tyr6zbqn3bx9nz2wyqt3mpc80000gn/T/mobai/screenshots/00008150-000609C23C40401C-1789316752.jpeg

Enregistrement /tmp/nitrate-explorer-search : 26 images inspectées. Les alertes
de changement correspondent au clavier, au passage en recherche et au chargement
des affiches. Ceci ne constitue pas une mesure de fréquence d’images.
Pas de test matériel Android sur cette intervention. Automation arrêtée.
