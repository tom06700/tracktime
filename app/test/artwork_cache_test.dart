import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/media/artwork_cache.dart';
import 'package:tracktime/media/palette.dart';

class _Files implements FileSystem {
  _Files(this.path);
  final String path;
  @override
  Future<File> createFile(String name) async =>
      const LocalFileSystem().file('$path/$name');
}

class _Pixels extends ImageProvider<_Pixels> {
  _Pixels(ui.Image source) {
    completer = OneFrameImageStreamCompleter(
      Future.value(ImageInfo(image: source.clone())),
    );
    handle = completer.keepAlive();
  }
  late final ImageStreamCompleter completer;
  late final ImageStreamCompleterHandle handle;
  @override
  Future<_Pixels> obtainKey(ImageConfiguration config) => SynchronousFuture(this);
  @override
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream,
      _Pixels key, ImageErrorListener handleError) {
    // Own the stream explicitly: the test concerns the palette consumer,
    // independently of Flutter's deferred global-cache eviction.
    stream.setCompleter(completer);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'le cache disque survit à un nouveau gestionnaire sans retélécharger',
    () async {
      final dir = io.Directory.systemTemp.createTempSync(
        'nitrate-artwork-test-',
      );
      var requests = 0;
      CacheManager make() => createArtworkCache(
        config: Config(
          'nitrate-test',
          fileSystem: _Files(dir.path),
          repo: JsonCacheInfoRepository(path: '${dir.path}/index.json'),
          fileService: HttpFileService(
            httpClient: MockClient((_) async {
              requests++;
              return http.Response.bytes(
                [1, 2, 3, 4],
                200,
                headers: {
                  'cache-control': 'max-age=86400',
                  'content-type': 'image/png',
                },
              );
            }),
          ),
        ),
      );
      var cache = make();
      try {
        final files = await Future.wait([
          cache.getSingleFile('https://example.test/poster.png'),
          cache.getSingleFile('https://example.test/poster.png'),
        ]);
        expect(requests, 1);
        expect(await files.first.readAsBytes(), [1, 2, 3, 4]);
        await cache.dispose();
        cache = make();
        expect(
          await (await cache.getSingleFile(
            'https://example.test/poster.png',
          )).readAsBytes(),
          [1, 2, 3, 4],
        );
        expect(requests, 1);
      } finally {
        await cache.dispose();
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'tailles de décodage bornées et regroupées selon la largeur physique',
    () {
      expect(artworkDecodeWidth(136, 3), 448);
      expect(artworkDecodeWidth(137, 3), 448);
      expect(artworkDecodeWidth(390, 3), 1216);
      expect(artworkDecodeWidth(double.infinity, 3), null);
      expect(artworkDecodeWidth(4000, 4), 2048);
    },
  );

  testWidgets('l’analyse des couleurs libère sa référence native', (tester) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(const Color(0xffaa5533), BlendMode.src);
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(64, 64)))!;
    picture.dispose();
    final provider = _Pixels(image);
    try {
      expect(await tester.runAsync(() => swatchesOfImage(provider)), isNotEmpty);
      // The original and the explicitly retained provider are the only owners.
      expect(image.debugGetOpenHandleStackTraces()!.length, 2);
    } finally {
      provider.handle.dispose();
      expect(image.debugGetOpenHandleStackTraces()!.length, 1);
      image.dispose();
    }
  });
}
