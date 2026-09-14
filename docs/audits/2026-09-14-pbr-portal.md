# Prototype PBR — Nitrate

Prototype demandé et approuvé : comparer la porte validée avec un vrai moteur
PBR avant de remplacer la version des états vides. Entrée hors release :
Réglages → Portail · Studio 3D ; route /_preview/portal-pbr.

## Rendu et comparaison

Thermion Flutter/Dart 0.5.0, Filament, SDK Flutter local 3.41.9 inchangé. Modèle
exporté directement du constructeur Three.js validé, avec ses dimensions,
biseaux et matériaux. Source reproductible : export-portal-glb.mjs. GLB final
794384 octets, 8 maillages, charnière DoorPivot et racine PortalRoot.

Environnement original de studio, préparé par cmgen Filament 1.69.1 : 6 faces
256 px, 5 niveaux de rugosité, coefficients SH vérifiés ; 2095444 octets.
Générateur et provenance : STUDIO_ENVIRONMENT.md. Matériaux céramique/métal,
ombres portées réelles sur sol à transparence radiale, source principale,
contre-éclairage violet et petite lumière chaude dans l’ouverture.

Le même viewer et la même surface transparente sont conservés entre repos,
comparaison Actuel/Studio 3D et traversée de 2,2 s. Le véritable Explorer reste
monté derrière le masque. Le panneau permet pause, vue rapprochée et rejeu.
La boucle au repos dure 7 s. La caméra Filament, la charnière et la projection
asymétrique reprennent les calculs du masque Flutter.

Les mises à jour natives sont sérialisées, avec remplacement de la pose en
attente. La surface est plafonnée à une densité 2× et le moteur à 60 Hz.
Le rendu caché/en arrière-plan est arrêté ; une vue visible figée reçoit une
image à la demande. Le passage interrompu par l’arrière-plan est annulé.
Le viewer et les textures sont libérés à la fermeture, moteur global réutilisé.

## Vérifications

11 tests ciblés passent : projection PBR/masque Flutter pendant la traversée,
charnière au départ, comportements existants du portail et cache des affiches.
Analyse statique des nouveaux fichiers sans diagnostic.
Première installation iOS profile réussie ; apparition du modèle et accès au
vrai Explorer confirmés sur l’iPhone physique. Raffinement du sol après revue
visuelle (la première version montrait un rectangle gris).

La revue a corrigé la recréation de la surface, l’écrasement de la projection
par le widget standard, la saturation de l’allocation par les ticks, l’arrivée
prématurée lors du passage en arrière-plan et le rendu invisible en comparaison.

La résolution a sélectionné notamment path_provider_foundation 2.5.1,
objective_c 8.1.0, hooks 1.0.3 et code_assets 1.0.0 pour les contraintes Thermion.
Le build profile observé pèse environ 48 Mio sur disque ; ceci n’est ni le poids
du téléchargement App Store ni un comparatif release. Android est pris en
charge par la dépendance, mais n’a pas été validé sur matériel pour ce prototype.

Documentation consultée : https://thermion.dev/quickstart/ et code des packages
0.5.0 effectivement résolus. Aucun changement des collections, commit ou push.

## Dernière session iPhone

Comparaison Actuel/Studio 3D, Détails, Pause et arrivée dans Explorer observés
sur le téléphone. Un dernier essai a toutefois révélé un SIGABRT Filament :
« SwapChain must remain valid until endFrame is called ». La trace passe par
ThermionViewer.renderSingleFrame : begin/render/end sont des appels asynchrones
séparés, susceptibles de s'entrelacer avec le scheduler natif. Le rendu statique
utilise désormais renderManager.render(), qui soumet une frame complète au
thread natif, puis désactive la vue. Aucun patch du cache de dépendances.

Analyse statique à nouveau sans diagnostic. Build profile corrigé réussi
(31,9 s), installation/lancement réussis (11,4 s). Log :
/tmp/nitrate-pbr-safe-frame.log. L'iPhone a disparu de l'USB pendant la dernière
séquence de vérification ; aucun nouveau crash dans le log avant « Lost
connection to device ». La correction du crash reste donc à confirmer par
plusieurs cycles pause/détails/traversée/rejeu sur matériel. L'enregistrement
final n'a pas été produit (timeout de l'arbre UI lors du crash précédent).
Aucune mesure finale fiable de fluidité à revendiquer.

Arrêt du bridge demandé après la déconnexion : MobAI répond HTTP 404 « device
not found ». Son arrêt n'est donc pas confirmé ; à terminer dès reconnexion.
