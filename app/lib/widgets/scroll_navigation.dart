import 'package:flutter/material.dart';

/// Keeps the body geometry stable while the floating navigation slides away.
class ScrollNavigationScaffold extends StatefulWidget {
  const ScrollNavigationScaffold({
    super.key,
    required this.tabIndex,
    required this.body,
    required this.bottomNavigationBar,
    this.appBar,
  });

  final int tabIndex;
  final Widget body;
  final Widget bottomNavigationBar;
  final PreferredSizeWidget? appBar;

  @override
  State<ScrollNavigationScaffold> createState() =>
      _ScrollNavigationScaffoldState();
}

class _ScrollNavigationScaffoldState extends State<ScrollNavigationScaffold> {
  final _hidden = ValueNotifier(false);
  double _travel = 0;

  @override
  void didUpdateWidget(covariant ScrollNavigationScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabIndex != widget.tabIndex) {
      _travel = 0;
      _hidden.value = false;
    }
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics.axisDirection != AxisDirection.down ||
        MediaQuery.accessibleNavigationOf(context)) {
      return false;
    }
    if (notification is ScrollStartNotification) _travel = 0;
    if (notification is! ScrollUpdateNotification ||
        notification.dragDetails == null ||
        metrics.outOfRange) {
      return false;
    }
    if (metrics.maxScrollExtent - metrics.minScrollExtent < 80) {
      _hidden.value = false;
      _travel = 0;
      return false;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) return false;
    if (_travel.sign != delta.sign) _travel = 0;
    _travel += delta;
    if (_travel >= 64) {
      _hidden.value = true;
    } else if (_travel <= -12) {
      _hidden.value = false;
    }
    return false;
  }

  @override
  void dispose() {
    _hidden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      extendBody: true,
      appBar: widget.appBar,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.body,
      ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: _hidden,
        child: widget.bottomNavigationBar,
        builder: (context, hidden, child) {
          final concealed = hidden && !accessible;
          return IgnorePointer(
            key: const ValueKey('navigation-interaction'),
            ignoring: concealed,
            child: ExcludeSemantics(
              excluding: concealed,
              child: AnimatedSlide(
                offset: concealed ? const Offset(0, 1) : Offset.zero,
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
