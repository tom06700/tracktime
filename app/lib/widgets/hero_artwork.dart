import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../motion.dart';
import '../tmdb/artwork.dart';
import '../brand/nitrate_brand.dart';

/// Height that can be filled without enlarging the decoded source pixels.
/// A landscape source also retains at least 75% of its horizontal composition.
double heroArtworkHeight(Size pixels, Size viewport, double pixelRatio) {
  if (pixels.isEmpty ||
      viewport.isEmpty ||
      pixelRatio <= 0 ||
      pixels.width < viewport.width * pixelRatio) return 0;
  final natural = pixels.height / pixelRatio;
  final composition = viewport.width * pixels.height / pixels.width / .75;
  return math.min(viewport.height, math.min(natural, composition));
}

bool artworkFitsHero(Size pixels, Size viewport, double pixelRatio) =>
    heroArtworkHeight(pixels, viewport, pixelRatio) >=
    math.min(180, viewport.height);

class HeroArtwork extends StatefulWidget {
  const HeroArtwork({super.key, required this.sources, required this.seed});
  final List<String?> sources;
  final String seed;

  @override
  State<HeroArtwork> createState() => _HeroArtworkState();
}

class _HeroArtworkState extends State<HeroArtwork> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _selected;
  double _imageHeight = 0;
  int _request = 0;
  Size? _viewport;
  double? _ratio;

  void _detach() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void didUpdateWidget(HeroArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sources, widget.sources)) _scheduleLoad();
  }

  void _scheduleLoad() {
    final request = ++_request;
    _detach();
    _selected = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || request != _request || _viewport == null) return;
      final urls = widget.sources
          .map(absoluteArtwork)
          .whereType<String>()
          .toSet()
          .toList();
      _trySource(urls, 0, request);
    });
  }

  void _trySource(List<String> urls, int index, int request) {
    if (!mounted || request != _request || index >= urls.length) return;
    _detach();
    final stream = NetworkImage(urls[index])
        .resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, synchronousCall) {
      final pixels =
          Size(info.image.width.toDouble(), info.image.height.toDouble());
      info.dispose();
      // Also defer cache hits: resolving an image may invoke this synchronously.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _request) return;
        if (artworkFitsHero(pixels, _viewport!, _ratio!)) {
          _detach();
          setState(() {
            _selected = urls[index];
            _imageHeight = heroArtworkHeight(pixels, _viewport!, _ratio!);
          });
        } else {
          _trySource(urls, index + 1, request);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }, onError: (Object error, StackTrace? stackTrace) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == _request) {
          _trySource(urls, index + 1, request);
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    _request++;
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          final ratio = MediaQuery.devicePixelRatioOf(context);
          if (_viewport != viewport || _ratio != ratio) {
            _viewport = viewport;
            _ratio = ratio;
            _scheduleLoad();
          }
          return Stack(fit: StackFit.expand, children: [
            const ColoredBox(color: NitrateBrand.ink),
            AnimatedSwitcher(
              duration: motionOf(context, Motion.normal),
              child: _selected == null
                  ? const SizedBox.expand()
                  : Align(
                      key: ValueKey(_selected),
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: double.infinity,
                        height: _imageHeight,
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.transparent
                            ],
                            stops: [0, .72, 1],
                          ).createShader(rect),
                          child: Image.network(
                            _selected!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, _, _) => const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
            ),
          ]);
        },
      );
}
