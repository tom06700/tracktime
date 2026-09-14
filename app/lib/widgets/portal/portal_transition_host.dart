import 'package:flutter/material.dart';
import '../../motion.dart';
import 'portal_door_painter.dart';
import 'portal_geometry.dart';

typedef PortalStart = Future<void> Function(Rect stage, double phase);

class PortalScope extends InheritedWidget {
  const PortalScope({
    super.key,
    required this.start,
    required this.active,
    required super.child,
  });
  final PortalStart start;
  final bool active;
  static PortalScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PortalScope>();
  @override
  bool updateShouldNotify(PortalScope old) => old.active != active;
}

/// Preserves the four tab subtrees. Only the destination is clipped; no second
/// Explorer, screen capture or route is created for the transition.
class PortalTransitionHost extends StatefulWidget {
  const PortalTransitionHost({
    super.key,
    required this.index,
    required this.onSelected,
    required this.screens,
    required this.scaffoldBuilder,
    this.explorerIndex = 2,
  });
  final int index, explorerIndex;
  final ValueChanged<int> onSelected;
  final List<Widget> screens;
  final Widget Function(Widget body, Animation<double>? portal) scaffoldBuilder;
  @override
  State<PortalTransitionHost> createState() => _PortalTransitionHostState();
}

class _PortalTransitionHostState extends State<PortalTransitionHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  final _root = GlobalKey();
  Rect? _stage;
  double _phase = 0;
  bool get _active => _stage != null;
  double get _seconds => _motion.value * 2.2;
  @override
  void didUpdateWidget(PortalTransitionHost old) {
    super.didUpdateWidget(old);
    if (_active && old.index != widget.index) _motion.stop(canceled: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_active && reduceMotionOf(context)) _motion.value = 1;
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  Future<void> _start(Rect globalStage, double phase) async {
    if (_active || widget.index == widget.explorerIndex) return;
    if (reduceMotionOf(context)) {
      widget.onSelected(widget.explorerIndex);
      return;
    }
    final box = _root.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      widget.onSelected(widget.explorerIndex);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _stage = globalStage.shift(-box.localToGlobal(Offset.zero));
      _phase = phase;
    });
    try {
      await _motion.forward(from: 0).orCancel;
      if (mounted) widget.onSelected(widget.explorerIndex);
    } on TickerCanceled {
      // System back/disposal cancels the passage without changing the tab.
    } finally {
      if (mounted) setState(() => _stage = null);
    }
  }

  PortalGeometry _geometry(Size size) => PortalGeometry(
    stage: _stage!,
    viewport: size,
    phase: _phase,
    seconds: _seconds,
    travelling: true,
  );
  @override
  Widget build(BuildContext context) {
    return PortalScope(
      start: _start,
      active: _active,
      child: PopScope(
        canPop: !_active,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _active) _motion.stop(canceled: true);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final body = Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < widget.screens.length; i++)
                  Offstage(
                    offstage:
                        i != widget.index &&
                        !(_active && i == widget.explorerIndex),
                    child: TickerMode(
                      enabled:
                          i == widget.index ||
                          (_active && i == widget.explorerIndex),
                      child: IgnorePointer(
                        ignoring: _active,
                        child: ExcludeSemantics(
                          excluding: _active,
                          child: AnimatedBuilder(
                            animation: _motion,
                            child: widget.screens[i],
                            builder: (context, child) {
                              final destination = i == widget.explorerIndex;
                              return ClipPath(
                                clipper: _active && destination
                                    ? _PortalClipper(_geometry(size))
                                    : null,
                                child: Opacity(
                                  opacity: !_active
                                      ? 1
                                      : destination
                                      ? portalEase(.18, .65, _seconds)
                                      : 1 - portalEase(0, .42, _seconds),
                                  child: Transform.scale(
                                    scale: _active && destination
                                        ? 1.10 -
                                              .10 *
                                                  portalEase(.6, 2.2, _seconds)
                                        : 1,
                                    alignment: const Alignment(0, -.12),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
            return Stack(
              key: _root,
              fit: StackFit.expand,
              children: [
                widget.scaffoldBuilder(body, _active ? _motion : null),
                if (_active)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeSemantics(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const ValueKey('portal-traversal'),
                            painter: PortalDoorPainter(
                              geometry: _geometry,
                              repaint: _motion,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PortalClipper extends CustomClipper<Path> {
  _PortalClipper(this.geometry);
  final PortalGeometry geometry;
  @override
  Path getClip(Size size) => geometry.aperture;
  @override
  bool shouldReclip(_PortalClipper old) => true;
}
