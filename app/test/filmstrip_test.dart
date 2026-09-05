import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/onboarding/filmstrip_painter.dart';

void main() {
  testWidgets('la pellicule a une jointure périodique sans saut de dessin',
      (tester) async {
    Future<List<int>> pixels(double phase) async {
      final recorder = ui.PictureRecorder();
      FilmstripPainter(
              const AlwaysStoppedAnimation(1), AlwaysStoppedAnimation(phase))
          .paint(Canvas(recorder), const Size(400, 280));
      final picture = recorder.endRecording();
      final image = await picture.toImage(400, 280);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final result = bytes!.buffer.asUint8List().toList();
      image.dispose();
      picture.dispose();
      return result;
    }

    await tester.runAsync(() async {
      final start = await pixels(0);
      final end = await pixels(1);
      final middle = await pixels(.5);
      var seamDifference = 0;
      var movingDifference = 0;
      for (var i = 0; i < start.length; i++) {
        seamDifference += (start[i] - end[i]).abs();
        movingDifference += (start[i] - middle[i]).abs();
      }
      expect(seamDifference / start.length, lessThan(.1));
      expect(movingDifference / start.length, greaterThan(.1));
    });
  });
}
