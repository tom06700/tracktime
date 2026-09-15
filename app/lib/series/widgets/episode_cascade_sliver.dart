import 'package:flutter/material.dart';

import '../../motion.dart';

/// The selected V2 entrance: a single, finite timeline for a lazy episode list.
/// Key this widget by season/filter, never by watched state or item count.
class EpisodeCascadeSliver extends StatefulWidget {
  const EpisodeCascadeSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.itemIds,
    this.removedItemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext, int, EpisodeCascadeMotion) itemBuilder;
  final ChildIndexGetter? findChildIndexCallback;
  final List<int>? itemIds;
  final Widget Function(BuildContext, int, EpisodeCascadeMotion)?
  removedItemBuilder;

  @override
  State<EpisodeCascadeSliver> createState() => _EpisodeCascadeSliverState();
}

class _EpisodeCascadeSliverState extends State<EpisodeCascadeSliver>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _started = false;
  bool _scheduled = false;
  var _listKey = GlobalKey<SliverAnimatedListState>();
  late final List<int> _ids = List.of(widget.itemIds ?? const []);

  @override
  void didUpdateWidget(EpisodeCascadeSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.itemIds;
    if (incoming == null) return;
    final wanted = incoming.toSet();
    final existing = _ids.toSet();
    final changes =
        _ids.where((id) => !wanted.contains(id)).length +
        incoming.where((id) => !existing.contains(id)).length;
    // Hydration and whole-season updates must stay lazy: do not allocate
    // hundreds of independent insertion/removal controllers for One Piece.
    if ((!_started && _ids.isEmpty) || changes > 24) {
      _ids
        ..clear()
        ..addAll(incoming);
      _listKey = GlobalKey<SliverAnimatedListState>();
      return;
    }
    final list = _listKey.currentState;
    if (list == null) {
      _ids
        ..clear()
        ..addAll(incoming);
      return;
    }
    final duration = motionOf(context, const Duration(milliseconds: 440));
    void remove(int index) {
      final id = _ids.removeAt(index);
      final builder = widget.removedItemBuilder;
      list.removeItem(
        index,
        (context, animation) => IgnorePointer(
          child: ExcludeSemantics(
            child: _EpisodeSizeTransition(
              sizeFactor: animation.drive(
                CurveTween(
                  curve: const Interval(0, .66, curve: Curves.easeOutCubic),
                ),
              ),
              child: FadeTransition(
                opacity: animation.drive(
                  CurveTween(
                    curve: const Interval(.35, 1, curve: Curves.easeOut),
                  ),
                ),
                child:
                    builder?.call(
                      context,
                      id,
                      const EpisodeCascadeMotion(kAlwaysCompleteAnimation, 0),
                    ) ??
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        duration: duration,
      );
    }

    for (var i = _ids.length - 1; i >= 0; i--) {
      if (!wanted.contains(_ids[i])) remove(i);
    }
    for (var i = 0; i < incoming.length; i++) {
      if (i < _ids.length && _ids[i] == incoming[i]) continue;
      final previous = _ids.indexOf(incoming[i]);
      if (previous >= 0) remove(previous);
      _ids.insert(i, incoming[i]);
      list.insertItem(
        i,
        duration: motionOf(context, const Duration(milliseconds: 220)),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _started = true;
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      // Slivers can be laid out in the cache before they reach the screen.
      // Do not spend the entrance while the user is still above the list.
      if (!_started &&
          !_scheduled &&
          widget.itemCount > 0 &&
          constraints.remainingPaintExtent > 0) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scheduled = false;
          if (!mounted || _started || widget.itemCount == 0) return;
          _started = true;
          _controller.forward();
        });
      }
      Widget item(BuildContext context, int dataIndex, int motionIndex) {
        final motion = EpisodeCascadeMotion(_controller, motionIndex);
        final child = widget.itemBuilder(context, dataIndex, motion);
        return KeyedSubtree(key: child.key, child: motion.row(child));
      }

      if (widget.itemIds != null) {
        final dataIndexes = {
          for (var i = 0; i < widget.itemIds!.length; i++)
            widget.itemIds![i]: i,
        };
        return SliverAnimatedList(
          key: _listKey,
          initialItemCount: _ids.length,
          findChildIndexCallback: widget.findChildIndexCallback,
          itemBuilder: (context, index, animation) {
            final child = item(context, dataIndexes[_ids[index]]!, index);
            return _EpisodeSizeTransition(
              key: child.key,
              sizeFactor: animation,
              child: FadeTransition(opacity: animation, child: child),
            );
          },
        );
      }
      return SliverList.builder(
        itemCount: widget.itemCount,
        findChildIndexCallback: widget.findChildIndexCallback,
        itemBuilder: (context, index) {
          return item(context, index, index);
        },
      );
    },
  );
}

/// Top-anchored vertical reveal, compatible with both the local Flutter 3.41
/// and newer CI SDKs (SizeTransition's alignment API differs between them).
class _EpisodeSizeTransition extends AnimatedWidget {
  const _EpisodeSizeTransition({
    super.key,
    required Animation<double> sizeFactor,
    required this.child,
  }) : super(listenable: sizeFactor);

  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Align(
      alignment: AlignmentDirectional.topStart,
      heightFactor: (listenable as Animation<double>).value.clamp(
        0.0,
        double.infinity,
      ),
      child: child,
    ),
  );
}

/// Paint-only transitions; titles and statuses are not rebuilt on each tick.
class EpisodeCascadeMotion {
  const EpisodeCascadeMotion(this._timeline, this._index);
  final Animation<double> _timeline;
  final int _index;
  static const _curve = Cubic(.2, .75, .2, 1);

  Animation<double> _phase(int duration, [int delay = 0]) {
    // Additional visible rows join the last wave instead of appearing early
    // below a gap. Lazy rows created after 800 ms are already fully visible.
    final start = _index.clamp(0, 5) * 56 + delay;
    return _timeline.drive(
      CurveTween(
        curve: Interval(start / 800, (start + duration) / 800, curve: _curve),
      ),
    );
  }

  Widget row(Widget child) => _rise(child, _phase(520), 20);
  Widget title(Widget child) => _rise(child, _phase(400, 45), 4);
  Widget status(Widget child) =>
      FadeTransition(opacity: _phase(320, 110), child: child);

  Widget _rise(Widget child, Animation<double> progress, double distance) =>
      FadeTransition(
        opacity: progress,
        child: AnimatedBuilder(
          animation: progress,
          child: child,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, distance * (1 - progress.value)),
            child: child,
          ),
        ),
      );
}
