import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Les quatre icônes de navigation, dessinées à la main dans un même univers
/// cinéma : même grille 24×24, même graisse de trait, mêmes extrémités
/// arrondies. Un jeu Material générique cassait l'identité de l'app.
enum NitrateIcon { reel, clapper, lens, portrait }

class NitrateIconView extends StatelessWidget {
  const NitrateIconView(
    this.icon, {
    super.key,
    required this.color,
    this.size = 24,
    this.active = false,
  });

  final NitrateIcon icon;
  final Color color;
  final double size;

  /// Onglet courant : trait légèrement plus gras et accents pleins, pour
  /// marquer la sélection sans pastille de fond.
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NitrateIconPainter(icon: icon, color: color, active: active),
    );
  }
}

class _NitrateIconPainter extends CustomPainter {
  const _NitrateIconPainter({
    required this.icon,
    required this.color,
    required this.active,
  });

  final NitrateIcon icon;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.0 : 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..isAntiAlias = true;

    switch (icon) {
      case NitrateIcon.reel:
        _reel(canvas, stroke, fill);
      case NitrateIcon.clapper:
        _clapper(canvas, stroke, fill);
      case NitrateIcon.lens:
        _lens(canvas, stroke, fill);
      case NitrateIcon.portrait:
        _portrait(canvas, stroke, fill);
    }
    canvas.restore();
  }

  /// Séries — bobine de pellicule : jante, moyeu, trois lumières.
  void _reel(Canvas canvas, Paint stroke, Paint fill) {
    const c = Offset(12, 12);
    canvas.drawCircle(c, 8.6, stroke);
    canvas.drawCircle(c, 1.7, fill);
    for (var i = 0; i < 3; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 3;
      final p = c + Offset(math.cos(a), math.sin(a)) * 4.8;
      canvas.drawCircle(p, 1.9, active ? fill : stroke);
    }
  }

  /// Films — clap : ardoise et barre à claquer rayée.
  void _clapper(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromLTRBR(3.2, 9.6, 20.8, 20.4, const Radius.circular(2.4)),
      stroke,
    );
    final bar = RRect.fromLTRBR(
      3.2,
      4.4,
      20.8,
      9.6,
      const Radius.circular(1.6),
    );
    canvas.drawRRect(bar, stroke);
    if (active) {
      canvas.drawRRect(bar, fill);
    } else {
      for (var i = 0; i < 3; i++) {
        final x = 6.4 + i * 5.0;
        canvas.drawLine(Offset(x, 9.6), Offset(x + 2.6, 4.4), stroke);
      }
    }
  }

  /// Explorer — objectif : lentille et poignée, comme une loupe de projection.
  void _lens(Canvas canvas, Paint stroke, Paint fill) {
    const c = Offset(10.6, 10.6);
    canvas.drawCircle(c, 6.4, stroke);
    // Anneau intérieur : lit comme un objectif, pas comme une loupe standard.
    canvas.drawCircle(c, 3.1, stroke);
    if (active) canvas.drawCircle(c, 1.3, fill);
    canvas.drawLine(const Offset(15.3, 15.3), const Offset(20, 20), stroke);
  }

  /// Profil — silhouette prise dans le faisceau.
  void _portrait(Canvas canvas, Paint stroke, Paint fill) {
    const head = Offset(12, 8.2);
    canvas.drawCircle(head, 3.7, active ? fill : stroke);
    final shoulders = Path()
      ..addArc(const Rect.fromLTRB(4.8, 13.6, 19.2, 25.4), math.pi, math.pi);
    canvas.drawPath(shoulders, stroke);
  }

  @override
  bool shouldRepaint(_NitrateIconPainter old) =>
      old.icon != icon || old.color != color || old.active != active;
}
