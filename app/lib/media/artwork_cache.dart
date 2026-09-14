import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared compressed files; the OS may reclaim its cache directory.
CacheManager createArtworkCache({Config? config}) => CacheManager(
  config ??
      Config(
        'nitrate_artwork_v1',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 500,
      ),
);

abstract final class ArtworkImages {
  static final cache = createArtworkCache();

  /// Widget tests substitute their existing network fixtures. Disk persistence
  /// is exercised separately with the real manager and isolated files.
  @visibleForTesting
  static ImageProvider Function(String)? debugProvider;

  static ImageProvider provider(String url) =>
      debugProvider?.call(url) ??
      CachedNetworkImageProvider(url, cacheManager: cache);
}

/// Bucket widths so tiny layout differences do not retain duplicate decodes.
/// Width only preserves the original image's aspect ratio.
int? artworkDecodeWidth(double logicalWidth, double pixelRatio) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
  return ((logicalWidth * pixelRatio / 64).ceil() * 64).clamp(64, 2048);
}
