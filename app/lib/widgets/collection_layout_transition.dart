import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../motion.dart';
import '../theme.dart';
import 'media_image.dart';
import 'collection_layout_icon.dart';
import 'modern_controls.dart';

enum CollectionMotion { cascade, films }

/// Focus envelope shared by the temporary blur and brightness.
double collectionFocusPulse(double phase) => phase < .43
    ? Curves.easeInOut.transform((phase / .43).clamp(0.0, 1.0))
    : 1 - Curves.easeInOut.transform(((phase - .43) / .57).clamp(0.0, 1.0));

/// Measures actual poster bounds across layouts; only visible posters fly.
/// The destination keeps its normal lazy list and its original interactions.
class CollectionLayoutTransition extends StatefulWidget {
  const CollectionLayoutTransition({
    super.key,
    required this.motion,
    required this.builder,
  });
  final CollectionMotion motion;
  final Widget Function(BuildContext context, bool compact) builder;
  @override
  State<CollectionLayoutTransition> createState() =>
      _CollectionLayoutTransitionState();
}

class _Shot {
  const _Shot(this.rect, this.poster);
  final Rect rect;
  final CollectionTransitionPoster poster;
}

class _Flight {
  const _Flight(
    this.from,
    this.to,
    this.poster,
    this.entering,
    this.leaving,
    this.fromRadius,
  );
  final Rect from, to;
  final CollectionTransitionPoster poster;
  final bool entering, leaving;
  final double fromRadius;
}

