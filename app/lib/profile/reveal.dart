import 'package:flutter/material.dart';

/// Apparition « générique de film » : la section se révèle en fondu + léger
/// glissement vers le haut la première fois qu'elle entre dans le viewport.
/// Respecte MediaQuery.disableAnimations (affichage direct).
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delayMs = 0});

  final Widget child;

  /// Décalage avant l'animation (stagger des premières sections).
  final int delayMs;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  ScrollPosition? _pos;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _pos?.removeListener(_check);
    _pos = Scrollable.maybeOf(context)?.position;
    _pos?.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_done || !mounted) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _finish(instant: true);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final y = box.localToGlobal(Offset.zero).dy;
    if (y < MediaQuery.sizeOf(context).height * 0.92) _finish();
  }

  void _finish({bool instant = false}) {
    _done = true;
    _pos?.removeListener(_check);
    if (instant) {
      _c.value = 1;
      return;
    }
    if (widget.delayMs == 0) {
      _c.forward();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - _a.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
