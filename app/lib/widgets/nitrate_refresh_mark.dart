import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../brand/nitrate_brand.dart';
import '../motion.dart';
import '../theme.dart';

/// The approved transparent ribbon loop, displayed only during a refresh.
class NitrateRefreshMark extends StatelessWidget {
  const NitrateRefreshMark({super.key, required this.refreshing});

  final bool refreshing;
  static const asset = 'assets/animations/nitrate-loader.json';
  static const _still = Center(child: NitrateSymbol(size: 27));

  @override
  Widget build(BuildContext context) => Semantics(
    label: refreshing
        ? 'Actualisation en cours'
        : 'Tirer puis relâcher pour actualiser',
    liveRegion: refreshing,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: Material(
          color: TtColors.surface,
          shape: const CircleBorder(),
          child: SizedBox.square(
            dimension: 44,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: !refreshing || reduceMotionOf(context)
                  ? _still
                  : Lottie.asset(
                      asset,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      frameRate: FrameRate.composition,
                      frameBuilder: (context, child, composition) =>
                          composition == null ? _still : child,
                      errorBuilder: (context, error, stack) => _still,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
