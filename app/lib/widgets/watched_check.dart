import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../motion.dart';

/// Confirmation follows persisted state; the animation never triggers a write.
class WatchedCheck extends StatefulWidget {
  const WatchedCheck({
    super.key,
    required this.confirmed,
    this.size = 24,
    this.color = const Color(0xFF455E33),
    this.busy = false,
  });
  final bool confirmed;
  final bool busy;
  final double size;
  final Color color;
  static const duration = Duration(milliseconds: 500);
  static const asset = 'assets/animations/watched-check.json';

  @override
  State<WatchedCheck> createState() => _WatchedCheckState();
}

class _WatchedCheckState extends State<WatchedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WatchedCheck.duration,
    value: widget.confirmed ? 1 : 0,
  );
  @override
  void didUpdateWidget(WatchedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confirmed != widget.confirmed) {
      if (!widget.confirmed || reduceMotionOf(context)) {
        _controller.value = widget.confirmed ? 1 : 0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _controller.value = widget.confirmed ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: widget.busy ? 0 : 1,
            child: RepaintBoundary(
              child: reduceMotionOf(context)
                  ? Icon(
                      widget.confirmed ? Icons.check : Icons.circle_outlined,
                      size: widget.size,
                      color: widget.color,
                    )
                  : ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        widget.color,
                        BlendMode.srcIn,
                      ),
                      child: Lottie.asset(
                        WatchedCheck.asset,
                        controller: _controller,
                        repeat: false,
                        width: widget.size,
                        height: widget.size,
                        frameBuilder: (_, child, composition) =>
                            composition == null
                            ? Icon(
                                widget.confirmed
                                    ? Icons.check
                                    : Icons.circle_outlined,
                                size: widget.size,
                                color: widget.color,
                              )
                            : child,
                        errorBuilder: (_, error, stack) => Icon(
                          widget.confirmed
                              ? Icons.check
                              : Icons.circle_outlined,
                          size: widget.size,
                          color: widget.color,
                        ),
                      ),
                    ),
            ),
          ),
          if (widget.busy)
            SizedBox.square(
              dimension: widget.size * .7,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.color,
              ),
            ),
        ],
      ),
    ),
  );
}
