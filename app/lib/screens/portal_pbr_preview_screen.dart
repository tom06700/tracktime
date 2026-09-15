import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../motion.dart';
import '../widgets/modern_controls.dart';
import '../widgets/portal/portal_door_painter.dart';
import '../widgets/portal/portal_geometry.dart';
import '../widgets/portal/pbr/portal_pbr_renderer.dart';
import 'explorer_screen.dart';

/// Comparison lab accessible from Settings, including TestFlight builds.
/// Collections stay intact.
class PortalPbrPreviewScreen extends StatefulWidget {
  const PortalPbrPreviewScreen({super.key});
  @override
  State<PortalPbrPreviewScreen> createState() => _PortalPbrPreviewScreenState();
}

class _PortalPbrPreviewScreenState extends State<PortalPbrPreviewScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..addListener(_tick);
  late final _passage = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..addListener(_tick);
  final _pose = ValueNotifier(
    PortalGeometry(
      stage: const Rect.fromLTWH(0, 20, 402, 330),
      viewport: const Size(402, 760),
      phase: 0,
    ),
  );
  Size _size = const Size(402, 760);
  bool _pbr = true,
      _ready = false,
      _entering = false,
      _arrived = false,
      _resumed = true,
      _paused = false,
      _details = false;
  bool _reduced = false;
  double _startPhase = 0;
  String? _error;
  Timer? _loadingTimeout;
  bool get _rendering => _pbr && !_arrived && _resumed && !_paused && !_reduced;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadingTimeout = Timer(const Duration(seconds: 40), () {
      if (mounted && !_ready) {
        setState(
          () => _error =
              'Le studio 3D prend plus de temps à démarrer. Tu peux revenir à la version actuelle.',
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = reduceMotionOf(context);
    _syncClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (!_resumed) {
      _breath.stop();
      if (_entering) _reset();
    } else {
      _syncClock();
    }
    if (mounted) setState(() {});
  }

  void _syncClock() {
    if (_resumed && !_reduced && !_paused && !_entering && !_arrived) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
    }
  }

  Rect get _stage => Rect.fromLTWH(
    0,
    18,
    _size.width,
    math.min(_size.height * .54, _details ? 430 : 340) * (_details ? 1.18 : 1),
  );
  void _tick() {
    if (!mounted) return;
    _pose.value = PortalGeometry(
      stage: _stage,
      viewport: _size,
      phase: _entering ? _startPhase : _breath.value,
      seconds: _passage.value * 2.2,
      travelling: _entering,
    );
  }

  Future<void> _enter() async {
    if (_entering || _arrived || (_pbr && !_ready)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_reduced) {
      setState(() => _arrived = true);
      _syncClock();
      return;
    }
    _startPhase = _breath.value;
    _breath.stop();
    setState(() => _entering = true);
    try {
      await _passage.forward(from: 0).orCancel;
      if (mounted) {
        setState(() {
          _entering = false;
          _arrived = true;
        });
      }
    } on TickerCanceled {
      /* Back cancels without selecting a destination. */
    }
  }

  void _reset() {
    _passage.stop();
    setState(() {
      _entering = false;
      _arrived = false;
    });
    _passage.value = 0;
    _tick();
    _syncClock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingTimeout?.cancel();
    _breath.dispose();
    _passage.dispose();
    _pose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_entering,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _entering) _reset();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF101113),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101113),
        title: Text(
          _arrived ? 'Explorer' : 'Le passage · Studio',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (_arrived)
            TextButton(onPressed: _reset, child: const Text('Revoir la porte')),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (size != _size) {
            _size = size;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _tick();
            });
          }
          return ValueListenableBuilder<PortalGeometry>(
            valueListenable: _pose,
            child: PortalPbrRenderer(
              pose: _pose,
              enabled: _rendering,
              active: _pbr && !_arrived && _resumed,
              onReady: () {
                if (mounted) {
                  _loadingTimeout?.cancel();
                  setState(() {
                    _ready = true;
                    _error = null;
                  });
                }
              },
              onError: (error) {
                if (mounted) {
                  setState(() {
                    _ready = false;
                    _error =
                        'Le studio 3D n’a pas pu démarrer. La version actuelle reste disponible.';
                  });
                }
              },
            ),
            builder: (context, g, renderer) => Stack(
              fit: StackFit.expand,
              children: [
                // The same real Explorer remains mounted across every replay.
                Offstage(
                  offstage: !_entering && !_arrived,
                  child: IgnorePointer(
                    ignoring: !_arrived,
                    child: ClipPath(
                      clipper: _entering ? _Aperture(g) : null,
                      child: Opacity(
                        opacity: _arrived ? 1 : portalEase(.18, .65, g.seconds),
                        child: Transform.scale(
                          scale: _arrived
                              ? 1
                              : 1.10 - .10 * portalEase(.6, 2.2, g.seconds),
                          alignment: const Alignment(0, -.12),
                          child: const ExplorerScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Offstage(
                    offstage: _arrived || !_pbr,
                    child: CustomPaint(painter: _Interior(g)),
                  ),
                ),
                // Keep the native surface mounted; switching the comparison pauses
                // Filament rather than repeatedly allocating engines and textures.
                IgnorePointer(
                  child: Opacity(
                    opacity: _pbr && !_arrived
                        ? 1 - portalEase(1.78, 1.95, g.seconds)
                        : 0,
                    child: renderer,
                  ),
                ),
                if (!_arrived && !_pbr)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: PortalDoorPainter(geometry: (_) => g),
                    ),
                  ),
                if (!_arrived)
                  IgnorePointer(
                    ignoring: _entering,
                    child: Opacity(
                      opacity: _entering
                          ? 1 - portalEase(0, .42, g.seconds)
                          : 1,
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: _stage,
                            child: Semantics(
                              button: true,
                              label: 'Traverser la porte 3D',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _enter,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 26,
                            right: 26,
                            top: _details
                                ? _size.height - 260
                                : math.min(
                                    _stage.bottom + 8,
                                    _size.height - 280,
                                  ),
                            bottom: math.max(
                              12,
                              MediaQuery.paddingOf(context).bottom,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (!_details)
                                    const Text(
                                      'Un nouveau monde\nt’attend.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'CormorantGaramond',
                                        fontSize: 34,
                                        height: 1.02,
                                        color: Color(0xFFF0EDF4),
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  if (!_details)
                                    Text(
                                      _pbr
                                          ? 'Céramique satinée · lumière de studio'
                                          : 'Rendu actuel · comparaison',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFABA4B6),
                                      ),
                                    ),
                                  const SizedBox(height: 22),
                                  if (_pbr && !_ready)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        _error ?? 'Préparation du studio…',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB8AEC7),
                                        ),
                                      ),
                                    ),
                                  FilledButton(
                                    onPressed: (!_pbr || _ready)
                                        ? _enter
                                        : null,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        50,
                                      ),
                                      backgroundColor: ModernPalette.lilac,
                                      foregroundColor: const Color(0xFF21172D),
                                    ),
                                    child: const Text(
                                      'Traverser vers Explorer',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SegmentedButton<bool>(
                                    segments: const [
                                      ButtonSegment(
                                        value: true,
                                        label: Text('Studio 3D'),
                                      ),
                                      ButtonSegment(
                                        value: false,
                                        label: Text('Actuel'),
                                      ),
                                    ],
                                    selected: {_pbr},
                                    style: ButtonStyle(
                                      backgroundColor:
                                          WidgetStateProperty.resolveWith(
                                            (s) =>
                                                s.contains(WidgetState.selected)
                                                ? ModernPalette.lilac
                                                : const Color(0xFF19171F),
                                          ),
                                      foregroundColor:
                                          WidgetStateProperty.resolveWith(
                                            (s) =>
                                                s.contains(WidgetState.selected)
                                                ? const Color(0xFF21172D)
                                                : const Color(0xFFDAD3E5),
                                          ),
                                      side: const WidgetStatePropertyAll(
                                        BorderSide(color: Color(0xFF38323F)),
                                      ),
                                    ),
                                    showSelectedIcon: false,
                                    onSelectionChanged: (s) {
                                      setState(() => _pbr = s.first);
                                      _tick();
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: ModernPalette.lilac,
                                        ),
                                        onPressed: () {
                                          setState(() => _paused = !_paused);
                                          _syncClock();
                                        },
                                        icon: Icon(
                                          _paused
                                              ? Icons.play_arrow_rounded
                                              : Icons.pause_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _paused ? 'Animer' : 'Pause',
                                        ),
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: ModernPalette.lilac,
                                        ),
                                        onPressed: () {
                                          setState(() => _details = !_details);
                                          _tick();
                                        },
                                        icon: Icon(
                                          _details
                                              ? Icons.zoom_out_rounded
                                              : Icons.zoom_in_rounded,
                                          size: 18,
                                        ),
                                        label: Text(
                                          _details ? 'Vue entière' : 'Détails',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _Aperture extends CustomClipper<Path> {
  _Aperture(this.g);
  final PortalGeometry g;
  @override
  Path getClip(Size size) => g.aperture;
  @override
  bool shouldReclip(_Aperture old) => old.g != g;
}

class _Interior extends CustomPainter {
  _Interior(this.g);
  final PortalGeometry g;
  @override
  void paint(Canvas canvas, Size size) {
    if (g.reveal >= 1) return;
    final path = g.arch(1.45, 2.18, -.105), b = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(b.topCenter, b.bottomCenter, [
          const Color(0xFF45266B).withValues(alpha: 1 - g.reveal),
          const Color(0xFFF5A275).withValues(alpha: 1 - g.reveal),
        ]),
    );
  }

  @override
  bool shouldRepaint(_Interior old) => old.g != g;
}
