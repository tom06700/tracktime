import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'glass.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Durée commune des transitions d'onglet. Assez courte pour rester calme,
/// assez longue pour ne pas paraître sèche.
const Duration kNavTransition = Duration(milliseconds: 200);

/// Barre de navigation flottante en verre.
///
/// L'onglet actif se lit à trois signaux seulement — couleur de l'icône,
/// graisse du libellé, barre ambrée — au lieu d'une capsule à dégradé,
/// bordure et halo qui faisait ressembler l'onglet à un bouton posé sur la
/// barre.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double _height = 60;
  static const double _radius = 30;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, bottomSafe > 0 ? bottomSafe : 14),
      child: GlassShadow(
        borderRadius: _radius,
        blurRadius: 22,
        opacity: 0.26,
        offset: const Offset(0, 6),
        child: GlassSurface(
          borderRadius: _radius,
          blurSigma: 14,
          // Assez opaque pour isoler les icônes du décor animé du Profil,
          // assez transparent pour que le contenu qui défile reste perceptible.
          tintOpacity: 0.44,
          // Pas de lensing ni d'arête franche : le contour ne doit que
          // suggérer le verre, pas capter le regard avant les icônes.
          edgeOpacity: 0.42,
          child: SizedBox(
            height: _height,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavTab(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () {
                        // Pas de retour haptique quand on retape l'onglet déjà
                        // ouvert : rien ne change, rien à signaler.
                        if (i == selectedIndex) return;
                        HapticFeedback.selectionClick();
                        onSelected(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  // Plus clair que TtColors.dim : les icônes doivent rester lisibles
  // au-dessus d'un fond mouvant (contraste ≥ 4.5:1).
  static const _inactive = Color(0xFF9BA3B7);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduceMotion ? Duration.zero : kNavTransition;

    return Semantics(
      button: true,
      selected: selected,
      // Onglets mutuellement exclusifs : VoiceOver annonce la sélection au
      // sein d'un groupe plutôt que comme un bouton isolé.
      inMutuallyExclusiveGroup: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // La zone tactile occupe toute la hauteur de la barre et le quart de
        // sa largeur : bien au-delà des 44×44 recommandés.
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.05 : 1.0,
                duration: duration,
                curve: Curves.easeOutCubic,
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 22,
                  color: selected ? TtColors.amber : _inactive,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: duration,
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? TtColors.text : _inactive,
                  letterSpacing: 0.1,
                ),
                child: Text(item.label),
              ),
              const SizedBox(height: 4),
              _ActiveIndicator(selected: selected, duration: duration),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre ambrée sous l'onglet actif : apparaît en fondu et s'étire
/// horizontalement. Elle occupe toujours sa hauteur, pour que la bascule d'un
/// onglet à l'autre ne déplace jamais les libellés.
class _ActiveIndicator extends StatelessWidget {
  const _ActiveIndicator({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      child: AnimatedOpacity(
        opacity: selected ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: selected ? 20 : 8,
          decoration: BoxDecoration(
            color: TtColors.amber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
