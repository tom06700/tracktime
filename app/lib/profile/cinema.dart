import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fond « salle obscure » vivant : faisceau de projecteur teinté par les
/// genres dominants, poussières qui dérivent dans le cône, scintillement de
/// la lampe, nappe de lumière à l'écran, vignettage — et parallaxe au scroll.
///
/// Deux couches pour la perf :
/// - une couche STATIQUE (dégradés + faisceau flouté + vignette), peinte une
///   fois dans un RepaintBoundary et simplement translatée au scroll ;
/// - une couche ANIMÉE légère (poussières, halo de lampe) repainte à chaque
///   tick de [drive].
///
/// Géométrie déterministe par [seed] : chaque profil a sa propre projection.
class CinemaBackground extends StatelessWidget {
  const CinemaBackground({
    super.key,
    required this.seed,
    required this.palette,
    this.drive,
    this.scroll,
  });

  final int seed;
  final List<Color> palette;

  /// Horloge 0→1 en boucle (≈30 s) pour la dérive des poussières et le
  /// scintillement. Null ou arrêtée = fond figé (accessibilité).
  final Animation<double>? drive;

  /// Position de scroll du contenu, pour la parallaxe du fond.
  final ScrollController? scroll;

  /// Le fond défile à 12 % de la vitesse du contenu…
  static const _parallax = 0.12;

  /// …et il est peint 30 % plus haut que l'écran pour avoir de la matière.
  static const _overflow = 0.30;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final paintH = h * (1 + _overflow);
          final geo = _Geo(seed, Size(w, paintH), palette);

          Widget parallaxed(Widget child) {
            final s = scroll;
            if (s == null) return child;
            return AnimatedBuilder(
              animation: s,
              builder: (_, kid) {
                final off = s.hasClients ? s.offset : 0.0;
                final dy = (off * _parallax).clamp(0.0, h * _overflow);
                return Transform.translate(offset: Offset(0, -dy), child: kid);
              },
              child: child,
            );
          }

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                width: w,
                height: paintH,
                child: parallaxed(
                  Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter:
                              _CinemaStaticPainter(geo: geo, palette: palette),
                          isComplex: true,
                          willChange: false,
                        ),
                      ),
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _CinemaDustPainter(
                            geo: geo,
                            drive: drive ?? const AlwaysStoppedAnimation(0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Géométrie du faisceau, calculée une fois par (seed, taille).
class _Geo {
  _Geo(this.seed, this.size, List<Color> palette) {
    final rnd = math.Random(seed);
    final w = size.width, h = size.height;
    srcX = w * (0.32 + rnd.nextDouble() * 0.36);
    landY = h * (0.70 + rnd.nextDouble() * 0.14);
    landX =
        (srcX + (rnd.nextDouble() - 0.5) * w * 0.35).clamp(w * 0.22, w * 0.78);
    spread = w * (0.34 + rnd.nextDouble() * 0.14);
    beamColor = Color.lerp(palette.first, Colors.white, 0.45)!;
  }

  final int seed;
  final Size size;
  late final double srcX, landX, landY, spread;
  late final Color beamColor;

  Offset get src => Offset(srcX, -6);

  @override
  bool operator ==(Object other) =>
      other is _Geo && other.seed == seed && other.size == size;

  @override
  int get hashCode => Object.hash(seed, size);
}

class _CinemaStaticPainter extends CustomPainter {
  _CinemaStaticPainter({required this.geo, required this.palette});

  final _Geo geo;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(geo.seed + 1);
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

    final src = geo.src;
    final landX = geo.landX, landY = geo.landY, spread = geo.spread;
    final beamColor = geo.beamColor;

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
      final x2 = w - src.dx;
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

    // Lampe du projecteur (le halo qui scintille vit dans la couche animée).
    canvas.drawCircle(
      src.translate(0, 12),
      26,
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = beamColor.withValues(alpha: 0.40),
    );
    canvas.drawCircle(src.translate(0, 12), 4.5,
        Paint()..color = Colors.white.withValues(alpha: 0.85));

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
  bool shouldRepaint(_CinemaStaticPainter old) =>
      old.geo != geo || old.palette != palette;
}

/// Couche animée légère : poussières qui dérivent le long du faisceau et
/// respiration de la lampe. Aucun flou coûteux hors le petit halo de lampe.
class _CinemaDustPainter extends CustomPainter {
  _CinemaDustPainter({required this.geo, required this.drive})
      : super(repaint: drive);

  final _Geo geo;
  final Animation<double> drive;

  @override
  void paint(Canvas canvas, Size size) {
    final v = drive.value; // 0→1 sur ~30 s, boucle continue
    final src = geo.src;
    final landX = geo.landX, landY = geo.landY, spread = geo.spread;
    final beamColor = geo.beamColor;
    final dustColor = Color.lerp(beamColor, Colors.white, 0.6)!;

    // Respiration de la lampe (fréquences entières → boucle sans à-coup).
    final flick = 0.10 * math.sin(2 * math.pi * (7 * v)) +
        0.06 * math.sin(2 * math.pi * (23 * v) + 1.3);
    canvas.drawCircle(
      src.translate(0, 12),
      26,
      Paint()
        ..blendMode = BlendMode.screen
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
        ..color = beamColor.withValues(alpha: (0.14 + flick).clamp(0.0, 0.3)),
    );

    // Poussières en dérive lente le long du cône.
    final rnd = math.Random(geo.seed + 2);
    final motes = 46 + rnd.nextInt(18);
    for (var i = 0; i < motes; i++) {
      final t0 = rnd.nextDouble();
      final speed = 1 + rnd.nextInt(3); // traversées par boucle (entier)
      final swayK = 2 + rnd.nextInt(4); // oscillations par boucle (entier)
      final phase = rnd.nextDouble() * math.pi * 2;
      final lane = (rnd.nextDouble() * 2 - 1) * rnd.nextDouble();
      final swayAmp = 4 + rnd.nextDouble() * 10;
      final baseAlpha = 0.10 + rnd.nextDouble() * 0.35;
      final r = 0.4 + rnd.nextDouble() * 1.3;

      final ti = (t0 + v * speed) % 1.0;
      final cx = src.dx + (landX - src.dx) * ti;
      final half = 7 + (spread - 7) * ti;
      final sway = math.sin(2 * math.pi * swayK * v + phase) * swayAmp;
      final x = cx + lane * half + sway;
      final y = src.dy + (landY - src.dy) * ti;
      // Fondu aux extrémités du trajet + atténuation vers le bas.
      final a = baseAlpha *
          math.sin(math.pi * ti) *
          (1 - ti * 0.35);
      if (a <= 0.01) continue;
      canvas.drawCircle(
          Offset(x, y), r, Paint()..color = dustColor.withValues(alpha: a));
    }
  }

  @override
  bool shouldRepaint(_CinemaDustPainter old) =>
      old.geo != geo || old.drive != drive;
}
