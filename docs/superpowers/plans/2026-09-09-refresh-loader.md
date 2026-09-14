# Loader de rafraîchissement borné

Problème confirmé : le geste attend la passe complète sur toutes les séries, qui peut inclure plusieurs requêtes par titre et attendre une passe de fond. Le timeout HTTP ne borne pas cette attente globale.

Correction : un composant commun BoundedRefreshIndicator laisse le loader visible au plus 8 secondes. Ensuite la synchronisation continue avec un message explicite. Les nouveaux gestes pendant cette tâche réutilisent le travail en cours. Les erreurs sont absorbées et signalées sans exception après démontage. Séries À voir / À venir et Films Ma liste utilisent le composant. Films repose sur les flux de base pour ses mises à jour, sans invalider un ref après une longue attente.

Validation : 22 tests ciblés réussis, analyse Flutter sans problème. Cas : succès rapide, dépassement de délai, gestes répétés, erreur immédiate et erreur après départ de la page. Build debug signé installé et lancé sur l’iPhone 17 Pro via MobAI. Sur Séries, captures avant/après confirmant le loader puis sa disparition avec le message de poursuite en arrière-plan ; Films et À venir reviennent également sans loader persistant après le geste. Captures locales dans /tmp/nitrate-refresh-check.

## Maintien demandé le 11 septembre

Le contenu doit rester tiré pendant le chargement puis remonter au succès, à l’erreur ou après 8 secondes. Un espace de 72 points accueille le logo de 44 points. La translation ajoute uniquement la distance manquante par rapport au rebond natif iOS, afin d’éviter un double décalage. Retour animé en 220 ms ; mouvement réduit immédiat. Le contenu est conservé en enfant de l’AnimatedBuilder et n’est pas reconstruit à chaque image du maintien.

Tests d’abord en échec (contenu revenu à 0 au lieu de rester à 72), puis réussis : gestes réels bouncing/clamping, position maintenue, retour progressif et délai maximal. 28 tests ciblés (rafraîchissement, logo, pages Séries/Films) réussis ; analyse sans problème. Version profile signée installée et lancée sur l’iPhone. Contrôle physique : contenu maintenu à +72 points pendant le chargement, puis retour à sa position initiale au délai de 8 secondes avec poursuite de la synchronisation en arrière-plan. Captures `/tmp/nitrate-refresh-hold/held.png` et `released.png`. MobAI arrêté après vérification.
