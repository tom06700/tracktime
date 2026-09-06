@Tags(['audit'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/profile/genre_filmstrip.dart';
import 'package:tracktime/theme.dart';
import 'support/pellicule_fixture.dart';
import 'support/audit_fonts.dart';

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final Uint8List bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpHeaders get headers => _Headers();
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final Uint8List bytes;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Client implements HttpClient {
  _Client(this.images);
  final Map<String, Uint8List> images;
  @override
  Future<HttpClientRequest> getUrl(Uri uri) async =>
      _Request(images[uri.path.substring(1)]!);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) => getUrl(uri);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('capture et interaction de la pellicule validée', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final images = <String, Uint8List>{};
    final source = File('../design/validated-handoff/pellicule/reference.html')
        .readAsStringSync();
    // Reference's demonstration images are audit-only, never application assets.
    final assets =
        RegExp(r'const assets=(\{.*?\});').firstMatch(source)!.group(1)!;
    for (final match in RegExp(r'"(\w+)":\s*"data:image/[^;]+;base64,([^"]+)"')
        .allMatches(assets)) {
      images[match.group(1)!] =
          Uint8List.fromList(const Base64Decoder().convert(match.group(2)!));
    }
    expect(images.length, 5);
    final key = GlobalKey();
    await tester.runAsync(loadAuditFonts);
    final out = Directory('build/modern-audit')..createSync(recursive: true);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(MaterialApp(
          theme: buildTheme(),
          home: RepaintBoundary(
              key: key,
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: GenreFilmStrip(
                              universe: pelliculeFixture(posters: const {
                            'Comédie': 'https://pellicule.test/onepiece',
                            'Animation': 'https://pellicule.test/jujutsu',
                            'Drame': 'https://pellicule.test/severance',
                            'Aventure': 'https://pellicule.test/dune',
                            'Action': 'https://pellicule.test/chainsaw',
                          }))))))));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      Future<void> shot(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        readableAuditFonts(boundary);
        await tester.pump();
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('${out.path}/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await shot('pellicule-initial');
      for (var frame = 0; frame < 165; frame++) {
        final id = switch (frame) {
          0 => 'genre:Drame',
          40 => 'genre:Drame',
          80 => 'genre:Action',
          83 => 'genre:Animation',
          125 => 'rest',
          _ => null
        };
        if (id != null) {
          final selector = frame == 40 || frame == 125 ? 'genre' : 'segment';
          await tester.tap(find.byKey(ValueKey('pellicule-$selector-$id')));
        }
        await tester.pump(const Duration(milliseconds: 33));
        await shot('pellicule-motion-$frame');
      }
      await shot('pellicule-selected');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, createHttpClient: (_) => _Client(images));
  },
      skip: Platform.environment['NITRATE_PELLICULE_AUDIT'] != '1',
      timeout: const Timeout(Duration(minutes: 2)));
}
