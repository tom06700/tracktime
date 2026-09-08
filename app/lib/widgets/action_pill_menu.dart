import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One labelled command in the deployed menu. Data mutations stay with callers.
class ActionPill {
  const ActionPill({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });
  final String label;
  final IconData icon;
  final FutureOr<void> Function() onSelected;
  final bool destructive;
}

class ActionPillMenuButton extends StatefulWidget {
  const ActionPillMenuButton({
    super.key,
    required this.label,
    required this.actions,
    this.diameter = 30,
    this.enabled = true,
  });
  final String label;
  final List<ActionPill> actions;
  final double diameter;
  final bool enabled;

  @override
  State<ActionPillMenuButton> createState() => _ActionPillMenuButtonState();
}

class _ActionPillMenuButtonState extends State<ActionPillMenuButton>
    with WidgetsBindingObserver {
  bool _busy = false;
  _PillRoute? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    final route = _route;
    if (route != null && route.isCurrent) route.navigator?.pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final route = _route;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy || !widget.enabled || widget.actions.isEmpty) return;
    final navigator = Navigator.of(context);
    final box = context.findRenderObject()! as RenderBox;
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final actions = List<ActionPill>.of(widget.actions);
    final reduce = MediaQuery.disableAnimationsOf(context);
    final route = _PillRoute(
      anchor: anchor,
      actions: actions,
      reduceMotion: reduce,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      dismissLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    );
    _route = route;
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      final selection = await navigator.push<int>(route);
      // Finish removing the modal before mutating a card or opening a dialog.
      await route.completed;
      if (selection != null && mounted) {
        HapticFeedback.lightImpact();
        await actions[selection].onSelected();
      }
    } finally {
      _route = null;
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      tooltip: widget.label,
      // Consume rapid taps while open instead of passing them to the card.
      onPressed: widget.enabled && widget.actions.isNotEmpty ? _open : null,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
      icon: Container(
        width: widget.diameter,
        height: widget.diameter,
        decoration: BoxDecoration(
          color: const Color(0xCC161820),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: const Icon(Icons.more_horiz, size: 18, color: Colors.white),
      ),
    ),
  );
}

class _PillRoute extends PopupRoute<int> {
  _PillRoute({
    required this.anchor,
    required this.actions,
    required this.reduceMotion,
    required this.themes,
    required this.dismissLabel,
  }) : super(
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
         filter: reduceMotion
             ? null
             : ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
       );
  final Rect anchor;
  final List<ActionPill> actions;
  final bool reduceMotion;
  final CapturedThemes themes;
  final String dismissLabel;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 350);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 170);
  @override
  bool get barrierDismissible => true;
  @override
  Color get barrierColor => const Color(0x6B080A11);
  @override
  String get barrierLabel => dismissLabel;
  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => themes.wrap(_PillOverlay(route: this));
}

class _PillOverlay extends StatefulWidget {
  const _PillOverlay({required this.route});
  final _PillRoute route;
  @override
  State<_PillOverlay> createState() => _PillOverlayState();
}

