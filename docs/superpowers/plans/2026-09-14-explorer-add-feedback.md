# Retrouver une œuvre après ajout

Cas signalé : Young Sherlock ajouté depuis Explorer puis introuvable.

Causes observées dans le code : exclusion de la collection recalculée pendant
la navigation ; aucun message de succès ; le tri Récentes de Mes séries ignore
la date d'ajout lorsqu'il n'existe aucun visionnage.

- [x] Vérifier l'enregistrement de Young Sherlock sur l'iPhone, en lecture seule.
- [x] Garder les affiches ajoutées pendant la visite d'Explorer, cochées.
  Réactualiser les exclusions lors d'une nouvelle visite de l'onglet.
- [x] Confirmer l'ajout avec une action ouvrant directement la fiche.
- [x] Faire participer la date d'ajout au tri Récentes de Mes séries.
- [x] Tester ajout/confirmation/navigation/tri puis installer sur l'iPhone.

Preuve sur copie en lecture seule de la base iPhone : Young Sherlock, id 450633,
ajoutée le 14 septembre à 08:29 UTC ; 8 épisodes en cache, aucun visionnage.
Simulation des deux tris sur les mêmes données : position 174/174 avant, 1/174
après prise en compte de la date d’ajout. Aucune modification de la base réelle.

42 tests ciblés réussis : ajout conservé et confirmé, action ouvrant /show/450633,
aucun épisode marqué vu, exclusions réactualisées à la visite suivante, tri
Récentes et navigation existante. Analyse ciblée sans problème.

Build profile et installation devicectl réussis. Contrôle visuel MobAI toujours indisponible (limite d’appareils) ; aucune automation activée. Copie de diagnostic SQLite supprimée après vérification.

Correction de la confirmation : persist=false explicite (Flutter 3.41 rend
les SnackBar avec action persistants par défaut), durée 6 secondes, texte et
action blancs, fond d’action transparent et croix de fermeture. 14 tests
Explorer réussis ; le test ciblé vérifie les couleurs rendues et l’absence de
SnackBar après expiration, en conservant l’affiche ajoutée. Analyse sans problème.

Décochage depuis Explorer : le bouton coché désactivait son onTap. Il permet
maintenant un retrait local, immédiat sans visionnage, ou confirmé si une
progression existe (dialogue film existant réutilisé). Les doubles appuis sont
bloqués pendant l’opération, puis le « + » permet un nouvel ajout. Libellé
accessible « Retirer … de ma liste », état bascule, zone tactile complète.

Les tests ont également révélé que deleteShow dépendait d’une cascade SQLite
non garantie sur toutes les connexions. Le retrait nettoie explicitement les
épisodes et visionnages concernés dans une transaction ; les autres séries
restent intactes. Vérification de l’historique par requête ponctuelle limitée.

51 tests réussis, 1 test existant ignoré : Explorer, ajout/retrait/réajout des
deux médias, annulation sans perte de progression, navigation et fiche épisode.
Analyse ciblée sans problème. Aucun retrait effectué dans la collection réelle.
Build profile, installation et relance sur l’iPhone réussis à 11:23 UTC,
sans activer l’automation. Validation visuelle sur appareil non effectuée.
