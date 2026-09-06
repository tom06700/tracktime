# Portage des deux packs validés

Références : pack principal et complément notifications, empreintes SHA-256
vérifiées à l’extraction. Les originaux sont conservés localement dans
`nitrate-codex-handoff/` et `nitrate-notifications-codex/`. Les aperçus suivis
ici utilisent les mêmes sources, remplacent les images embarquées par les PNG
et la police du dépôt, et omettent les affiches de démonstration du mini-accueil.
Ils restent des documents de référence, pas une cible web de l’application.

## Parcours

Premier lancement : envol → explication notifications → collection existante.
« Passer » sur l’envol rejoint la deuxième étape. « Plus tard » poursuit sans
demande système. Le WelcomeGate existant mémorise la fin du parcours ; les
utilisateurs ayant déjà terminé l’accueil ne sont pas interrompus à la mise
à jour. Réglages → Découvrir Nitrate permet de revoir les deux étapes.
Réglages → Notifications donne aussi accès à la permission.

La page ne demande rien à son apparition. Le bouton interroge le statut et
appelle l’API native uniquement si le choix est indéterminé. Un refus permet
de continuer ; ouvrir les réglages reste une action explicite. Le statut est
relu au retour de l’application. Une erreur ne devient jamais une autorisation.

**Aucun service d’envoi ou de planification des sorties n’existe dans ce dépôt.**
La page et sa confirmation l’indiquent. Pas de Firebase, enregistrement APNs,
backend ou fausse notification ajoutés par ce portage. La future livraison
d’alertes sans spoilers constitue un chantier distinct.

Les dialogues système sont ceux des plateformes. Le canal Flutter utilise
UNUserNotificationCenter sur iOS et POST_NOTIFICATIONS à partir d’Android 13,
avec lecture du réglage effectif sur les versions antérieures. Aucune nouvelle
dépendance Flutter.

Sources officielles consultées le 6 septembre 2026 :
- https://docs.flutter.dev/platform-integration/platform-channels
- https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- https://developer.android.com/develop/ui/compose/notifications/notification-permission

## Commandes et collection

Soft check, Attach, Next up, Glide, Surprise et navigation sont des widgets
Flutter reliés aux actions existantes. Les filtres Films et Explorer partagent
Glide. Ajouter n’est pas supprimer ; ouvrir n’enregistre aucun visionnage ;
la confirmation dépend d’une écriture réussie et le dernier épisode peut être
annulé depuis la confirmation. Les titres, images et compteurs du HTML ne sont
pas utilisés comme données utilisateur.

L’image, le titre et les actions À reprendre défilent ensemble. La sélection
de source du héros conserve le garde-fou existant sur les dimensions décodées :
une image trop petite pour l’écran est écartée au profit d’une source de la même
œuvre. Si aucune source ne convient, le fond reste sobre.

## Vérification

Flutter analyse, tests de composants et captures natives de widgets s’exécutent
sur Linux dans Actions. Les comparaisons utilisent une largeur de 390 pixels
logiques. Les cadres, crédits et boutons Rejouer des prototypes sont hors
périmètre de l’interface native. Les instantanés de l’envol sont pris à des phases
différentes ; ses équations, phases déterministes et durées sont portées du JS.

La compilation native sans publication vérifie séparément Swift/iOS et
Kotlin/Android. Elle ne teste pas la réponse d’un vrai dialogue sur appareil.
L’essai physique iPhone, VoiceOver et la fluidité mesurée restent à effectuer.
Les captures de widgets ne certifient pas les performances iPhone.

## Compatibilité Android vérifiée par compilation

Le projet utilise AGP 9, mais share_plus 12 nécessite encore le plugin Kotlin
classique. Le mode `android.builtInKotlin=false` est donc conservé et le module
app applique explicitement KGP. file_picker 11.0.2 omet à tort KGP sous AGP 9,
ce qui exclut sa classe FilePickerPlugin du build. Un script Gradle limité à ce
plugin applique le correctif de compatibilité publié dans son changelog beta.3,
sans changer l’API d’import ni relever la version minimale iOS. Il pourra être
retiré lors d’une migration délibérée de file_picker. Le manifeste utilise
Nitrate comme nom présenté par Android.

Références :
- https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers
- https://pub.dev/packages/file_picker/changelog#1200-beta3