class _PillOverlayState extends State<_PillOverlay> {
  bool _selected = false;
  void _dismiss([int? value]) {
    if (_selected) return;
    _selected = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final media = MediaQuery.of(context);
    final scaler = media.textScaler;
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 13,
      height: 1.25,
      fontWeight: FontWeight.w500,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _dismiss(),
      },
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Actions du film',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final safe = Rect.fromLTRB(
              media.padding.left + 12,
              media.padding.top + 10,
              constraints.maxWidth - media.padding.right - 12,
              constraints.maxHeight -
                  math.max(media.padding.bottom, media.viewInsets.bottom) -
                  12,
            );
            double longest = 0;
            for (final action in route.actions) {
              final painter = TextPainter(
                text: TextSpan(text: action.label, style: textStyle),
                textScaler: scaler,
                textDirection: Directionality.of(context),
              )..layout();
              longest = math.max(longest, painter.width);
              painter.dispose();
            }
            final width = math.min(safe.width, math.max(220.0, longest + 72));
            final heights = route.actions.map((action) {
              final painter = TextPainter(
                text: TextSpan(text: action.label, style: textStyle),
                textScaler: scaler,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: width - 70);
              final height = math.max(48.0, painter.height + 24);
              painter.dispose();
              return height;
            }).toList();
            final menuHeight =
                heights.fold<double>(0, (a, b) => a + b) +
                (heights.length - 1) * 9;
            final anchor = route.anchor;
            final closeX = anchor.left
                .clamp(safe.left, math.max(safe.left, safe.right - 44))
                .toDouble();
            final closeY = anchor.top
                .clamp(safe.top, math.max(safe.top, safe.bottom - 44))
                .toDouble();
            final below = math.max(0.0, safe.bottom - closeY - 52);
            final above = math.max(0.0, closeY - 8 - safe.top);
            final opensUp = below < menuHeight && above > below;
            final available = opensUp ? above : below;
            final height = math.min(menuHeight, available);
            final top = opensUp ? closeY - height - 8 : closeY + 52;
            final left = (anchor.right - width)
                .clamp(safe.left, math.max(safe.left, safe.right - width))
                .toDouble();
            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () => _dismiss(),
                  ),
                ),
                Positioned(
                  left: closeX,
                  top: closeY,
                  width: 44,
                  height: 44,
                  child: AnimatedBuilder(
                    animation: route.animation!,
                    builder: (context, child) {
                      final t = Curves.easeOutCubic.transform(
                        route.animation!.value,
                      );
                      return Transform.scale(
                        scale: .72 + .28 * t,
                        child: Transform.rotate(
                          angle: -.7 * (1 - t),
                          child: Opacity(opacity: t, child: child),
                        ),
                      );
                    },
                    child: Material(
                      color: const Color(0xFFD9CDF0),
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        tooltip: 'Fermer les actions',
                        onPressed: () => _dismiss(),
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFF292134),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < route.actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 9),
                          AnimatedBuilder(
                            animation: route.animation!,
                            builder: (context, child) {
                              final raw = route.animation!.value;
                              final delay = route.reduceMotion
                                  ? 0.0
                                  : math.min(.3, i * .13);
                              final t = ((raw - delay) / (1 - delay)).clamp(
                                0.0,
                                1.0,
                              );
                              final curved = Curves.easeOutBack.transform(t);
                              return Opacity(
                                opacity: Curves.easeOut.transform(t),
                                child: Transform.translate(
                                  offset: Offset(
                                    (anchor.center.dx - left - width / 2) *
                                        (1 - curved) *
                                        .35,
                                    (opensUp ? 24 : -24) * (1 - curved),
                                  ),
                                  child: Transform.scale(
                                    scale: .8 + .2 * curved,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: _Pill(
                              action: route.actions[i],
                              height: heights[i],
                              textStyle: textStyle,
                              autofocus: i == 0,
                              onTap: () => _dismiss(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.action,
    required this.height,
    required this.textStyle,
    required this.autofocus,
    required this.onTap,
  });
  final ActionPill action;
  final double height;
  final TextStyle textStyle;
  final bool autofocus;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final foreground = action.destructive
        ? const Color(0xFFE5B8AE)
        : const Color(0xFFF2EDF9);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: const Color(0xFF292630),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: .08)),
        ),
        elevation: 5,
        shadowColor: Colors.black45,
        clipBehavior: Clip.antiAlias,
        child: TextButton(
          autofocus: autofocus,
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: foreground,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: const StadiumBorder(),
            minimumSize: const Size(44, 48),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  action.label,
                  style: textStyle.copyWith(color: foreground),
                ),
              ),
              const SizedBox(width: 11),
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: action.destructive
                      ? const Color(0x15E58C78)
                      : const Color(0x19C5AEFD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  action.icon,
                  size: 18,
                  color: action.destructive
                      ? const Color(0xFFEDAFA0)
                      : const Color(0xFFD0BAF8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
