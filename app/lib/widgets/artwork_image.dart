import 'package:flutter/material.dart';
import '../media/artwork_cache.dart';

/// Common loader for remote artwork: disk reuse plus a bounded memory decode.
/// An original file serves both small cards and larger detail views.
class ArtworkImage extends StatelessWidget {
  const ArtworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.frameBuilder,
    this.errorBuilder,
  });
  final String url;
  final double? width, height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final ImageFrameBuilder? frameBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final logicalWidth = width != null && width!.isFinite
          ? width!
          : constraints.maxWidth;
      final decodeWidth = artworkDecodeWidth(
        logicalWidth,
        MediaQuery.devicePixelRatioOf(context),
      );
      return Image(
        image: ResizeImage.resizeIfNeeded(
          decodeWidth,
          null,
          ArtworkImages.provider(url),
        ),
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: filterQuality,
        frameBuilder: frameBuilder,
        errorBuilder: errorBuilder,
      );
    },
  );
}
