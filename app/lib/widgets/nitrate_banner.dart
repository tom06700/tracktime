import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

enum NitrateBannerKind { success, info, error }

/// One transient message per root navigator, above routes and the navbar.
/// Capturing this handle before an await is safe if the source card disappears.
class NitrateMessenger {
  NitrateMessenger._(this._overlay);
  static final _instances = Expando<NitrateMessenger>();
  final OverlayState _overlay;
  OverlayEntry? _entry;

  static NitrateMessenger of(BuildContext context) {
    final overlay = Overlay.of(context, rootOverlay: true);
    return _instances[overlay] ??= NitrateMessenger._(overlay);
  }

  static NitrateMessenger? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    return overlay == null
        ? null
        : (_instances[overlay] ??= NitrateMessenger._(overlay));
  }

  bool get mounted => _overlay.mounted;

  void showBanner(NitrateBanner banner) {
    if (!mounted) return;
    _remove();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BannerPresentation(
        banner: banner,
        onClosed: () {
          if (identical(_entry, entry)) _remove();
        },
      ),
    );
    _entry = entry;
    _overlay.insert(entry);
  }

  void _remove() {
    final entry = _entry;
    _entry = null;
    if (entry == null) return;
    // The overlay itself owns teardown when the app/navigator is disposed.
    if (mounted) entry.remove();
    entry.dispose();
  }
}

/// Graphite surface and the same type, colour and spacing on every screen.
class NitrateBanner extends StatelessWidget {
  const NitrateBanner({
    super.key,
    required this.content,
    this.title,
    this.kind = NitrateBannerKind.info,
    this.action,
    this.duration,
  });

  final Widget content;
  final String? title;
  final NitrateBannerKind kind;
  final NitrateBannerAction? action;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final accent = switch (kind) {
      NitrateBannerKind.success => TtColors.amber,
      NitrateBannerKind.info => const Color(0xFFCAB7FF),
      NitrateBannerKind.error => TtColors.danger,
    };
    final icon = switch (kind) {
      NitrateBannerKind.success => Icons.check_rounded,
      NitrateBannerKind.info => Icons.info_outline_rounded,
      NitrateBannerKind.error => Icons.priority_high_rounded,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF22232A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 18;
                if (stacked) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(icon, size: 22, color: accent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title ??
                                  switch (kind) {
                                    NitrateBannerKind.success => 'Confirmation',
                                    NitrateBannerKind.info => 'Information',
                                    NitrateBannerKind.error =>
                                      'Action impossible',
                                  },
                              style: const TextStyle(
                                color: TtColors.dim,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fermer le message',
                            onPressed: () =>
                                _BannerScope.of(context)?.dismiss(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: TtColors.dim,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4),
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                          child: content,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(height: 8),
                        action!,
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 19, color: accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null) ...[
                              Text(
                                title!,
                                style: const TextStyle(
                                  color: TtColors.dim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                            ],
                            DefaultTextStyle.merge(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                              child: content,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (action != null) ...[const SizedBox(width: 8), action!],
                    IconButton(
                      tooltip: 'Fermer le message',
                      onPressed: () => _BannerScope.of(context)?.dismiss(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: TtColors.dim,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class NitrateBannerAction extends StatelessWidget {
  const NitrateBannerAction({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () {
      if (_BannerScope.of(context)?.dismiss() ?? true) onPressed();
    },
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    child: Text(label),
  );
}

class _BannerScope extends InheritedWidget {
  const _BannerScope({required this.dismiss, required super.child});
  final bool Function() dismiss;
  static _BannerScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BannerScope>();
  @override
  bool updateShouldNotify(_BannerScope oldWidget) => false;
}

class _BannerPresentation extends StatefulWidget {
  const _BannerPresentation({required this.banner, required this.onClosed});
  final NitrateBanner banner;
  final VoidCallback onClosed;
  @override
  State<_BannerPresentation> createState() => _BannerPresentationState();
}

class _BannerPresentationState extends State<_BannerPresentation>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: Motion.normal,
    reverseDuration: Motion.fast,
  );
  Timer? _timer;
  bool _started = false, _closing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _animation.value = 1;
      _schedule();
    } else {
      _animation.forward().whenComplete(_schedule);
    }
  }

  void _schedule() {
    if (!mounted || _closing) return;
    _timer?.cancel();
    final base =
        widget.banner.duration ??
        Duration(
          seconds:
              widget.banner.action != null ||
                  widget.banner.kind == NitrateBannerKind.error
              ? 6
              : 4,
        );
    final accessible = MediaQuery.accessibleNavigationOf(context);
    _timer = Timer(accessible ? base * 2 : base, _dismiss);
  }

  bool _dismiss() {
    if (_closing || !mounted) return false;
    _closing = true;
    _timer?.cancel();
    if (reduceMotionOf(context)) {
      widget.onClosed();
    } else {
      _animation.reverse().whenComplete(() {
        if (mounted) widget.onClosed();
      });
    }
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: SafeArea(
      bottom: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _BannerScope(
              dismiss: _dismiss,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final t = Motion.enter.transform(_animation.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, -Motion.rise * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: Dismissible(
                  key: ObjectKey(widget.banner),
                  direction: DismissDirection.up,
                  movementDuration: motionOf(context, Motion.normal),
                  resizeDuration: null,
                  onDismissed: (_) => widget.onClosed(),
                  child: Listener(
                    onPointerDown: (_) => _timer?.cancel(),
                    onPointerUp: (_) => _schedule(),
                    onPointerCancel: (_) => _schedule(),
                    child: widget.banner,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
