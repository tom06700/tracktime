import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:tracktime/brand/nitrate_brand.dart';
import 'package:tracktime/widgets/nitrate_refresh_mark.dart';

void main() {
  testWidgets('reduced motion uses the static mark with loading semantics', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: NitrateRefreshMark(refreshing: true)),
        ),
      ),
    );
    expect(find.byType(NitrateSymbol), findsOneWidget);
    expect(find.byType(LottieBuilder), findsNothing);
    expect(find.bySemanticsLabel('Actualisation en cours'), findsOneWidget);
    expect(t.getSize(find.byType(NitrateRefreshMark)), const Size(44, 44));
    semantics.dispose();
  });

  test(
    'Flutter renders the matte, reveal, fade and transparent loop seam',
    () async {
      final composition = await LottieComposition.fromBytes(
        File(NitrateRefreshMark.asset).readAsBytesSync(),
      );
      expect(composition.warnings, isEmpty);
      final drawable = LottieDrawable(composition);
      final pixels = <int>[];
      for (final frame in [0, 24, 72, 112, 143]) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        drawable.setProgress(frame / 143.99);
        drawable.draw(canvas, const Rect.fromLTWH(0, 0, 256, 256));
        final picture = recorder.endRecording();
        final image = await picture.toImage(256, 256);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var alpha = 0;
        for (var i = 3; i < data.lengthInBytes; i += 4) {
          alpha += data.getUint8(i);
        }
        pixels.add(alpha);
        if (Platform.environment['NITRATE_LOADER_AUDIT'] == '1') {
          final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          File(
            '/tmp/nitrate-loader-flutter-$frame.png',
          ).writeAsBytesSync(png.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
      }
      expect(pixels[0], 0);
      expect(pixels[1], greaterThan(0));
      expect(pixels[2], greaterThan(pixels[1]));
      expect(pixels[3], allOf(greaterThan(0), lessThan(pixels[2])));
      expect(pixels[4], 0);
    },
  );
}
