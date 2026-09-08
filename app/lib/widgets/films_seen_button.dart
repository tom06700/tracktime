import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion.dart';
import 'films_seen_painter.dart';

/// Illustrated cinema eye: 1.6 seconds of motion, then rest until the next cycle.
class FilmsSeenButton extends StatefulWidget {
  const FilmsSeenButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<FilmsSeenButton> createState() => _FilmsSeenButtonState();
}

class _FilmsSeenButtonState extends State<FilmsSeenButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  Timer? _repeat;
  bool _visible = false;
  bool _foreground = true;
  final Stopwatch _sinceOpen = Stopwatch();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
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
      if (_repeat == null) {
        _controller.forward(from: 0);
        _repeat = Timer.periodic(const Duration(seconds: 7), (_) {
          _controller.forward(from: 0);
        });
      }
    } else {
      _repeat?.cancel();
      _repeat = null;
      _controller.stop();
      _controller.value = 0;
    }
  }

  void _open() {
    if (_sinceOpen.isRunning &&
        _sinceOpen.elapsed < const Duration(milliseconds: 500)) {
      return;
    }
    _sinceOpen
      ..reset()
      ..start();
    HapticFeedback.selectionClick();
    widget.onPressed();
  }

  @override
  void dispose() {
    _repeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Films vus',
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
      ),
      child: Semantics(
        label: 'Films vus',
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                size: const Size(42, 36.96),
                painter: FilmsSeenPainter(progress: _controller.value),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
