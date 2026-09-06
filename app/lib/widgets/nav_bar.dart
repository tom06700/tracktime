import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'modern_controls.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Approved clear capsule, shared with the peach Glide tabs.
class NitrateNavBar extends StatelessWidget {
  const NitrateNavBar(
      {super.key,
      required this.items,
      required this.selectedIndex,
      required this.onSelected});
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => ColoredBox(
        key: const ValueKey('navigation-foundation'),
        color: TtColors.bg,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.paddingOf(context).bottom + 8),
            child: GlideControl(
                navigation: true,
                labels: items.map((i) => i.label).toList(),
                icons: items.map((i) => i.icon).toList(),
                index: selectedIndex,
                onSelected: (i) {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                })),
      );
}
