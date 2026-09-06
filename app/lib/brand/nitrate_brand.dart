import 'package:flutter/material.dart';
import 'ribbon_paths.dart';

/// Approved modern identity; Inter is bundled with its OFL licence.
abstract final class NitrateBrand {
  static const ink = Color(0xFF101113);
  static const ivory = Color(0xFFF2F3F5);
  static const displayFamily = 'Inter';
  static TextStyle display(double size) => TextStyle(
        fontFamily: displayFamily,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.1,
        color: ivory,
      );
}

/// The approved outlined signature, scaled uniformly within available space.
class NitrateWordmark extends StatelessWidget {
  const NitrateWordmark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Nitrate',
        image: true,
        child: ExcludeSemantics(
            child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
              height: size,
              child: AspectRatio(
                aspectRatio: 648 / 157,
                child: CustomPaint(painter: _WordmarkPainter()),
              )),
        )),
      );
}

class NitrateSymbol extends StatelessWidget {
  const NitrateSymbol(
      {super.key, this.size = 24, this.color = const Color(0xFFC5AEFD)});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Nitrate',
        image: true,
        child: CustomPaint(
            size: Size(size, size * 224 / 234), painter: _SymbolPainter(color)),
      );
}

/// Reused by the flight painter without rasterization or font substitution.
void paintNitrateSymbol(Canvas canvas, Rect bounds,
    {Color color = const Color(0xFFC5AEFD)}) {
  final target = applyBoxFit(BoxFit.contain, const Size(234, 224), bounds.size)
      .destination;
  final rect = Alignment.center.inscribe(target, bounds);
  canvas.save();
  canvas.translate(rect.left, rect.top);
  canvas.scale(rect.width / 234);
  canvas.drawPath(ribbonPath0, Paint()..color = color);
  canvas.restore();
}

class _SymbolPainter extends CustomPainter {
  const _SymbolPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) =>
      paintNitrateSymbol(canvas, Offset.zero & size, color: color);
  @override
  bool shouldRepaint(_SymbolPainter oldDelegate) => color != oldDelegate.color;
}

class _WordmarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 648);
    canvas.drawPath(lockupPath0, Paint()..color = const Color(0xFFC5AEFD));
    canvas.drawPath(lockupPath1, Paint()..color = const Color(0xFFF7F2EF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WordmarkPainter oldDelegate) => false;
}
