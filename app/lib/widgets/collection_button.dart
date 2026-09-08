import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';

/// A compact collection with an automatic, gently spaced fan animation.
class CollectionButton extends StatefulWidget {
  const CollectionButton({
    super.key,
    required this.onPressed,
    this.label = 'Mes séries',
  });
  final VoidCallback onPressed;
  final String label;

  @override
  State<CollectionButton> createState() => _CollectionButtonState();
}

class _CollectionButtonState extends State<CollectionButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _fan;
  bool _visible = true;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
    _fan = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 360,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 600,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(0), weight: 6040),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        !reduceMotionOf(context) &&
        (ModalRoute.isCurrentOf(context) ?? true);
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMotion();
  }

  void _syncMotion() {
    if (_visible && _foreground) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  DateTime? _lastOpen;

  void _open() {
    final now = DateTime.now();
    if ((_lastOpen != null &&
        now.difference(_lastOpen!) < const Duration(milliseconds: 500))) {
      return;
    }
    _lastOpen = now;
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    excludeFromSemantics: true,
    child: TextButton(
      onPressed: _open,
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused)
              ? const Color(0x22CAB7FF)
              : Colors.transparent,
        ),
        foregroundBuilder: (context, states, child) {
          return Semantics(
            label: widget.label,
            child: AnimatedBuilder(
              animation: _fan,
              builder: (context, _) {
                final amount = _fan.value;
                return Transform.scale(
                  scale: .82 * (1 - amount * .07),
                  child: SizedBox(
                    width: 48,
                    height: 52,
                    child: ExcludeSemantics(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Transform.translate(
                              offset: Offset(
                                (i - 1) * (10 - amount * 5),
                                (i == 0
                                        ? 3
                                        : i == 1
                                        ? -3
                                        : 1) +
                                    amount * 2,
                              ),
                              child: Transform.rotate(
                                angle:
                                    (i == 0
                                        ? -.20
                                        : i == 1
                                        ? -.1
                                        : 0) *
                                    (1 - amount * .8),
                                alignment: Alignment.bottomCenter,
                                child: _PosterTile(index: i),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      child: const SizedBox(width: 48, height: 52),
    ),
  );
}

class _PosterTile extends StatelessWidget {
  const _PosterTile({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 37,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4.5),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4.5),
      border: Border.all(color: const Color(0xE6F2F3F5), width: 1),
    ),
    clipBehavior: Clip.antiAlias,
    child: OverflowBox(
      alignment: Alignment(index - 1.0, 0),
      minWidth: 75,
      maxWidth: 75,
      minHeight: 37,
      maxHeight: 37,
      child: Image.asset(
        'assets/images/collection_posters.png',
        width: 75,
        height: 37,
        cacheWidth: 450,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
    ),
  );
}
