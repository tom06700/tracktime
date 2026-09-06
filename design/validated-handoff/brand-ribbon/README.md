# Identité ruban validée

Le propriétaire a validé le logo le 6 septembre 2026 et demandé son intégration
pour la prochaine fusion, sans livraison immédiate sur main.

Sources actives : `app/assets/brand/symbol-lilac.svg` et `lockup-lilac.svg`.
Le symbole et les lettres sont des contours vectorisés de la référence fournie,
sans substitution de police. Lilas #C5AEFD, noir #0D0E10, blanc #F7F2EF.

La signature est peinte en vectoriel dans l’accueil et les headers d’introduction.
Le symbole est repris dans la sphère animée, l’aperçu des notifications et les
splash screens. Les animations et les zones tactiles restent celles validées.
L’icône principale est noire sur lilas : catalogue iOS opaque, cinq densités
Android, couches adaptatives et monochrome Android 13. Les variantes SVG sombre
et monochrome sont conservées sans changement automatique d’apparence iOS.

`python3 scripts/build_brand.py` régénère les chemins Flutter et les PNG depuis
les SVG avec Pillow. Aucune dépendance Flutter supplémentaire. Les XML vectoriels
Android sont également inclus. Le pack source `design/brand-ribbon-review/`
reste préservé localement.

Vérifications locales : dimensions et opacité des icônes iOS, XML Android valides,
inspection des exports. Analyse, tests et captures Flutter : CI de la PR.
Masques du lanceur, splash et fluidité : contrôle sur appareil encore nécessaire.
