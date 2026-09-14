import 'dart:async';
import 'package:flutter/painting.dart';
import 'package:tracktime/media/artwork_cache.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // UI scenarios keep deterministic image fixtures and require no platform
  // cache plugins. artwork_cache_test uses a real, isolated disk cache.
  ArtworkImages.debugProvider = NetworkImage.new;
  await testMain();
}
