import 'dart:async';
import 'package:flutter/material.dart';
import '../motion.dart';
import 'nitrate_refresh_mark.dart';
import 'nitrate_banner.dart';

/// The gesture waits briefly; large libraries can finish syncing in the
/// background. Keep the actual job until it settles so pulls cannot stack it.
class BoundedRefreshIndicator extends StatefulWidget {
  const BoundedRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<BoundedRefreshIndicator> createState() =>
      _BoundedRefreshIndicatorState();
}

class _BoundedRefreshIndicatorState extends State<BoundedRefreshIndicator>
    with SingleTickerProviderStateMixin {
  static const _foregroundLimit = Duration(seconds: 8);
  static const _holdExtent = 72.0;
  late final AnimationController _hold = AnimationController(
    vsync: this,
    upperBound: _holdExtent,
    duration: Motion.normal,
  );
  bool _holding = false;
  Future<void>? _inFlight;
  bool _background = false;
  RefreshIndicatorStatus? _status;
  double _pullDistance = 0;
  double _physicalOverscroll = 0;

  void _statusChanged(RefreshIndicatorStatus? status) {
    setState(() => _status = status);
    final holding =
        status == RefreshIndicatorStatus.snap ||
        status == RefreshIndicatorStatus.refresh;
    if (_holding == holding) return;
    _holding = holding;
    final target = holding ? _holdExtent : 0.0;
    if (reduceMotionOf(context)) {
      _hold.value = target;
    } else {
      _hold.animateTo(target, duration: Motion.normal, curve: Motion.enter);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) _hold.value = _holding ? _holdExtent : 0;
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  bool _trackPull(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axisDirection != AxisDirection.down) {
      return false;
    }
    var distance = _pullDistance;
    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification ||
        notification.metrics.extentBefore > 0) {
      distance = 0;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      distance = (distance - (notification.scrollDelta ?? 0)).clamp(0, 1000);
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      distance = (distance - notification.overscroll).clamp(0, 1000);
    }
    final overscroll =
        (notification.metrics.minScrollExtent - notification.metrics.pixels)
            .clamp(0.0, double.infinity);
    if (distance != _pullDistance || overscroll != _physicalOverscroll) {
      setState(() {
        _pullDistance = distance;
        _physicalOverscroll = overscroll;
      });
    }
    return false;
  }

  void _message(
    String message, {
    NitrateBannerKind kind = NitrateBannerKind.info,
  }) {
    if (!mounted) return;
    NitrateMessenger.maybeOf(
      context,
    )?.showBanner(NitrateBanner(kind: kind, content: Text(message)));
  }

  Future<void> _perform() async {
    try {
      await widget.onRefresh();
    } catch (error, stack) {
      debugPrint('Actualisation impossible : $error\n$stack');
      _message(
        'Actualisation impossible. Réessaie dans un instant.',
        kind: NitrateBannerKind.error,
      );
    }
  }

  Future<void> _refresh() async {
    // Flutter 3.41's noSpinner callback omits the refresh transition itself.
    _statusChanged(RefreshIndicatorStatus.refresh);
    if (_background && _inFlight != null) {
      _message('La mise à jour continue en arrière-plan.');
      return;
    }
    final job = _inFlight ??= _perform().whenComplete(() {
      _inFlight = null;
      _background = false;
    });
    try {
      await job.timeout(_foregroundLimit);
    } on TimeoutException {
      _background = true;
      _message('La mise à jour continue en arrière-plan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // A scroll start is also emitted on pointer-down, before any pull exists.
    final visible = switch (_status) {
      RefreshIndicatorStatus.drag => _pullDistance >= 24,
      RefreshIndicatorStatus.armed ||
      RefreshIndicatorStatus.snap ||
      RefreshIndicatorStatus.refresh => true,
      _ => false,
    };
    return ClipRect(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _hold,
            // Native iOS bounce already moves the content. Only add the space
            // still missing, so its return settles at the held refresh position.
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                (_hold.value - _physicalOverscroll).clamp(0, _holdExtent),
              ),
              child: child,
            ),
            child: RefreshIndicator.noSpinner(
              onRefresh: _refresh,
              onStatusChange: _statusChanged,
              child: NotificationListener<ScrollNotification>(
                onNotification: _trackPull,
                child: widget.child,
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedSwitcher(
                  duration: reduceMotionOf(context)
                      ? Duration.zero
                      : Motion.fast,
                  child: visible
                      ? NitrateRefreshMark(
                          key: const ValueKey('nitrate-refresh-mark'),
                          refreshing: _status == RefreshIndicatorStatus.refresh,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
