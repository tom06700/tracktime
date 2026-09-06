import 'dart:ui' as ui;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../motion.dart';

import 'flight_painter.dart';
import 'notification_screen.dart';

/// Resolves the local preference before displaying either destination.
/// The library and its database are never modified by onboarding.
class WelcomeGate extends StatefulWidget {
  const WelcomeGate({super.key, required this.child});
  final Widget child;

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  static const preferenceKey = 'nitrate.welcome.v1';
  bool? _seen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    bool seen;
    try {
      seen = (await SharedPreferences.getInstance()).getBool(preferenceKey) ??
          false;
    } catch (_) {
      // Storage failure must never prevent access to the existing library.
      seen = true;
    }
    if (mounted) setState(() => _seen = seen);
  }

  Future<void> _finish() async {
    try {
      await (await SharedPreferences.getInstance())
          .setBool(preferenceKey, true);
    } catch (_) {
      // Continue for this session even when preferences cannot be written.
    }
    if (mounted) setState(() => _seen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == null) {
      return const Scaffold(
        body: Center(
            child: Image(
                image: AssetImage('assets/images/launch_mark.png'),
                width: 96,
                height: 96)),
      );
    }
    return _seen! ? widget.child : IntroFlow(onFinish: _finish);
  }
}

/// Shared first-run and settings replay flow; skip intro still reaches step two.
class IntroFlow extends StatefulWidget {
  const IntroFlow({super.key, required this.onFinish});
  final Future<void> Function() onFinish;
  @override
  State<IntroFlow> createState() => _IntroFlowState();
}

class _IntroFlowState extends State<IntroFlow> {
  bool _notifications = false;
  @override
  Widget build(BuildContext context) => _notifications
      ? NotificationScreen(onFinish: widget.onFinish)
      : WelcomeScreen(onFinish: () async {
          if (mounted) setState(() => _notifications = true);
        });
}

