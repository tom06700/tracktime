import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand/nitrate_brand.dart';
import '../motion.dart';
import '../theme.dart';

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
    if (_seen == null) return const Scaffold(body: SizedBox.expand());
    return _seen! ? widget.child : WelcomeScreen(onFinish: _finish);
  }
}

/// A finite opening sequence, with no network assets or perpetual ticker.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onFinish});
  final Future<void> Function() onFinish;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
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
                                    painter: _ProjectionPainter(_controller)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Les histoires passent.\nLes émotions restent.',
                            textAlign: TextAlign.center,
                            style:
                                NitrateBrand.display(44).copyWith(height: 1.04),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Tes films. Tes séries. Ton regard.\nUn endroit pour garder le fil.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, height: 1.6, color: TtColors.dim),
                          ),
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

/// Original vector artwork: an aperture opens onto an ivory projection frame.
/// Animation changes only painting, never layout or the readability of text.
class _ProjectionPainter extends CustomPainter {
  _ProjectionPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform(animation.value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .43;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final glow = Rect.fromCircle(center: Offset.zero, radius: radius * 1.4);
    canvas.drawCircle(
        Offset.zero,
        radius * 1.4,
        Paint()
          ..shader = RadialGradient(colors: [
            NitrateBrand.ivory.withValues(alpha: .16 * t),
            NitrateBrand.ivory.withValues(alpha: 0),
          ]).createShader(glow));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    for (var i = 0; i < 3; i++) {
      line.color = NitrateBrand.ivory.withValues(alpha: .12 + i * .045);
      canvas.drawCircle(Offset.zero, radius * (1 + i * .1), line);
    }
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4 + (1 - t) * .45);
      final path = Path()
        ..moveTo(radius * (.12 + .28 * t), -radius * .12)
        ..lineTo(radius * .65, -radius * .64)
        ..quadraticBezierTo(
            radius * 1.12, -radius * .2, radius * .93, radius * .34)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              colors: [
                NitrateBrand.ivory.withValues(alpha: .7),
                const Color(0xFF343B33)
              ],
            ).createShader(
                Rect.fromCircle(center: Offset.zero, radius: radius)));
      canvas.drawPath(
          path,
          Paint()
            ..color = NitrateBrand.ivory.withValues(alpha: .32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6);
      canvas.restore();
    }
    final frame = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset.zero, width: radius * .48, height: radius * .32),
      const Radius.circular(3),
    );
    canvas.drawRRect(
        frame, Paint()..color = NitrateBrand.ivory.withValues(alpha: t));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProjectionPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
