# Nitrate — étude locale des menus d’actions

Aperçu indépendant, sans dépendance ni connexion à la bibliothèque réelle.

Lancement : `python3 -m http.server 8788 --bind 127.0.0.1 --directory design/interactive/action-menus`

## Référence et décisions

Source : https://www.inspora.design/posts/multi-action-button

Trois variations de structure et de mouvement dans les couleurs et illustrations existantes : pastilles séparées en cascade (recommandation), panneau compact, éventail court. Le bouton se transforme en fermeture. Les actions restent libellées. Animation au clic seulement, ralenti manuel, respect de prefers-reduced-motion. Fermeture extérieure et Échap, focus clavier contenu dans le menu, cibles de 44 px minimum.

## Emplacements relevés dans Flutter

- Cartes Films : `app/lib/movies/widgets/movie_poster_card.dart`, `_ActionMenu`. Deux actions réelles : `markWatched` / `markUnwatched` selon l’état et `remove`. Priorité pour une future intégration.
- Films vus : variante sémantique proposée, basée sur le paramètre `watched` du composant. L’aperçu ne prétend pas reproduire la présentation actuelle de la page d’historique.
- Fiche Film : `app/lib/screens/movie_detail_screen.dart`, `_manage` retire le film et `_toggle` change son statut de visionnage. Le prototype propose de regrouper ces deux actions, actuellement séparées.
- Fiche Série : `app/lib/screens/show_detail_screen.dart`, `_manage` suit ou retire la série. Une seule action contextuelle ; menu multi-action non recommandé actuellement.
- En-tête : `app/lib/widgets/validated_detail.dart`, `ValidatedDetailHero.onManage` fournit le bouton « … » commun aux fiches.

Les films et synopsis sont fictifs. Les actions affectent seulement la variante cliquée ; Annuler et Réinitialiser permettent de tout rejouer. Le code Flutter n’est pas modifié.
