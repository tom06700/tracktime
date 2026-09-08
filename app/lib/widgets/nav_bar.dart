import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modern_controls.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Approved clear capsule, shared with the peach Glide tabs.
class NitrateNavBar extends StatefulWidget {
  const NitrateNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  State<NitrateNavBar> createState() => _NitrateNavBarState();
}

class _NitrateNavBarState extends State<NitrateNavBar> {
  final _trackKey = GlobalKey();
  int? _dragIndex;

  void _selectAt(Offset position) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || widget.items.isEmpty) return;
    // Leaving the bar vertically pauses selection; the last visited tab stays.
    if (position.dy < -20 || position.dy > box.size.height + 20) return;
    final width = box.size.width - 12; // GlideControl's 6px inset on each side.
    if (width <= 0) return;
    var index = ((position.dx - 6) / (width / widget.items.length))
        .floor()
        .clamp(0, widget.items.length - 1);
    if (Directionality.of(context) == TextDirection.rtl) {
      index = widget.items.length - 1 - index;
    }
    if (index == _dragIndex) return;
    _dragIndex = index;
    if (index != widget.selectedIndex) {
      HapticFeedback.selectionClick();
      widget.onSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('navigation-foundation'),
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.paddingOf(context).bottom + 8,
    ),
    child: GestureDetector(
      key: _trackKey,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onHorizontalDragStart: (details) {
        _dragIndex = widget.selectedIndex;
        _selectAt(details.localPosition);
      },
      onHorizontalDragUpdate: (details) => _selectAt(details.localPosition),
      onHorizontalDragEnd: (_) => _dragIndex = null,
      onHorizontalDragCancel: () => _dragIndex = null,
      child: GlideControl(
        navigation: true,
        labels: widget.items.map((i) => i.label).toList(),
        icons: widget.items.map((i) => i.icon).toList(),
        index: widget.selectedIndex,
        onSelected: (i) {
          HapticFeedback.selectionClick();
          widget.onSelected(i);
        },
      ),
    ),
  );
}
