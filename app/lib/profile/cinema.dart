import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fond « salle obscure » : faisceau de projecteur teinté par les genres
/// dominants, poussières lumineuses dans le cône, nappe de lumière à l'écran
/// et vignettage. Géométrie déterministe par [seed] : chaque profil a sa
/// propre projection.
class CinemaBackground extends StatelessWidget {
  const CinemaBackground({
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
      painter: _CinemaPainter(seed: seed, palette: palette),
      isComplex: true,
      willChange: false,
      child: child,
    );
  }
}

class _CinemaPainter extends CustomPainter {
  _CinemaPainter({required this.seed, required this.palette});

  final int seed;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(seed);
    final w = size.width, h = size.height;

    // Salle obscure.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07090F), Color(0xFF0B0E15)],
        ).createShader(rect),
    );

    // Ambiance latérale très douce aux couleurs du profil.
    for (var i = 0; i < math.min(2, palette.length); i++) {
      final cx = i.isEven ? w * 0.04 : w * 0.96;
      final cy = h * (0.5 + rnd.nextDouble() * 0.35);
      final r = w * 0.75;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(colors: [
            palette[i].withValues(alpha: 0.055),
            palette[i].withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }

    // Géométrie du faisceau principal.
    final srcX = w * (0.32 + rnd.nextDouble() * 0.36);
    final src = Offset(srcX, -6);
    final landY = h * (0.70 + rnd.nextDouble() * 0.14);
    final landX =
        (srcX + (rnd.nextDouble() - 0.5) * w * 0.35).clamp(w * 0.22, w * 0.78);
    final spread = w * (0.34 + rnd.nextDouble() * 0.14);
    final beamColor = Color.lerp(palette.first, Colors.white, 0.45)!;

    void beam(double widthFactor, double alpha, double blur) {
      final path = Path()
        ..moveTo(src.dx - 7 * widthFactor, src.dy)
        ..lineTo(src.dx + 7 * widthFactor, src.dy)
        ..lineTo(landX + spread * widthFactor, landY)
        ..lineTo(landX - spread * widthFactor, landY)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              beamColor.withValues(alpha: alpha),
              beamColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.95],
          ).createShader(
              Rect.fromLTRB(landX - spread, 0, landX + spread, landY)),
      );
    }

    beam(1.0, 0.30, 26); // halo large
    beam(0.55, 0.22, 12); // cœur du faisceau

    // Faisceau secondaire discret (2e couleur du profil), désaxé.
    if (palette.length > 1) {
      final c2 = Color.lerp(palette[1], Colors.white, 0.35)!;
      final x2 = w - srcX;
      final path = Path()
        ..moveTo(x2 - 5, -6)
        ..lineTo(x2 + 5, -6)
        ..lineTo(x2 + spread * 0.9 + w * 0.08, h * 0.82)
        ..lineTo(x2 - spread * 0.9 + w * 0.08, h * 0.82)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c2.withValues(alpha: 0.10), c2.withValues(alpha: 0)],
          ).createShader(Rect.fromLTWH(0, 0, w, h * 0.82)),
      );
    }

    // Nappe de lumière là où le faisceau se pose (l'« écran »).
    final pool = Rect.fromCenter(
        center: Offset(landX, landY), width: spread * 2.6, height: h * 0.18);
    canvas.drawOval(
      pool,
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30)
        ..shader = RadialGradient(colors: [
          beamColor.withValues(alpha: 0.15),
          beamColor.withValues(alpha: 0),
        ]).createShader(pool),
    );

    // Lampe du projecteur.
    canvas.drawCircle(
      src.translate(0, 12),
      26,
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = beamColor.withValues(alpha: 0.5),
    );
    canvas.drawCircle(src.translate(0, 12), 4.5,
        Paint()..color = Colors.white.withValues(alpha: 0.85));

    // Poussières en suspension DANS le faisceau (pas un champ d'étoiles :
    // elles vivent dans le cône de lumière, plus denses vers la lampe).
    final motes = 46 + rnd.nextInt(18);
    for (var i = 0; i < motes; i++) {
      final t = rnd.nextDouble(); // position le long du faisceau
      final cx = src.dx + (landX - src.dx) * t;
      final half = 7 + (spread - 7) * t;
      final u = (rnd.nextDouble() * 2 - 1) * rnd.nextDouble(); // resserré
      final x = cx + u * half;
      final y = src.dy + (landY - src.dy) * t + (rnd.nextDouble() - 0.5) * 14;
      final a = (0.10 + rnd.nextDouble() * 0.35) * (1 - t * 0.45);
      final r = 0.4 + rnd.nextDouble() * 1.3;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color =
              Color.lerp(beamColor, Colors.white, 0.6)!.withValues(alpha: a),
      );
    }

    // Vignettage (coins de salle).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.15,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.42)],
          stops: const [0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CinemaPainter old) =>
      old.seed != seed || old.palette != palette;
}
