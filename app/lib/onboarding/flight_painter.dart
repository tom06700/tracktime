import '../brand/nitrate_brand.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

const flightAssets = [
  'clapper_board',
  'popcorn',
  'crossed_swords',
  'television',
  'dragon',
  'admission_tickets',
  'flying_saucer',
  'movie_camera',
  'crystal_ball',
  'magic_wand',
  'film_frames',
  'japanese_castle',
];

/// Equations and seeded phases from the approved 01-intro-envol reference.
class FlightPainter extends CustomPainter {
  FlightPainter(this.clock, this.departure, this.sprites, {this.sourceHeight})
      : super(repaint: Listenable.merge([clock, departure]));
  final ValueNotifier<double> clock;
  final Animation<double> departure;
  final List<ui.Image> sprites;

  /// Original scene height keeps the source fixed as the flight extends upward.
  final double? sourceHeight;
  static double random(int i) {
    final n = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return n - n.floor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width, height = size.height;
    final boost = (departure.value * .9 * 1.45).clamp(0.0, 1.0);
    final sourceY = height - (sourceHeight ?? height) * .13, cx = width * .5;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(Colors.black, BlendMode.srcOver);
    for (var i = 0; i < 69; i++) {
      canvas.drawCircle(
          Offset(random(i + 100) * width, random(i + 230) * height),
          random(i + 500) > .92 ? 1 : .55,
          Paint()
            ..color = const Color(0xFFDCDFF5)
                .withValues(alpha: .08 + random(i + 50) * .15));
    }
    if (boost < .7) {
      canvas.drawCircle(
          Offset(cx, sourceY),
          47,
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFBCCBF4).withValues(alpha: .09 * (1 - boost)),
              Colors.transparent,
            ]).createShader(
                Rect.fromCircle(center: Offset(cx, sourceY), radius: 47)));
      canvas.drawCircle(
          Offset(cx, sourceY),
          31,
          Paint()
            ..shader = ui.Gradient.radial(
                Offset(cx, sourceY),
                33,
                [
                  const Color(0xFF3B3E45),
                  const Color(0xFF202228),
                  const Color(0xFF14151A),
                  const Color(0xFF434750)
                ].map((c) => c.withValues(alpha: 1 - boost)).toList(),
                const [0, .35, .86, 1],
                TileMode.clamp,
                null,
                Offset(cx - 12, sourceY - 17),
                1));
      canvas.drawCircle(
          Offset(cx, sourceY),
          31,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color =
                const Color(0x3DC5C8D4).withValues(alpha: .24 * (1 - boost)));
      paintNitrateSymbol(
          canvas,
          Rect.fromCenter(
              center: Offset(cx, sourceY - 1), width: 24, height: 24),
          color: const Color(0xFFC5AEFD).withValues(alpha: 1 - boost));
    }
    final order = List.generate(21, (i) => i)
      ..sort((a, b) => random(a + 32).compareTo(random(b + 32)));
    for (final i in order) {
      if (sprites.length != flightAssets.length) break;
      final depth = random(i + 32), side = random(i + 41) * math.pi * 2;
      final angle = random(i + 67) * 2 - 1;
      final t = (clock.value / (11 + random(i + 21) * 8) + random(i + 3)) % 1;
      final fade = math.min(1.0, math.min(t / .09, (1 - t) / .13));
      final sway = math.sin(t * 6.5 + side) *
          (.27 * width) *
          math.sin(math.pi * math.min(t * 1.2, 1));
      final x = cx + sway + math.sin(t * 12 + side) * 15;
      final y = sourceY - t * (sourceY + 70) - boost * (80 + depth * 110);
      final extent = (31 + random(i + 12) * 32) *
          width /
          440 *
          (.65 + math.sin(t * math.pi) * .5);
      final sprite = sprites[i % sprites.length];
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(
          angle * .7 + math.sin(clock.value * .24 + side) * .38 + t * angle);
      canvas.scale(.92 + .08 * math.cos(clock.value * .3 + side), 1);
      canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(
              0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: extent, height: extent),
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Colors.white.withValues(
                alpha: fade * (.68 + .32 * depth) * (1 - boost * .65)));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FlightPainter oldDelegate) =>
      oldDelegate.sourceHeight != sourceHeight ||
      oldDelegate.sprites != sprites ||
      oldDelegate.clock != clock ||
      oldDelegate.departure != departure;
}
