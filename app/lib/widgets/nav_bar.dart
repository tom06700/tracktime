import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modern_controls.dart';
import 'native_glass_navigation.dart';

class NavItem {
  const NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Native Apple glass on supported iOS; the existing capsule elsewhere.
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

  int? _indexAt(Offset position, {double verticalTolerance = 20}) {
    final box = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || widget.items.isEmpty) return null;
    // Leaving the bar vertically pauses selection; the last visited tab stays.
    if (position.dy < -verticalTolerance ||
        position.dy > box.size.height + verticalTolerance) {
      return null;
    }
    final width = box.size.width - 12; // GlideControl's 6px inset on each side.
    if (width <= 0) return null;
    var index = ((position.dx - 6) / (width / widget.items.length))
        .floor()
        .clamp(0, widget.items.length - 1);
    if (Directionality.of(context) == TextDirection.rtl) {
      index = widget.items.length - 1 - index;
    }
    return index;
  }

  void _selectAt(Offset position) {
    final index = _indexAt(position);
    if (index == null || index == _dragIndex) return;
    setState(() => _dragIndex = index);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('navigation-foundation'),
    padding: EdgeInsets.fromLTRB(
      0,
      8,
      0,
      MediaQuery.paddingOf(context).bottom + 8,
    ),
    child: NativeGlassNavigation(
      labels: widget.items.map((i) => i.label).toList(),
      symbols: widget.items
          .map(
            (i) => switch (i.icon) {
              Icons.tv_outlined => 'tv',
              Icons.movie_outlined => 'film',
              Icons.travel_explore_outlined => 'globe',
              Icons.person_outline => 'person',
              _ => 'circle',
            },
          )
          .toList(),
      index: widget.selectedIndex,
      onSelected: (i) {
        // UIKit emits only committed selections, including accessibility.
        if (_dragIndex != null || i == widget.selectedIndex) return;
        HapticFeedback.selectionClick();
        widget.onSelected(i);
      },
      fallback: Listener(
        onPointerCancel: (_) => setState(() => _dragIndex = null),
        child: GestureDetector(
          key: _trackKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          // Gestures for Android and older iOS. UIKit owns supported iOS input.
          onTapUp: (details) {
            final index = _indexAt(details.localPosition, verticalTolerance: 0);
            if (index == null || index == widget.selectedIndex) return;
            HapticFeedback.selectionClick();
            widget.onSelected(index);
          },
          onHorizontalDragStart: (details) {
            _dragIndex = widget.selectedIndex;
            _selectAt(details.localPosition);
          },
          onHorizontalDragUpdate: (details) => _selectAt(details.localPosition),
          onHorizontalDragEnd: (_) {
            final destination = _dragIndex;
            setState(() => _dragIndex = null);
            if (destination != null && destination != widget.selectedIndex) {
              widget.onSelected(destination);
            }
          },
          onHorizontalDragCancel: () => setState(() => _dragIndex = null),
          child: GlideControl(
            navigation: true,
            labels: widget.items.map((i) => i.label).toList(),
            icons: widget.items.map((i) => i.icon).toList(),
            index: _dragIndex ?? widget.selectedIndex,
            onSelected: (i) {
              HapticFeedback.selectionClick();
              widget.onSelected(i);
            },
          ),
        ),
      ),
    ),
  );
}
