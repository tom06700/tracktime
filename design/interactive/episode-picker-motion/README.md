# Sélecteur d’épisode — aperçu V2

Lancer depuis la racine :

```sh
python3 -m http.server 8796 --bind 127.0.0.1 --directory design/interactive/episode-picker-motion
```

Ouvrir http://127.0.0.1:8796 dans Brave. Version initiale conservée dans `v1/`.

## Interaction

- Flèches : numéros sur rouleaux indépendants, largeur animée au passage 9 ↔ 10.
- Réglette : pointer capture, suivi horizontal, calage sur un épisode. Flèches du clavier, Home et End pris en charge.
- Poignée : suivi vertical, résistance vers le haut, fermeture selon déplacement et vitesse.
- Arrière-plan : recul et coins arrondis synchronisés avec le panneau.
- Saisie immédiate, validation 1–12, ouverture d’une fiche de démonstration.
- Ralenti ×3 et réduction des animations.

Adaptation originale à partir des principes publics de [NumberFlow](https://number-flow.barvian.me/) et [Vaul par Emil Kowalski](https://emilkowal.ski/ui/building-a-drawer-component). Aucun code de cours privé ni dépendance copiée. Titres de démonstration ; arrière-plan issu d’une capture locale de Nitrate. Aucun accès à la base de visionnages.

## Vérification

Syntaxe des scripts : `node --check`. Brave : rendu à la taille de fenêtre courante, flèches 9 → 10, réglette au clic et clavier, sélection et texte synchronisés. V1 : saisie invalide 99 rejetée, saisie 10 ouvrant la fiche correspondante, pressions successives et ralenti vérifiés. Le glissement continu de la poignée et de la réglette n’a pas été automatisé sur cette session. L’aperçu web n’est pas intégré à Flutter.
