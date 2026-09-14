import 'package:flutter/material.dart';
import '../../motion.dart';
import '../../theme.dart';
import '../modern_controls.dart';
import '../common.dart';
import 'portal_door_painter.dart';
import 'portal_geometry.dart';
import 'portal_transition_host.dart';

class PortalEmpty extends StatefulWidget {
  const PortalEmpty({super.key, required this.onExplore, this.movies = false});
  final VoidCallback onExplore;
  final bool movies;
  @override
  State<PortalEmpty> createState() => _PortalEmptyState();
}

class _PortalEmptyState extends State<PortalEmpty>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  final _door = GlobalKey();
  bool _opening = false, _resumed = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  void _updateMotion() {
    final enabled =
        _resumed &&
        TickerMode.valuesOf(context).enabled &&
        !reduceMotionOf(context) &&
        !(PortalScope.maybeOf(context)?.active ?? false);
    if (enabled && !_breath.isAnimating) {
      _breath.repeat();
    } else if (!enabled) {
      _breath.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _breath.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    if (_opening) return;
    final scope = PortalScope.maybeOf(context),
        box = _door.currentContext?.findRenderObject() as RenderBox?;
    if (scope == null || box == null) {
      widget.onExplore();
      return;
    }
    setState(() => _opening = true);
    try {
      await scope.start(
        box.localToGlobal(Offset.zero) & box.size,
        _breath.value,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = PortalScope.maybeOf(context)?.active ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxHeight - bottomNavInset(context) - 220)
            .clamp(180.0, 290.0);
        return SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomNavInset(context) + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Traverser la porte vers Explorer',
                button: true,
                onTap: _enter,
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: _enter,
                    behavior: HitTestBehavior.opaque,
                    child: FocusableActionDetector(
                      actions: {
                        ActivateIntent: CallbackAction<ActivateIntent>(
                          onInvoke: (_) {
                            _enter();
                            return null;
                          },
                        ),
                      },
                      child: SizedBox(
                        key: _door,
                        width: double.infinity,
                        height: height,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: active
                                ? null
                                : PortalDoorPainter(
                                    repaint: _breath,
                                    geometry: (size) => PortalGeometry(
                                      stage: Offset.zero & size,
                                      viewport: size,
                                      phase: _breath.value,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    Text(
                      widget.movies
                          ? 'Ton prochain film t’attend.'
                          : 'Un nouveau monde t’attend.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w500,
                        height: 1.13,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.movies
                          ? 'Ajoute les films que tu veux voir.\nTes prochaines découvertes commencent ici.'
                          : 'Ajoute une série pour retrouver\nici tes prochains épisodes.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: TtColors.dim,
                      ),
                    ),
                    const SizedBox(height: 25),
                    FilledButton(
                      onPressed: _opening ? null : _enter,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 51),
                        backgroundColor: ModernPalette.lilac,
                        foregroundColor: const Color(0xFF271B3B),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              widget.movies
                                  ? 'Explorer les films'
                                  : 'Explorer les séries',
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.north_east, size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Une place pour tes prochaines découvertes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: Color(0xFF807687)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
