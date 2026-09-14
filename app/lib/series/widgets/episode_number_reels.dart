import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../motion.dart';
import '../../widgets/modern_controls.dart';

/// One bounded animation for all digits. New selections start at the currently
/// painted positions, so repeated presses never queue up stale numbers.
class EpisodeNumberReels extends StatefulWidget {
  const EpisodeNumberReels({
    super.key,
    required this.number,
    this.animated = true,
  });
  final int number;
  final bool animated;

  @override
  State<EpisodeNumberReels> createState() => _EpisodeNumberReelsState();
}

class _EpisodeNumberReelsState extends State<EpisodeNumberReels>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController.unbounded(vsync: this, value: 1);
  List<double> _from = [], _to = [];
  double _fromWidth = 1, _toWidth = 1;
  List<double> get _positions => List.generate(
    _to.length,
    (i) => _from[i] + (_to[i] - _from[i]) * _motion.value,
  );

  @override
  void initState() {
    super.initState();
    _reset();
  }

  List<double> _digits(int number) =>
      '$number'.split('').reversed.map((d) => double.parse(d)).toList();

  void _reset() {
    _motion.stop();
    _from = _to = _digits(widget.number);
    _fromWidth = _toWidth = _to.length.toDouble();
    _motion.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) _reset();
  }

  @override
  void didUpdateWidget(EpisodeNumberReels oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.number == widget.number) return;
    if (!widget.animated || reduceMotionOf(context)) {
      _reset();
      return;
    }
    final current = _positions;
    final digits = _digits(widget.number);
    _fromWidth += (_toWidth - _fromWidth) * _motion.value;
    _toWidth = digits.length.toDouble();
    final length = math.max(current.length, digits.length);
    _from = List.generate(length, (i) => i < current.length ? current[i] : 0);
    final increasing = widget.number > oldWidget.number;
    _to = List.generate(length, (i) {
      final desired = i < digits.length ? digits[i] : 0.0;
      final priorTarget = i < _to.length ? _to[i] : 0.0;
      final lastDigit = priorTarget.round() % 10;
      var delta = desired - lastDigit;
      if (increasing && delta < 0) delta += 10;
      if (!increasing && delta > 0) delta -= 10;
      return priorTarget + delta;
    });
    _motion.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 380, damping: 34),
        0,
        1,
        0,
        tolerance: const Tolerance(distance: .001, velocity: .01),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.textScalerOf(context).scale(40);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final width = _fromWidth + (_toWidth - _fromWidth) * _motion.value;
            return CustomPaint(
              size: Size(fontSize * .66 * math.max(1, width), fontSize * 1.5),
              painter: _ReelsPainter(_positions, width, fontSize),
            );
          },
        ),
      ),
    );
  }
}

class _ReelsPainter extends CustomPainter {
  _ReelsPainter(this.positions, this.columns, this.fontSize);
  final List<double> positions;
  final double columns, fontSize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final advance = fontSize * .66;
    for (var column = 0; column < positions.length; column++) {
      final visibility = (columns - column).clamp(0.0, 1.0);
      if (visibility == 0) continue;
      final position = positions[column];
      for (var offset = -2; offset <= 2; offset++) {
        final digit = position.round() + offset;
        final distance = digit - position;
        final opacity =
            (1 - math.pow(distance.abs() / 1.5, 2)).clamp(0.0, 1.0) *
            visibility;
        if (opacity < .01) continue;
        final text = TextPainter(
          text: TextSpan(
            text: '${digit % 10}',
            style: TextStyle(
              color: ModernPalette.lilac.withValues(alpha: opacity),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(
          size.width - advance * (column + .5),
          size.height / 2 + distance * fontSize * 1.16,
        );
        canvas.scale(1, math.cos(distance * .55).abs().clamp(.3, 1));
        text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
        canvas.restore();
        text.dispose();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReelsPainter oldDelegate) => true;
}
