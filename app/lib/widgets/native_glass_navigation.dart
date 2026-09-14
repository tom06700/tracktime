import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modern_controls.dart';

/// The system owns the material; Nitrate retains its page and gesture state.
class NativeGlassNavigation extends StatefulWidget {
  const NativeGlassNavigation({
    super.key,
    required this.labels,
    required this.symbols,
    required this.index,
    required this.onSelected,
    required this.fallback,
  });

  final List<String> labels, symbols;
  final int index;
  final ValueChanged<int> onSelected;
  final Widget fallback;

  @override
  State<NativeGlassNavigation> createState() => _NativeGlassNavigationState();
}

class _NativeGlassNavigationState extends State<NativeGlassNavigation> {
  static const _availability = MethodChannel('nitrate/native_navigation');
  bool _supported = false;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) _checkSupport();
  }

  Future<void> _checkSupport() async {
    try {
      final supported = await _availability.invokeMethod<bool>('isAvailable');
      if (mounted && supported == true) setState(() => _supported = true);
    } on MissingPluginException {
      // An older host binary can still render the original navigation.
    } on PlatformException {
      // Navigation remains available even if capability detection fails.
    }
  }

  Map<String, Object> get _configuration => {
    'labels': widget.labels,
    'symbols': widget.symbols,
    'selectedIndex': widget.index,
    'tintColor': ModernPalette.lilac.toARGB32(),
    'isDark': true,
    'reduceMotion': MediaQuery.disableAnimationsOf(context),
  };

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', _configuration);
    } on PlatformException {
      if (mounted) setState(() => _supported = false);
    } on MissingPluginException {
      if (mounted) setState(() => _supported = false);
    }
  }

  @override
  void didUpdateWidget(NativeGlassNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index ||
        !listEquals(widget.labels, oldWidget.labels) ||
        !listEquals(widget.symbols, oldWidget.symbols)) {
      _update();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // UIKit supplies the floating glass's own horizontal margins. Its host
    // spans the screen; the Flutter capsule needs the 20px content inset.
    if (!_supported) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: widget.fallback,
      );
    }
    // Match GlideControl, including its two 6px insets. Capability detection
    // must never move the content or change ScrollNavigationScaffold geometry.
    final height =
        79.0 +
        (MediaQuery.textScalerOf(context).scale(12) - 12).clamp(0.0, 30.0);
    final covered = ModalRoute.of(context)?.isCurrent == false;
    return SizedBox(
      height: height,
      child: ExcludeSemantics(
        excluding: covered,
        child: IgnorePointer(
          ignoring: covered,
          child: Opacity(
            opacity: covered ? 0 : 1,
            child: UiKitView(
              viewType: 'nitrate/native_navigation',
              layoutDirection: Directionality.of(context),
              // UIKit owns hit testing, touch feedback and accessibility.
              // Eager delivery avoids waiting for Flutter's gesture arena.
              gestureRecognizers: {
                Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
              },
              creationParams: _configuration,
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (id) {
                if (!mounted) return;
                _channel?.setMethodCallHandler(null);
                _channel = MethodChannel('nitrate/native_navigation/$id');
                _channel!.setMethodCallHandler((call) async {
                  if (!mounted || call.method != 'selected') return;
                  if (ModalRoute.of(context)?.isCurrent == false) return;
                  final index = call.arguments;
                  if (index is int &&
                      index >= 0 &&
                      index < widget.labels.length &&
                      index != widget.index) {
                    widget.onSelected(index);
                  }
                });
                _update();
              },
            ),
          ),
        ),
      ),
    );
  }
}
