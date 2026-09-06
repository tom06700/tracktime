# Nitrate — complément 02 : permission notifications

Ce dossier complète le premier pack `nitrate-codex-handoff` déjà transmis. Il ne remplace ni l’intro sur fond noir, ni les six boutons modernes, ni l’écran À reprendre.

## Référence validée
`references/04-permission-notifications.html` est la copie exacte de l’écran testé et validé en conversation. Lire son HTML/CSS/JavaScript pour reproduire les formes, couleurs, positions, courbes et timings en Flutter natif. `index.html` permet de tester cet écran dans un navigateur sans configuration. Les images et icônes y sont incorporées ; la police Inter est chargée depuis Google Fonts et remplacée par une police système hors ligne.

Le parcours retenu est : intro → page notifications → accueil réel de Nitrate. Le repère 02 / 02 suppose ces deux étapes ; l’adapter si le parcours existant en contient davantage. Préserver les changements déjà réalisés à partir du premier pack.

## Design et mouvement
Fond noir, Inter 400/500, titre « La suite. Sans la manquer. », deux cartes de notification en suspension, objets 3D discrets, cloche et badge lime. Bouton blanc cassé « Activer les notifications » avec cloche qui oscille et reflet interne, puis option « Plus tard ».

Références exactes dans le CSS : arrivée de la notification 1,3 s avec cubic-bezier(.2,1.15,.3,1), flottement principal 7 s, carte arrière 9 s, objets 8 s, petite sonnerie et badge toutes les 6 s, reflet 7 s. Les temps sont des références visuelles ; ne pas retarder l’opération native pour attendre une animation.

Les exemples de sorties sont fictifs. Aucun épisode précis ni calendrier réel n’est affirmé. Les contenus des futures notifications doivent rester sans spoiler pour tenir la promesse affichée.

## Comportements d’intégration attendus
- Inspecter les instructions, l’onboarding, le stockage et les services de notification du dépôt actuel. Réutiliser l’architecture existante et vérifier la documentation officielle des plateformes/plugins utilisés au moment de l’implémentation.
- Cette page est une explication AVANT la permission. Le dialogue du HTML est explicitement une simulation : ne pas reproduire ce faux dialogue dans Flutter. L’app doit utiliser la vraie demande système prise en charge par la plateforme.
- Demander la permission après l’appui explicite sur « Activer les notifications », pas à l’ouverture de cette page.
- « Plus tard » poursuit vers l’accueil sans demande système. Mémoriser la fin du parcours pour éviter de redemander à chaque lancement.
- Lire le statut réel : déjà autorisé, encore indéterminé, refusé ou autres états gérés par l’API. Ne pas afficher un succès sur la seule base du clic.
- Une autorisation déjà accordée ne doit pas produire un doublon de demande. En cas de refus ou d’erreur, laisser l’app utilisable et permettre de continuer ; proposer une action appropriée dans les réglages lorsque nécessaire, sans forcer l’ouverture des réglages système.
- Les écrans finaux du prototype montrent les branches de démonstration. Les relier à l’accueil réel ; ne pas ajouter « Rejouer », les crédits de démonstration, le statut de simulation ou l’écran « Fin de cet aperçu » au parcours produit.
- L’autorisation seule ne crée pas un service de push. Vérifier séparément la capacité à détecter les sorties et envoyer/planifier les notifications, ainsi que la configuration native et les services du projet. Si absents, signaler ce qui reste à connecter au lieu de prétendre que l’envoi fonctionne. Ne pas ajouter arbitrairement de backend ou de dépendance lourde pour cette intégration visuelle.
- Respecter les données, fonctions et choix de l’utilisateur. Nitrate reste une app de tracking et non un lecteur vidéo.
- Réutiliser les composants du premier pack. Adapter aux safe areas, petits écrans, texte agrandi et lecteurs d’écran. Réduire le mouvement sur demande système, arrêter les animations hors écran/en arrière-plan et libérer les controllers.

## Vérification
Tester accepter, refuser, plus tard, déjà autorisé, erreur, double appui, retour d’arrière-plan et parcours de lancement suivant. Vérifier que « Plus tard » ne déclenche pas la permission, que le refus ne bloque pas l’accueil et que l’état visuel reflète la réponse réelle. Comparer visuellement le portage au prototype.

Validation déjà réalisée : parcours DOM simulés accepter/refuser/plus tard/continuer/rejouer. Aucun test natif de permission, d’envoi de notification ou de fluidité sur appareil n’a été effectué. Le pack ne contient pas de modification Flutter.

## Assets
Trois PNG transparents Microsoft Fluent Emoji, licence MIT jointe. Icônes Lucide 0.468.0 incorporées à l’aperçu, licence jointe. Utiliser la police Inter avec sa licence si elle est embarquée dans le projet. Le SHA-256 joint confirme que la référence est identique au prototype validé.
