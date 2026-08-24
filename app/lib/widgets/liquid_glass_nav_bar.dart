import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'glass.dart';

class NavItem {
  const NavItem(
      {required this.icon, required this.activeIcon, required this.label});

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barre de navigation flottante « Liquid Glass » : pilule translucide avec
/// flou + vibrance (le contenu défile derrière, couleurs ravivées), lensing
/// sur le pourtour, arête spéculaire, et pastille ambrée sous l'onglet actif.
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

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomSafe > 0 ? bottomSafe : 14),
      child: GlassShadow(
        borderRadius: 32,
        child: GlassSurface(
          borderRadius: 32,
          blurSigma: 16,
          tintOpacity: 0.52,
          lensing: true,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () {
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

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  // Plus clair que TtColors.dim : les icônes doivent rester lisibles
  // au-dessus d'un fond mouvant (contraste ≥ 4.5:1).
  static const _inactive = Color(0xFFBAC1D4);

  @override
  Widget build(BuildContext context) {
    final color = selected ? TtColors.amber : _inactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        TtColors.amber.withValues(alpha: 0.26),
                        TtColors.amber.withValues(alpha: 0.12),
                      ],
                    )
                  : null,
              border: selected
                  ? Border.all(
                      color: TtColors.amber.withValues(alpha: 0.22), width: 1)
                  : Border.all(color: Colors.transparent, width: 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: TtColors.amber.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: -3,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedScale(
              scale: selected ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Icon(selected ? item.activeIcon : item.icon,
                  size: 22, color: color),
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: color,
              letterSpacing: 0.1,
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
