import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand/nitrate_brand.dart';
import '../motion.dart';
import '../theme.dart';
import 'filmstrip_painter.dart';

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
    return _seen! ? widget.child : WelcomeScreen(onFinish: _finish);
  }
}

/// A film ribbon enters, then flows continuously; reading remains still.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onFinish});
  final Future<void> Function() onFinish;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _busy = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (!_active || reduceMotionOf(context)) {
      _controller.stop();
      _ambient.stop();
      if (reduceMotionOf(context)) {
        _controller.value = 1;
        _ambient.value = 0;
      }
      return;
    }
    if (_controller.value < 1 && !_controller.isAnimating) {
      _controller.forward();
    }
    if (!_ambient.isAnimating) _ambient.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ambient.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onFinish();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _reveal(
          {required double begin,
          required double end,
          required Widget child}) =>
      AnimatedBuilder(
        animation: _controller,
        child: child,
        builder: (context, child) {
          final t = Interval(begin, end, curve: Curves.easeOutCubic)
              .transform(_controller.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, (1 - t) * 12), child: child),
          );
        },
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: NitrateBrand.ink,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minHeight: math.max(0, constraints.maxHeight - 44)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        NitrateWordmark(size: 36),
                        Text('LE GOÛT DES HISTOIRES',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.4,
                              color: TtColors.dim,
                            )),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          ExcludeSemantics(
                            child: RepaintBoundary(
                              child: SizedBox(
                                height: (constraints.maxHeight * .34)
                                    .clamp(160.0, 300.0),
                                width: double.infinity,
                                child: CustomPaint(
                                    painter: FilmstripPainter(
                                        _controller, _ambient)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _reveal(
                              begin: .10,
                              end: .55,
                              child: Text(
                                'Les histoires passent.\nLes émotions restent.',
                                textAlign: TextAlign.center,
                                style: NitrateBrand.display(44)
                                    .copyWith(height: 1.04),
                              )),
                          const SizedBox(height: 20),
                          _reveal(
                              begin: .32,
                              end: .72,
                              child: const Text(
                                'Tes films. Tes séries. Ton regard.\nUn endroit pour garder le fil.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: TtColors.dim),
                              )),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _finish,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: Text(
                              _busy ? 'Ouverture…' : 'Entrer dans Nitrate'),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Sans compte. Ta collection reste sur ton appareil.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, height: 1.5, color: TtColors.dim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
