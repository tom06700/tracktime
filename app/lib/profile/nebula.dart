import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Fond génératif « nébuleuse » : nuages de lumière additifs aux couleurs de
/// tes genres + champ d'étoiles, positionnés de façon déterministe par [seed].
/// Chaque profil a donc son propre cosmos.
class NebulaBackground extends StatelessWidget {
  const NebulaBackground({
    super.key,
    required this.seed,
    required this.palette,
    this.child,
  });

  final int seed;
  final List<Color> palette;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NebulaPainter(seed: seed, palette: palette),
      isComplex: true,
      willChange: false,
      child: child,
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({required this.seed, required this.palette});

  final int seed;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(seed);

    // Fond profond.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0C12), Color(0xFF0D1017)],
        ).createShader(rect),
    );

    // Nuages de lumière (additifs) aux couleurs des genres.
    final clouds = 7 + rnd.nextInt(4);
    for (var i = 0; i < clouds; i++) {
      final color = palette[i % palette.length];
      final cx = rnd.nextDouble() * size.width;
      final cy = rnd.nextDouble() * size.height;
      final radius = size.width * (0.28 + rnd.nextDouble() * 0.5);
      final alpha = 0.16 + rnd.nextDouble() * 0.22;
      final paint = Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    // Voile sombre pour garder la lisibilité du contenu.
    canvas.drawRect(
      rect,
      Paint()..color = TtColors.bg.withValues(alpha: 0.28),
    );

    // Champ d'étoiles.
    final stars = 90 + rnd.nextInt(60);
    for (var i = 0; i < stars; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() < 0.9
          ? 0.5 + rnd.nextDouble() * 0.9
          : 1.4 + rnd.nextDouble();
      final a = 0.25 + rnd.nextDouble() * 0.55;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_NebulaPainter old) =>
      old.seed != seed || old.palette != palette;
}
