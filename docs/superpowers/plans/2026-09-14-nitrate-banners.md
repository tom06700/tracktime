# Bannières Nitrate

Demande : remplacer la confirmation d’ajout et utiliser le même système dans
toute l’app. Emplacement validé : en haut, flottante sous la zone système.

Direction : graphite, bord fin, rayon 22, petite icône de statut verte/lilas,
texte blanc et action compacte. Entrée fondu + translation de 8 px sur 220 ms,
sortie 140 ms ; réduction du mouvement respectée. Pas de flou plein écran.
Marge 16 px, largeur maximale 560, contenu adaptable aux grandes polices.

- [x] Composant commun et présentation dans l’Overlay racine, sans dépendance.
  Un seul message, remplacement immédiat, expiration 4 s / 6 s avec action,
  fermeture manuelle et par balayage. Les timers disparaissent avec le widget.
- [x] Migrer les messages existants, en préservant callbacks et confirmations
  destructives. Distinguer succès, information et erreur par icône + couleur.
- [x] Tester expiration avec action, remplacement, passage tactile hors carte,
  fermeture, callbacks uniques, grandes polices, zone sûre et mouvement réduit.
- [x] Vérifier le rendu Flutter local, analyser et tester les parcours touchés.
- [x] Compiler et installer sur l’iPhone sans automation.

Les dialogues de confirmation et les erreurs de page avec réessai restent des
interactions distinctes. Aucun historique utilisateur modifié pour les tests.

Migration de 30 points d’affichage dans 19 fichiers. Aucun appel showSnackBar
ne subsiste dans lib. Le système conserve les callbacks Voir/Annuler et ne
met aucun message en file. Capture du composant Flutter avec Inter et les
icônes Material : docs/audits/2026-09-14-nitrate-banners.png.

Tests des bannières, Explorer/collection, actualisation, séries, films,
navigation des fiches, épisodes, contrôles asynchrones, menus, imports,
réglages, notifications et onboarding validés après corrections ; un test de
navigation déjà ignoré reste ignoré. Analyse de lib sans problème.
Le cas de texte doublé utilise une disposition verticale avec action en dessous.
Les lecteurs d’écran disposent d’un délai doublé et d’une zone liveRegion.
Le retrait rapide d’Explorer conserve son délai spécifique de 3 secondes.

Build profile, installation et relance devicectl réussis le 14 septembre à
11:45 UTC. Automation laissée désactivée. Contrôle visuel effectué sur le
rendu Flutter local ; interactions vérifiées par tests, pas sur l’iPhone.

Correction suivante : messages sans sous-titre (notamment le retrait) décalés
verticalement. La rangée compacte centre désormais texte, icône, action et
croix ; le décalage fixe de 6 px de l’icône a été supprimé. Tests géométriques
sur message court et long, puis 10 tests bannière/collection réussis.