/// Native port of the approved flight. Completion preserves the welcome gate.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onFinish});
  final Future<void> Function() onFinish;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _departure = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  List<ui.Image> _sprites = [];
  Duration? _previous;
  bool _active = true, _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final images = <ui.Image>[];
    try {
      for (final asset in flightAssets) {
        final data = await rootBundle.load('assets/objects/$asset.png');
        final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        try {
          images.add((await codec.getNextFrame()).image);
        } finally {
          codec.dispose();
        }
      }
      if (!mounted) {
        for (final image in images) {
          image.dispose();
        }
        return;
      }
      setState(() => _sprites = images);
    } catch (e) {
      for (final image in images) {
        image.dispose();
      }
      debugPrint('Intro artwork unavailable: $e');
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (previous == null) return;
    final dt = ((elapsed - previous).inMicroseconds / 1000000).clamp(0.0, .06);
    _clock.value += dt * (_busy ? 4.8 : 1);
  }

  void _sync() {
    final animate = _active &&
        TickerMode.valuesOf(context).enabled &&
        !reduceMotionOf(context);
    if (animate && !_ticker.isActive) {
      _previous = null;
      _ticker.start();
    }
    if (!animate && _ticker.isActive) {
      _ticker.stop();
      _previous = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _sync();
    if (!_active) {
      _departure.stop();
    } else if (_busy && _departure.value < 1) {
      _departure.forward();
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!reduceMotionOf(context)) {
        await _departure.forward().orCancel;
      }
      if (!mounted) return;
      await widget.onFinish();
    } on TickerCanceled {
      // A disposed route never invokes completion later.
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ouverture impossible. Réessaie.')));
      }
    } finally {
      if (mounted) {
        _departure.reset();
        setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _departure.dispose();
    _clock.dispose();
    for (final image in _sprites) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 26, 24),
                child: Column(children: [
                  // Paint the flight behind the header and status area. The
                  // foreground alone keeps the safe inset and remains tappable.
                  Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                        top: 0,
                        left: -26,
                        right: -26,
                        bottom: 0,
                        child: IgnorePointer(
                            child: ExcludeSemantics(
                                child: RepaintBoundary(
                                    child: CustomPaint(
                                        painter: FlightPainter(
                                            _clock, _departure, _sprites,
                                            sourceHeight:
                                                (constraints.maxHeight -
                                                        MediaQuery.paddingOf(
                                                                context)
                                                            .top -
                                                        310)
                                                    .clamp(220.0, 403.0))))))),
                    Column(children: [
                      Padding(
                        padding: EdgeInsets.only(
                            top: MediaQuery.paddingOf(context).top + 18),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Flexible(
                                  child: Text('nitrate',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 25,
                                          letterSpacing: -1.35,
                                          fontWeight: FontWeight.w500))),
                              TextButton(
                                  onPressed: _busy ? null : _finish,
                                  child: const Text('Passer',
                                      style: TextStyle(
                                          color: Color(0xFF9B9BA2),
                                          fontSize: 12))),
                            ]),
                      ),
                      SizedBox(
                          height: (constraints.maxHeight -
                                  MediaQuery.paddingOf(context).top -
                                  310)
                              .clamp(220.0, 403.0)),
                    ]),
                  ]),
                  AnimatedBuilder(
                      animation: _departure,
                      child: const Column(children: [
                        Text('Tes films. Tes séries.\nTon univers.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 31,
                                height: 1.15,
                                letterSpacing: -1.3,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFF1F1F5))),
                        SizedBox(height: 17),
                        Text('Garde le fil de ce que tu regardes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                height: 1.55,
                                color: Color(0xFF8D8D97))),
                      ]),
                      builder: (context, child) => Opacity(
                          opacity: 1 - (_departure.value / .45).clamp(0.0, 1.0),
                          child: Transform.translate(
                              offset: Offset(0, -10 * _departure.value),
                              child: child))),
                  const SizedBox(height: 48),
                  AnimatedBuilder(
                      animation: Listenable.merge([_clock, _departure]),
                      builder: (context, _) => FilledButton(
                          onPressed: _busy ? null : _finish,
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF3F2F9),
                              disabledBackgroundColor: const Color(0xFFF3F2F9),
                              foregroundColor: const Color(0xFF202128),
                              disabledForegroundColor: const Color(0xFF202128),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(double.infinity, 59)),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: Stack(children: [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 54, vertical: 20),
                                    child: Center(
                                        child: Text(
                                            _busy ? 'On y va' : 'C’est parti',
                                            style: const TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500)))),
                                Positioned(
                                    right: 22,
                                    top: 17,
                                    child: ClipRect(
                                        child: SizedBox(
                                            width: 24,
                                            height: 25,
                                            child: Stack(children: [
                                              for (var i = 0; i < 2; i++)
                                                Transform.translate(
                                                    offset: Offset(
                                                        24 *
                                                            (_departure.value -
                                                                i),
                                                        -24 *
                                                            (_departure.value -
                                                                i)),
                                                    child: const Icon(
                                                        Icons.north_east,
                                                        size: 22))
                                            ])))),
                                if (!reduceMotionOf(context))
                                  Positioned.fill(child: IgnorePointer(child:
                                      LayoutBuilder(builder: (context, c) {
                                    final phase = ((_clock.value - 1.5) / 6.5)
                                            .clamp(0.0, double.infinity) %
                                        1;
                                    final t =
                                        ((phase - .68) / .22).clamp(0.0, 1.0);
                                    return Transform.translate(
                                        offset: Offset(
                                            (t * 2.8 - 1.4) * c.maxWidth, 0),
                                        child: const DecoratedBox(
                                            decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                    colors: [
                                              Colors.transparent,
                                              Color(0xA6FFFFFF),
                                              Colors.transparent
                                            ],
                                                    stops: [
                                              .4,
                                              .5,
                                              .6
                                            ]))));
                                  }))),
                                Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                            widthFactor: _departure.value,
                                            child: const SizedBox(
                                                height: 3,
                                                child: ColoredBox(
                                                    color:
                                                        Color(0xFFA9B7DE)))))),
                              ])))),
                  const SizedBox(height: 15),
                  const Text(
                      'Sans compte. Ta collection reste sur ton appareil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          height: 1.5,
                          color: Color(0xFF75757F))),
                ]),
              )),
            )),
      );
}
