import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../motion.dart';
import '../../widgets/modern_controls.dart';

String _label(int season) => season == 0 ? 'Spéciaux' : 'Saison $season';

/// A compact trigger, with a thumb-accessible list for long-running series.
class SeasonSelector extends StatefulWidget {
  const SeasonSelector({
    super.key,
    required this.seasons,
    required this.selected,
    this.onChanged,
  });

  final List<int> seasons;
  final int selected;
  final ValueChanged<int?>? onChanged;

  @override
  State<SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends State<SeasonSelector> {
  bool _open = false;

  Future<void> _choose() async {
    if (_open || widget.onChanged == null) return;
    setState(() => _open = true);
    try {
      final selected = await showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: ModernPalette.surface,
        barrierColor: Colors.black54,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        sheetAnimationStyle: AnimationStyle(
          duration: motionOf(context, Motion.slow),
          reverseDuration: motionOf(context, Motion.normal),
        ),
        builder: (_) =>
            _SeasonSheet(seasons: widget.seasons, selected: widget.selected),
      );
      if (mounted && selected != null && selected != widget.selected) {
        widget.onChanged?.call(selected);
      }
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: widget.onChanged == null || widget.seasons.isEmpty
        ? null
        : _choose,
    style: OutlinedButton.styleFrom(
      foregroundColor: ModernPalette.text,
      backgroundColor: const Color(0xFF211E29),
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      side: BorderSide(
        color: ModernPalette.lilac.withValues(alpha: _open ? .55 : .18),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _label(widget.selected),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedRotation(
          turns: _open ? .5 : 0,
          duration: motionOf(context, Motion.normal),
          curve: Motion.enter,
          child: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: ModernPalette.lilac,
          ),
        ),
      ],
    ),
  );
}

class _SeasonSheet extends StatefulWidget {
  const _SeasonSheet({required this.seasons, required this.selected});
  final List<int> seasons;
  final int selected;

  @override
  State<_SeasonSheet> createState() => _SeasonSheetState();
}

class _SeasonSheetState extends State<_SeasonSheet> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context);
    final extent = math.max(60.0, scale.scale(15) * 1.4 + 28);
    final listHeight = math.min(
      extent * widget.seasons.length,
      MediaQuery.sizeOf(context).height * .48,
    );
    final index = widget.seasons.indexOf(widget.selected);
    _scroll ??= ScrollController(
      initialScrollOffset: (index * extent - (listHeight - extent) / 2).clamp(
        0.0,
        math.max(0.0, widget.seasons.length * extent - listHeight),
      ),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saisons',
                    style: TextStyle(
                      color: ModernPalette.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer les saisons',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: listHeight,
              child: Scrollbar(
                controller: _scroll,
                child: ListView.builder(
                  controller: _scroll,
                  padding: EdgeInsets.zero,
                  itemExtent: extent,
                  itemCount: widget.seasons.length,
                  itemBuilder: (context, i) {
                    final season = widget.seasons[i];
                    final active = season == widget.selected;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Semantics(
                        selected: active,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, season),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            foregroundColor: active
                                ? ModernPalette.lilac
                                : ModernPalette.text,
                            backgroundColor: active
                                ? ModernPalette.lilac.withValues(alpha: .12)
                                : Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _label(season),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (active)
                                const Icon(Icons.check_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
