import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../brand/nitrate_brand.dart';

/// Authored Bézier ribbon, not a rotating loading indicator. Perforations and
/// frames advance exactly one pitch per loop, so the join has no visible jump.
class FilmstripPainter extends CustomPainter {
  FilmstripPainter(this.entrance, this.travel)
      : super(repaint: Listenable.merge([entrance, travel]));
  final Animation<double> entrance;
  final Animation<double> travel;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 400, size.height / 280);
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    canvas.translate(-200, -140);
    final reveal = Curves.easeOutCubic.transform(entrance.value);
    canvas.translate((1 - reveal) * 72, (1 - reveal) * 18);
    canvas.clipRect(const Rect.fromLTWH(-20, -20, 440, 320));
    final line = Path()
      ..moveTo(-65, 190)
      ..cubicTo(75, 258, 90, 45, 225, 93)
      ..cubicTo(300, 120, 316, 185, 465, 74);
    final metric = line.computeMetrics().single;
    final length = metric.length;
    Offset edge(double distance, double offset) {
      final tangent = metric.getTangentForOffset(distance.clamp(0, length))!;
      final normal = Offset(-tangent.vector.dy, tangent.vector.dx);
      return tangent.position + normal * offset;
    }

    final ribbon = Path();
    const samples = 100;
    for (var i = 0; i <= samples; i++) {
      final point = edge(length * i / samples, -43);
      if (i == 0) {
        ribbon.moveTo(point.dx, point.dy);
      } else {
        ribbon.lineTo(point.dx, point.dy);
      }
    }
    for (var i = samples; i >= 0; i--) {
      final point = edge(length * i / samples, 43);
      ribbon.lineTo(point.dx, point.dy);
    }
    ribbon.close();
    canvas.drawShadow(ribbon, Colors.black.withValues(alpha: .6), 12, false);
    canvas.drawPath(
        ribbon,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF888571), Color(0xFFDDD3B8), Color(0xFF666C5F)],
            stops: [0, .52, 1],
          ).createShader(const Rect.fromLTWH(0, 40, 400, 200)));
    canvas.drawPath(
        ribbon,
        Paint()
          ..color = NitrateBrand.ivory.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7);
    canvas.save();
    canvas.clipPath(ribbon);
    final pitch = length / 8;
    final offset = travel.value * pitch;
    for (var i = 0; i < 8; i++) {
      final distance = (i * pitch + offset) % length;
      if (distance < 0 || distance > length) continue;
      final tangent = metric.getTangentForOffset(distance)!;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      final frame = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pitch - 9, height: 56),
        const Radius.circular(2),
      );
      canvas.drawRRect(frame, Paint()..color = const Color(0xFF111713));
      canvas.drawRRect(
          frame.deflate(3),
          Paint()
            ..color = NitrateBrand.ivory.withValues(alpha: .13)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6);
      // A photographic exposure: light crosses the emulsion, not the labels.
      canvas.drawRRect(
          frame,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                NitrateBrand.ivory.withValues(alpha: .08),
                Colors.transparent
              ],
            ).createShader(frame.outerRect));
      canvas.restore();
    }
    for (var i = 0; i < 48; i++) {
      final distance = (i * (pitch / 6) + offset) % length;
      if (distance < 0 || distance > length) continue;
      final tangent = metric.getTangentForOffset(distance)!;
      canvas.save();
      canvas.translate(tangent.position.dx, tangent.position.dy);
      canvas.rotate(tangent.angle);
      for (final y in [-35.0, 35.0]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(0, y), width: 5, height: 7),
                const Radius.circular(1.1)),
            Paint()..color = NitrateBrand.ink);
      }
      canvas.restore();
    }
    canvas.restore();
    // The identity resolves after the ribbon has entered, then remains still.
    final title = TextPainter(
      text: TextSpan(text: 'Nitrate', style: NitrateBrand.display(45)),
      textDirection: TextDirection.ltr,
    )..layout();
    final opacity = ((entrance.value - .35) / .65).clamp(0.0, 1.0);
    canvas.saveLayer(const Rect.fromLTWH(80, 210, 240, 65),
        Paint()..color = Colors.white.withValues(alpha: opacity));
    title.paint(canvas, Offset(200 - title.width / 2, 222));
    canvas.restore();
    title.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(FilmstripPainter oldDelegate) =>
      oldDelegate.entrance != entrance || oldDelegate.travel != travel;
}
