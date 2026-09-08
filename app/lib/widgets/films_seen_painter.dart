// Artwork ported from design/interactive/films-buttons/regards-refined.svg.
// Approved vector artwork, optically centered and upright for the header.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FilmsSeenPainter extends CustomPainter {
  const FilmsSeenPainter({required this.progress});
  final double progress;

  static double _track(double t, List<(double, double)> points) {
    for (var i = 1; i < points.length; i++) {
      final (b, y) = points[i];
      if (t <= b) {
        final (a, x) = points[i - 1];
        final u = ((t - a) / (b - a)).clamp(0.0, 1.0);
        return x + (y - x) * u * u * (3 - 2 * u);
      }
    }
    return points.last.$2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final open = _track(t, [
      (0, 1),
      (.18, 1),
      (.26, 0),
      (.29, 0),
      (.47, 1),
      (1, 1),
    ]);
    final look = _track(t, [
      (0, 0),
      (.16, 1.3),
      (.3, 1.3),
      (.54, 3),
      (.82, 0),
      (1, 0),
    ]);
    final rotation = _track(t, [
      (0, 0),
      (.2, 1),
      (.34, -.8),
      (.58, .3),
      (.83, 0),
      (1, 0),
    ]);
    final rise = _track(t, [(0, 0), (.21, -.8), (.34, .35), (.7, 0), (1, 0)]);
    final eye = Path()
      ..moveTo(50, 85)
      ..cubicTo(72, 89 - 35 * open, 128, 89 - 35 * open, 150, 85)
      ..cubicTo(128, 89 + 22 * open, 72, 89 + 22 * open, 50, 85)
      ..close();
    final scale = math.min(size.width / 200, size.height / 176);
    canvas.save();
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 176 * scale) / 2,
    );
    canvas.scale(scale);
    canvas.save();
    canvas.translate(100, 88 + rise);
    canvas.rotate(rotation * math.pi / 180);
    // Center the painted frame (y=28…144), rather than the SVG artboard.
    canvas.translate(-100, -86);
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(22.0, 33.0, 157.0, 115.0),
            const Radius.circular(18.0),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0x3B060B16));
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(20.0, 28.0, 160.0, 116.0),
            const Radius.circular(18.0),
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0, -1.0),
            end: Alignment(0.3999999999999999, 1.0),
            colors: [Color(0xFFF0E1E1), Color(0xFFC5B4DE), Color(0xFF777598)],
            stops: [0.0, 0.4, 1.0],
          ).createShader(shape.getBounds()),
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(21.8, 29.7, 156.4, 111.4),
            const Radius.circular(16.3),
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0, -1.0),
            end: Alignment(-0.4, 1.0),
            colors: [Color(0xFF736987), Color(0xFF4B4865), Color(0xFF30364F)],
            stops: [0.0, 0.35, 1.0],
          ).createShader(shape.getBounds()),
      );
    }
    {
      final shape = (Path()
        ..moveTo(22.5, 47.0)
        ..lineTo(22.5, 45.0)
        ..quadraticBezierTo(22.5, 30.5, 38.0, 30.5)
        ..lineTo(160.0, 30.5)
        ..quadraticBezierTo(173.0, 30.5, 176.0, 41.0));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x3BFFF4EE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = (Path()
        ..moveTo(27.0, 133.0)
        ..quadraticBezierTo(31.0, 140.0, 40.0, 140.0)
        ..lineTo(160.0, 140.0)
        ..quadraticBezierTo(174.0, 140.0, 177.0, 127.0));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x7A141B32)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(38.5, 36.5, 123.0, 96.5),
            const Radius.circular(11.0),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF11182B));
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(39.5, 38.0, 121.0, 94.0),
            const Radius.circular(10.0),
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0, -1.0),
            end: Alignment(0.3999999999999999, 1.0),
            colors: [Color(0xFF1A2338), Color(0xFF2E3450)],
            stops: [0.0, 1.0],
          ).createShader(shape.getBounds()),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x4CB3A1C4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
    {
      final shape = (Path()
        ..moveTo(41.0, 51.0)
        ..lineTo(41.0, 49.0)
        ..quadraticBezierTo(41.0, 40.0, 51.0, 40.0)
        ..lineTo(148.0, 40.0));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x1CEEE3F1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.save();
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27.0, 40.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(28.0, 50.0)
        ..lineTo(33.0, 50.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(166.0, 40.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(167.0, 50.0)
        ..lineTo(172.0, 50.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27.0, 61.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(28.0, 71.0)
        ..lineTo(33.0, 71.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(166.0, 61.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(167.0, 71.0)
        ..lineTo(172.0, 71.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27.0, 82.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(28.0, 92.0)
        ..lineTo(33.0, 92.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(166.0, 82.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(167.0, 92.0)
        ..lineTo(172.0, 92.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27.0, 103.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(28.0, 113.0)
        ..lineTo(33.0, 113.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(166.0, 103.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(167.0, 113.0)
        ..lineTo(172.0, 113.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(27.0, 124.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(28.0, 134.0)
        ..lineTo(33.0, 134.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(166.0, 124.0, 7.0, 10.0),
            const Radius.circular(2.2),
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF181F32));
    }
    {
      final shape = (Path()
        ..moveTo(167.0, 134.0)
        ..lineTo(172.0, 134.0));
      canvas.drawPath(shape, Paint()..color = Color(0xFF000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x73B6A5C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    canvas.clipPath(eye);
    {
      final shape = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(47.0, 54.0, 106.0, 62.0),
            const Radius.circular(0.0),
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0, -1.0),
            end: Alignment(-1.0, 1.0),
            colors: [Color(0xFFA6A2CB), Color(0xFF858EB7), Color(0xFFBAC1D2)],
            stops: [0.0, 0.64, 1.0],
          ).createShader(shape.getBounds()),
      );
    }
    canvas.save();
    canvas.translate(-look * .25, 0);
    {
      final shape = (Path()
        ..moveTo(45.0, 103.0)
        ..lineTo(62.0, 83.0)
        ..lineTo(68.0, 88.0)
        ..lineTo(82.0, 76.0)
        ..lineTo(100.0, 101.0)
        ..lineTo(121.0, 67.0)
        ..lineTo(138.0, 87.0)
        ..lineTo(146.0, 81.0)
        ..lineTo(164.0, 106.0)
        ..lineTo(164.0, 116.0)
        ..lineTo(45.0, 116.0)
        ..close());
      canvas.drawPath(shape, Paint()..color = Color(0xFF737FA4));
    }
    {
      final shape = (Path()
        ..moveTo(106.0, 92.0)
        ..lineTo(121.0, 67.0)
        ..lineTo(117.0, 83.0)
        ..lineTo(126.0, 88.0)
        ..lineTo(122.0, 88.0)
        ..lineTo(132.0, 99.0)
        ..close());
      canvas.drawPath(shape, Paint()..color = Color(0xFF535F87));
    }
    {
      final shape = (Path()
        ..moveTo(42.0, 110.0)
        ..lineTo(63.0, 93.0)
        ..lineTo(74.0, 98.0)
        ..lineTo(86.0, 90.0)
        ..lineTo(101.0, 110.0)
        ..lineTo(134.0, 82.0)
        ..lineTo(145.0, 97.0)
        ..lineTo(166.0, 110.0)
        ..lineTo(166.0, 120.0)
        ..lineTo(42.0, 120.0)
        ..close());
      canvas.drawPath(shape, Paint()..color = Color(0xFF445D7E));
    }
    {
      final shape = (Path()
        ..moveTo(112.0, 104.0)
        ..lineTo(134.0, 82.0)
        ..lineTo(129.0, 98.0)
        ..lineTo(140.0, 104.0)
        ..close());
      canvas.drawPath(shape, Paint()..color = Color(0xFF354B6C));
    }
    {
      final shape = (Path()
        ..moveTo(48.0, 107.0)
        ..quadraticBezierTo(75.0, 100.0, 95.0, 106.0)
        ..quadraticBezierTo(115.0, 112.0, 154.0, 105.0)
        ..lineTo(152.0, 123.0)
        ..lineTo(47.0, 123.0)
        ..close());
      canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(-1.0, -1.0),
            end: Alignment(-1.0, 1.0),
            colors: [Color(0xFFA0B3CC), Color(0xFF4C627F)],
            stops: [0.0, 1.0],
          ).createShader(shape.getBounds()),
      );
    }
    {
      final shape = (Path()
        ..moveTo(50.0, 106.0)
        ..lineTo(67.0, 104.0)
        ..lineTo(80.0, 109.0)
        ..lineTo(67.0, 112.0)
        ..lineTo(91.0, 116.0)
        ..lineTo(45.0, 116.0)
        ..close()
        ..moveTo(155.0, 105.0)
        ..lineTo(145.0, 103.0)
        ..lineTo(130.0, 109.0)
        ..lineTo(145.0, 112.0)
        ..lineTo(126.0, 118.0)
        ..lineTo(160.0, 118.0)
        ..close());
      canvas.drawPath(shape, Paint()..color = Color(0xFF2C4561));
    }
    {
      final shape = (Path()
        ..moveTo(85.0, 109.0)
        ..lineTo(113.0, 109.0)
        ..moveTo(96.0, 113.0)
        ..lineTo(122.0, 113.0));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x80D0D6E2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.save();
    canvas.translate(look, 0);
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100.0, 84.0),
            width: 18.0 * 2,
            height: 18.0 * 2,
          ),
        );
      canvas.save();
      canvas.translate(0.0, 1.5);
      canvas.drawPath(shape, Paint()..color = Color(0x1F283047));
      canvas.restore();
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100.0, 84.0),
            width: 18.0 * 2,
            height: 18.0 * 2,
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(-0.36, -0.5),
            radius: 0.8,
            colors: [Color(0xFFF4D9BA), Color(0xFFD3A499), Color(0xFFB98285)],
            stops: [0.0, 0.65, 1.0],
          ).createShader(shape.getBounds()),
      );
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100.0, 84.0),
            width: 16.8 * 2,
            height: 16.8 * 2,
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x59F9DFC3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100.0, 84.0),
            width: 9.4 * 2,
            height: 9.4 * 2,
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFF262B41));
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(100.0, 84.0),
            width: 10.5 * 2,
            height: 10.5 * 2,
          ),
        );
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x66947D87)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(96.0, 80.0),
            width: 2.7 * 2,
            height: 2.2 * 2,
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xFFF9EADB));
    }
    {
      final shape = Path()
        ..addOval(
          Rect.fromCenter(
            center: const Offset(103.5, 88.0),
            width: 1.0 * 2,
            height: 1.0 * 2,
          ),
        );
      canvas.drawPath(shape, Paint()..color = Color(0xA6C9BFCE));
    }
    canvas.restore();
    canvas.restore();
    {
      final shape = eye;
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0xFFE8D9E8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeJoin = StrokeJoin.round,
      );
    }
    {
      final shape = (Path()
        ..moveTo(84.0, 122.0)
        ..lineTo(116.0, 122.0));
      canvas.drawPath(shape, Paint()..color = Color(0x8C000000));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Color(0x8CB6A6CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FilmsSeenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
