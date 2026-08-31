import 'package:flutter/material.dart';

import '../theme.dart';

/// Bloc de chargement. Un battement d'opacité lent suffit à signaler l'attente
/// — un shimmer balayant attire davantage l'œil que le contenu qu'il annonce.
/// Sous Reduce Motion, le bloc reste fixe.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 12,
    this.margin,
    this.tint,
  });

  final double? width;
  final double? height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  /// Teinte du bloc. Sert à accorder l'attente à l'ambiance de la fiche —
  /// discrètement : un squelette reste sombre, il n'annonce pas une couleur.
  final Color? tint;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _pulse.stop();
      _pulse.value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.45,
          end: 0.85,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.tint ?? TtColors.surfaceHi,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}
