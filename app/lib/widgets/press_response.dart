import 'package:flutter/material.dart';

import '../motion.dart';

/// One tactile rhythm for native buttons, artwork cards and navigation.
/// Only painting changes: layout, hit targets and semantics keep their size.
class PressResponse extends StatelessWidget {
  const PressResponse({super.key, required this.pressed, required this.child});

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: pressed && !reduceMotionOf(context) ? .975 : 1,
        duration: motionOf(context, Duration(milliseconds: pressed ? 90 : 240)),
        curve: Curves.easeOutCubic,
        child: child,
      );
}

/// Uses the button's own gesture/keyboard state; no competing recognizer.
Widget buttonPressResponse(
        BuildContext context, Set<WidgetState> states, Widget? child) =>
    PressResponse(
      pressed: states.contains(WidgetState.pressed) &&
          !states.contains(WidgetState.disabled),
      child: child ?? const SizedBox.shrink(),
    );

/// For surfaces that have no built-in button state. Dragging a surrounding
/// list cancels the press through the gesture arena and never opens the card.
class PressTarget extends StatefulWidget {
  const PressTarget({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<PressTarget> createState() => _PressTargetState();
}

class _PressTargetState extends State<PressTarget> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: PressResponse(pressed: _pressed, child: widget.child),
      );
}
