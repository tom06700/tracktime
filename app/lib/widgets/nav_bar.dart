import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../brand/nitrate_brand.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Navigation flottante en verre fumé, avec un fond opaque en contraste élevé.
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
  static const double _height = 66;

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
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white.withValues(alpha: .12), width: .7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          height: _height + (MediaQuery.textScalerOf(context).scale(11) - 11).clamp(0.0, 22.0),
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

    final glass = opaque ? bar : ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: bar),
    );
    return Padding(padding: EdgeInsets.fromLTRB(14, 8, 14, bottomSafe + 8), child: glass);
  }
}

/// Onglet actif en ivoire, signalé aussi par un repère sous son libellé.
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
    final target = selected ? NitrateBrand.ivory : _inactive;

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
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
                  height: 3, width: selected ? 12 : 3,
                  decoration: BoxDecoration(color: selected ? NitrateBrand.ivory : Colors.transparent,
                    borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
