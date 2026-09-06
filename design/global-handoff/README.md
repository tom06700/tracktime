# Accéder au pack

Décompresser `Nitrate-Design-Global.zip` dans un dossier de travail. Les chemins mentionnés ci-dessous sont relatifs au dossier extrait `nitrate-design-global/`. Ouvrir son `index.html` pour tester les références. Les fichiers sous `app/` ne sont pas modifiés par cette transmission.

# Nitrate — pack global de design validé

Le pack rassemble les directions validées en conversation pour préparer une grosse PR d’intégration Flutter. Il contient des prototypes interactifs, pas une nouvelle implémentation de l’application. Ouvrir `index.html` pour les essayer, ou servir le dossier avec `python3 -m http.server 8000`.

## Références et priorité
| Fichier | Référence pour |
| --- | --- |
| 01-intro.html | Intro définitive : envol d’objets sur noir, typographie Inter et CTA blanc |
| 02-boutons.html | Six familles de boutons modernes et leurs animations |
| 03-a-reprendre.html | Module À reprendre et suivi en contexte |
| 04-notifications.html | Explication avant permission, choix activer / plus tard |
| 05-episode.html | Fiche épisode adaptée au code, numéros longs et rattrapage |
| 06-serie.html | Nouvelle fiche série, saisons, accès direct, liste paginée |
| 07-film-explorer-profil.html | Fiche film, Explorer et profil reliés dans un aperçu |
| brand/nitrate-ruban-violet.png | Planche du logo violet retenu, référence raster à vectoriser |

Chaque HTML contient intégralement le fragment validé, entouré uniquement d’un document autonome et relié au runtime local d’icônes. Les empreintes SHA-256 des fragments d’origine et des documents sont dans `manifest.json`. Les images des prototypes sont incorporées. Inter se charge depuis Google Fonts, avec repli système hors ligne.

La fiche série complète de 06 prime sur la mini-fiche série de 07. Le mini-accueil après l’intro n’est pas un nouvel accueil à intégrer. Le logo est une planche de direction : ce n’est pas une icône exportable telle quelle, ni un SVG final.

## État GitHub vérifié pour cette transmission
Base de la branche de transmission : d6a47638ba9fef96e126232ef37f402c6500659d.
Le code ayant servi à l’analyse de la fiche épisode était c9a1840cb0710dd63dfb25b13ca69786882d57d9. La PR #8 de transmission de cette fiche est maintenant fusionnée. Lire aussi `design/validated-handoff/episode-detail/README.md` dans le dépôt.
Les packs initiaux ont déjà fait l’objet d’un portage. Inspecter le travail actuel avant de modifier : ne pas réappliquer les anciens packs à l’aveugle ni écraser les corrections récentes.

## Ordre d’intégration
1. Comparer les composants partagés actuels aux boutons retenus ; réutiliser et corriger au besoin.
2. Intégrer la fiche série et ses saisons/liste, puis raccorder la fiche épisode.
3. Intégrer fiche film, Explorer, profil/historique et leurs vrais états.
4. Harmoniser la marque avec le logo violet vectorisé et vérifier le parcours complet.
5. Vérifier format/analyse/tests pertinents et comparer visuellement sur une cible exécutable. Une analyse qui passe ne certifie pas le rendu ou la fluidité.

## Règles communes
Nitrate est une app de tracking, pas un service de streaming. Ouvrir une fiche ou changer d’épisode n’enregistre jamais un visionnage. Brancher les contrôles sur les données réelles ; succès après écriture réussie ; erreurs, double appui et cycle de vie gérés.
Porter en widgets Flutter natifs, pas en WebView. Reprendre les couleurs, géométries, courbes et timings directement dans les CSS/keyframes/JS. Respecter safe areas, texte agrandi, sémantique et réduction du mouvement. Arrêter les boucles hors écran et libérer les controllers.
Les jeux de données des prototypes sont indépendants : 06 utilise un cas synthétique de 1 236 épisodes, 07 un petit catalogue de cinq titres. Ne jamais fusionner ces fixtures dans les données produit. Les noms de saisons, durées et dates de démonstration ne font pas autorité sur le catalogue.
Préserver les fonctions et règles métier existantes, y compris les champs absents des maquettes. Les écrans de réglages/import/export de 07 sont des accès illustratifs, pas des spécifications complètes ni des suppressions de fonctionnalités.

