import 'package:flutter/material.dart';

/// Miniatures des dispositions réelles, dans un cadre commun de 24 px.
/// Le bouton parent porte le libellé accessible et l'état de sélection.
class CollectionLayoutIcon extends StatelessWidget {
  const CollectionLayoutIcon({
    super.key,
    required this.series,
    required this.compact,
  });

  final bool series;
  final bool compact;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size.square(24),
      painter: _LayoutPainter(
        series: series,
        compact: compact,
        color: IconTheme.of(context).color ?? Colors.white,
      ),
    ),
  );
}

class _LayoutPainter extends CustomPainter {
  const _LayoutPainter({
    required this.series,
    required this.compact,
    required this.color,
  });

  final bool series;
  final bool compact;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final outline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final fill = Paint()..color = color.withValues(alpha: .08);

    void card(double x, double y, double width, double height) {
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, outline);
    }

    if (series && !compact) {
      card(3, 2.5, 18, 10.5);
      card(3, 16, 7.5, 5.5);
      card(13.5, 16, 7.5, 5.5);
    } else if (series) {
      for (final x in [3.5, 13.5]) {
        for (final y in [2.5, 13.5]) {
          card(x, y, 7, 8);
        }
      }
    } else if (!compact) {
      card(3, 5.5, 7.5, 13);
      card(13.5, 5.5, 7.5, 13);
    } else {
      for (final x in [2.5, 9.5, 16.5]) {
        card(x, 7, 5, 10);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LayoutPainter oldDelegate) =>
      series != oldDelegate.series ||
      compact != oldDelegate.compact ||
      color != oldDelegate.color;
}