class _CollectionLayoutTransitionState extends State<CollectionLayoutTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final _surface = GlobalKey();
  final _anchors = <_CollectionTransitionPosterState>{};
  List<_Flight> _flights = [];
  bool _compact = false, _busy = false;
  bool? _pending;
  bool get cascade => widget.motion == CollectionMotion.cascade;
  int get totalMs => cascade ? 1020 : 705;
  double get elapsed => _clock.value * totalMs;
  double get handoff => !_busy
      ? 1
      : Curves.easeOut.transform(
          ((elapsed - (totalMs - 120)) / 120).clamp(0.0, 1.0),
        );
  double get artworkOpacity => !_busy || handoff > 0 ? 1 : 0;
  double get labelOpacity =>
      !_busy ? 1 : ((elapsed - (cascade ? 560 : 340)) / 230).clamp(0, 1);

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Map<Object, _Shot> _measure() {
    final surface = _surface.currentContext?.findRenderObject() as RenderBox?;
    if (surface == null || !surface.hasSize) return {};
    final result = <Object, _Shot>{};
    for (final anchor in _anchors) {
      final box = anchor.context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final rect = box.localToGlobal(Offset.zero, ancestor: surface) & box.size;
      if (rect.overlaps((Offset.zero & surface.size).inflate(80))) {
        result[anchor.widget.id] = _Shot(rect, anchor.widget);
      }
    }
    return result;
  }

  Future<void> select(bool compact) async {
    if (_busy) {
      _pending = compact;
      return;
    }
    if (compact == _compact) return;
    if (reduceMotionOf(context)) {
      setState(() => _compact = compact);
      return;
    }
    final before = _measure();
    _clock.value = 0;
    setState(() {
      _busy = true;
      _compact = compact;
      _flights = [
        for (final shot in before.values)
          _Flight(
            shot.rect,
            shot.rect,
            shot.poster,
            false,
            false,
            shot.poster.radius,
          ),
      ];
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final after = _measure();
    final size =
        (_surface.currentContext!.findRenderObject() as RenderBox).size;
    final ids = {...before.keys, ...after.keys}.take(18);
    setState(() {
      _flights = [
        for (final id in ids)
          _Flight(
            before[id]?.rect ?? after[id]!.rect.translate(0, size.height),
            after[id]?.rect ?? before[id]!.rect.translate(0, size.height),
            (after[id] ?? before[id])!.poster,
            !before.containsKey(id),
            !after.containsKey(id),
            (before[id] ?? after[id])!.poster.radius,
          ),
      ];
    });
    try {
      await _clock.forward().orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _flights = [];
    });
    final pending = _pending;
    _pending = null;
    if (pending != null) select(pending);
  }

  @override
  Widget build(BuildContext context) => _CollectionScope(
    owner: this,
    child: ClipRect(
      child: Stack(
        key: _surface,
        fit: StackFit.expand,
        children: [
          Builder(builder: (context) => widget.builder(context, _compact)),
          if (_busy)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: AnimatedBuilder(
                    animation: _clock,
                    builder: (context, _) {
                      final phase = _clock.value;
                      // A brief focus/brightness pulse, as in the approved Cascade demo.
                      final pulse = collectionFocusPulse(phase);
                      Widget layer = Stack(
                        children: [
                          for (var i = 0; i < _flights.length; i++)
                            _paintFlight(_flights[i], i),
                        ],
                      );
                      if (cascade) {
                        final light = 1 + .14 * pulse;
                        layer = ColorFiltered(
                          colorFilter: ColorFilter.matrix([
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            light,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]),
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 3 * pulse,
                              sigmaY: 3 * pulse,
                            ),
                            child: layer,
                          ),
                        );
                      }
                      return layer;
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _paintFlight(_Flight f, int i) {
    final delay = cascade ? math.min(i * 48, 240) : math.min(i * 22, 65);
    final t = ((elapsed - delay) / (cascade ? 780 : 640)).clamp(0.0, 1.0);
    final p = cascade ? _expo(t) : const Cubic(.22, 1, .36, 1).transform(t);
    final rect = Rect.lerp(f.from, f.to, p)!;
    return Positioned.fromRect(
      rect: rect,
      child: Opacity(
        opacity:
            (f.entering
                ? p
                : f.leaving
                ? 1 - p
                : 1) *
            (1 - handoff),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            ui.lerpDouble(f.fromRadius, f.poster.radius, p)!,
          ),
          child: MediaImage(
            sources: f.poster.sources,
            seed: f.poster.seed,
            alignment: f.poster.alignment,
          ),
        ),
      ),
    );
  }
}

double _expo(double t) => t == 0 || t == 1
    ? t
    : t < .5
    ? math.pow(2, 20 * t - 10) / 2
    : (2 - math.pow(2, -20 * t + 10)) / 2;

class _CollectionScope extends InheritedWidget {
  const _CollectionScope({required this.owner, required super.child});
  final _CollectionLayoutTransitionState owner;
  static _CollectionLayoutTransitionState? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CollectionScope>()?.owner;
  @override
  bool updateShouldNotify(_CollectionScope oldWidget) => true;
}

/// Anchor only the artwork: text and buttons are never stretched.
class CollectionTransitionPoster extends StatefulWidget {
  const CollectionTransitionPoster({
    super.key,
    required this.id,
    required this.sources,
    required this.seed,
    required this.child,
    this.radius = 18,
    this.alignment = Alignment.center,
  });
  final Object id;
  final List<String?> sources;
  final String seed;
  final Widget child;
  final double radius;
  final Alignment alignment;
  @override
  State<CollectionTransitionPoster> createState() =>
      _CollectionTransitionPosterState();
}

class _CollectionTransitionPosterState
    extends State<CollectionTransitionPoster> {
  _CollectionLayoutTransitionState? _owner;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _CollectionScope.of(context);
    if (next != _owner) {
      _owner?._anchors.remove(this);
      _owner = next;
      _owner?._anchors.add(this);
    }
  }

  @override
  void dispose() {
    _owner?._anchors.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = _owner;
    if (owner == null) return widget.child;
    return AnimatedBuilder(
      animation: owner._clock,
      child: widget.child,
      builder: (context, child) =>
          Opacity(opacity: owner.artworkOpacity, child: child),
    );
  }
}

class CollectionTransitionLabels extends StatelessWidget {
  const CollectionTransitionLabels({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final owner = _CollectionScope.of(context);
    if (owner == null) return child;
    return AnimatedBuilder(
      animation: owner._clock,
      child: child,
      builder: (context, child) => IgnorePointer(
        ignoring: owner._busy,
        child: Opacity(opacity: owner.labelOpacity, child: child),
      ),
    );
  }
}

class CollectionLayoutToggle extends StatelessWidget {
  const CollectionLayoutToggle({super.key, this.series = false});
  final bool series;
  @override
  Widget build(BuildContext context) {
    final owner = _CollectionScope.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TtColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final compact in [false, true])
            Semantics(
              selected: owner._compact == compact,
              child: IconButton(
                tooltip: compact
                    ? 'Vue d’ensemble'
                    : series
                    ? 'Grande carte'
                    : 'Grandes affiches',
                onPressed: () => owner.select(compact),
                icon: CollectionLayoutIcon(series: series, compact: compact),
                color: owner._compact == compact
                    ? ModernPalette.lilac
                    : TtColors.dim,
                style: IconButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: owner._compact == compact
                      ? ModernPalette.lilac.withValues(alpha: .12)
                      : Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
