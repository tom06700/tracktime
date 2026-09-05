# Pellicule — source de motion design

La courbe principale possède deux Bézier cubiques dans un espace 400 × 280 :
M(-65,190) C(75,258 90,45 225,93) C(300,120 316,185 465,74).
La bande mesure 86 unités, avec huit photogrammes et six perforations par
photogramme et par bord. Aucun visuel de catalogue inventé.

La version Flutter est `app/lib/onboarding/filmstrip_painter.dart` : ouverture
sur 1,8 s, déplacement d’un pas sur 6 s, jointure périodique. Le mot-symbole
se révèle après 35 % de l’entrée. Le texte de l’écran et les boutons ne bougent
pas. Animation arrêtée en arrière-plan et en réduction des animations.

Le dessin SVG modifiable `filmstrip.svg` est généré par
`scripts/build_filmstrip_source.py` à partir des mêmes points de contrôle.
Glaxnimate 0.6.0 Intel est installé dans ~/Applications/glaxnimate.app : minimum
macOS 13 vérifié, signature et notarisation Apple acceptées, export PNG exécuté
et dessin SVG ouvert dans l’éditeur. Le PNG inspecté est une étude vectorielle,
pas une capture de l’app. L’animation runtime reste en Flutter ; aucun export
Lottie animé ni plugin MCP n’est utilisé.

Validation artistique native encore requise : la validité du dessin et des
calculs ne prouve ni sa finition visuelle ni sa fluidité sur iPhone.
