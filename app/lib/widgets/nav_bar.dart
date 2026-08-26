import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Navigation principale : un socle sobre ancré au bas de l'écran.
///
/// Pas de capsule flottante, pas d'ombre portée, pas d'arête lumineuse — la
/// barre se lit comme la navigation du système plutôt que comme un widget
/// décoratif posé par-dessus. Le contenu défile derrière un fond assombri et
/// flouté, séparé par un simple filet.
class NitrateNavBar extends StatelessWidget {
  const NitrateNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Hauteur utile, hors safe area. Contient confortablement icône et
  /// libellé, et dépasse les 44 px de zone tactile recommandés.
  static const double _height = 54;

  @override
  Widget build(BuildContext context) {
    // `padding` et non `viewPadding` : la réserve du Home Indicator disparaît
    // quand le clavier est ouvert, donc pas de vide au-dessus du clavier
    // dans Explorer.
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final opaque = MediaQuery.highContrastOf(context);

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: TtColors.bg.withValues(alpha: opaque ? 1 : 0.82),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafe),
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
                      // Retaper l'onglet courant ne doit rien produire : ni
                      // vibration, ni reconstruction.
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
    );

    if (opaque) return bar;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: bar,
      ),
    );
  }
}

/// Un onglet. L'état actif ne tient qu'à la couleur — icône et libellé
/// passent en ambre — sans capsule, bordure, halo ni agrandissement.
class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Plus clair que TtColors.dim : les icônes doivent rester lisibles
  /// au-dessus du décor animé du Profil (contraste ≥ 4.5:1).
  static const _inactive = Color(0xFF9BA3B7);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = selected ? TtColors.amber : _inactive;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ExcludeSemantics(
          // Une seule couche animée pour l'onglet entier : la couleur pilote
          // à la fois l'icône et le libellé.
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(begin: target, end: target),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            builder: (context, color, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: color,
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
