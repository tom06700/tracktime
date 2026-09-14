import 'package:flutter/material.dart';
import '../../motion.dart';
import '../../widgets/modern_controls.dart';

class SeasonCompleteState extends StatelessWidget {
  const SeasonCompleteState({
    super.key,
    required this.count,
    required this.onReview,
    this.onNext,
    this.nextSeason,
  });
  final int count;
  final int? nextSeason;
  final VoidCallback onReview;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 42, 24, 28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motionOf(context, const Duration(milliseconds: 540)),
            curve: const Cubic(.2, .75, .2, 1),
            builder: (_, value, _) => CustomPaint(
              size: const Size(54, 54),
              painter: _CompleteCheck(value),
            ),
          ),
        ),
        const SizedBox(height: 19),
        Semantics(
          header: true,
          child: const Text(
            'Saison terminée',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
              letterSpacing: -.5,
              color: Color(0xFFECE6F5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$count épisode${count == 1 ? '' : 's'} vu${count == 1 ? '' : 's'}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFFA79CAB)),
        ),
        if (onNext != null) ...[
          const SizedBox(height: 25),
          FilledButton.icon(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: ModernPalette.lilac,
              foregroundColor: const Color(0xFF342453),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text('Saison suivante · $nextSeason'),
          ),
        ] else
          const SizedBox(height: 16),
        TextButton(
          onPressed: onReview,
          child: const Text(
            'Revoir les épisodes',
            style: TextStyle(color: ModernPalette.lilac),
          ),
        ),
      ],
    ),
  );
}

class _CompleteCheck extends CustomPainter {
  const _CompleteCheck(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, 26, Paint()..color = const Color(0xFF232A20));
    canvas.drawCircle(
      center,
      25.5,
      Paint()
        ..color = const Color(0xFF455139)
        ..style = PaintingStyle.stroke,
    );
    final path = Path()
      ..moveTo(16, 27)
      ..lineTo(24, 35)
      ..lineTo(39, 19);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = ModernPalette.lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CompleteCheck oldDelegate) =>
      oldDelegate.progress != progress;
}