## Fiche série
Conserver `ShowDetailScreen`, ses routes et données réelles. Grande image, progression, ajout explicite, Reprendre vers le premier épisode pertinent non vu, onglets À propos / Épisodes, saison choisie, filtre non vus et accès par numéro.
Les saisons utilisent les numéros officiels retournés par le fournisseur. Aucun arc manga ni numéro absolu ne doit être inventé. Les listes doivent supporter les trous, spéciaux si disponibles, langues/manquants et très longues saisons. Pagination de 6 lignes en démo ; préférer un builder/une liste virtualisée dans Flutter.
La demande de rattrapage du prototype suit le comportement déjà lu dans `findMissingEpisodesBetween` : cible d’abord marquée, intermédiaires de la même saison proposés, aucun remplissage sans réponse. Ne pas la confondre avec « Jusqu’ici » de la fiche épisode, de portée différente.
Le changement de saison et la recherche n’écrivent pas de progression. Ajouter n’est pas retirer ; le retrait passe par gestion et confirmation, avec sa portée de suppression expliquée.

## Fiche film / Explorer / profil
Le bouton film agit sur l’unique visionnage, avec date et annulation. Les identités réelles et fournisseurs remplacent la fixture Dune. Ne pas copier le filtre de démonstration comme un moteur de recherche réel ; conserver pagination réseau, erreurs, états vides et tous les types réellement pris en charge.
La maquette suggère un ajout explicite avant suivi. Vérifier les règles de la branche actuelle, notamment l’incohérence précédemment relevée entre fiches série/épisode ; harmoniser explicitement plutôt que changer silencieusement les comportements.
Profil : temps ESTIMÉ calculé à partir des durées, compteurs dérivés des visionnages, historique consultable et retour à non vu. Toute mutation doit se refléter partout dans l’app. Les trois stats du prototype ne remplacent pas les autres informations du profil actuel.
« Quoi regarder ce soir ? » utilise uniquement les titres suivis encore à voir. Le prototype parcourt une sélection déterministe pour permettre les tests ; conserver la logique produit de suggestion.
Le formulaire profil du prototype est local : en Flutter, prénom ET avatar doivent être validés ensemble au clic Enregistrer ; Annuler ne doit pas persister une modification. Reprendre la gestion des avatars existante, pas nécessairement les glyphes de démo.

## Notifications et marque
La référence notifications est un pré-écran, pas un faux dialogue système à recopier. Utiliser les statuts natifs réels. L’autorisation ne signifie pas que le service d’envoi est opérationnel ; le document de portage existant indique l’absence de service d’envoi à sa rédaction. Vérifier l’état actuel et adapter honnêtement la promesse.
Logo : « n » ruban violet, icône principale lilas/symbole noir ; version dans l’app lilas et mot nitrate. Utiliser la planche pour un tracé vectoriel propre, proportions cohérentes et test de lisibilité petite taille, puis générer les icônes natives requises. Ne pas convertir la planche entière en icône. Ne pas repartir sur les autres logos ni la direction rétro rejetée.

## Validation et limites
Parcours DOM simulés déjà vérifiés :
- Série : reprise sans mutation, coche, rattrapage, 6 lignes, accès à 1200, retrait confirmé, ajout.
- Film/Explorer/profil : film vu → temps 8 h 13 et 1 film, retour non vu → 5 h 27 ; recherche/filtres/état vide, ajout série → compteur, suggestion, prénom échappé.
- Épisode : numéro 1155/1200, navigation sans écriture, 10 lignes, confirmer/annuler un lot en préservant l’antérieur, résumé absent, fermeture.
Tests exécutés sur les simulations, pas sur une application native. Aucun rendu navigateur complet ou test de performance téléphone n’est certifié par ce pack. Les interfaces finales doivent être testées dans le dépôt et sur cible adaptée.

## Crédits
Objets : Microsoft Fluent Emoji, licence MIT jointe. Icônes d’aperçu : Lucide 0.468.0, licence jointe. Affiches : crédits dans les références ; visuels de démonstration, pas des assets libres de droits livrés pour production. Utiliser les sources autorisées par l’app. Inter : conserver sa licence si embarquée. Les anciens briefs sont fournis pour traçabilité ; ce README et les références finales définissent la priorité en cas de conflit visuel.
