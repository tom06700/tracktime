@Tags(['audit'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/portal/portal_door_painter.dart';
import 'package:tracktime/widgets/portal/portal_geometry.dart';

void main() {
  testWidgets(
    'export native portal camera poses',
    (tester) async {
      await tester.runAsync(() async {
        final dir = Directory('build/audit/portal')
          ..createSync(recursive: true);
        for (final t in [0.0, .65, 1.05, 1.35]) {
          final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
          canvas.scale(2);
          const size = Size(402, 874), stage = Rect.fromLTWH(0, 190, 402, 290);
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = const Color(0xFF101113),
          );
          PortalDoorPainter(
            geometry: (_) => PortalGeometry(
              stage: stage,
              viewport: size,
              phase: .3,
              seconds: t,
              travelling: true,
            ),
          ).paint(canvas, size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(804, 1748);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${dir.path}/door-$t.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      });
    },
    skip: Platform.environment['NITRATE_PORTAL_AUDIT'] != '1',
  );
}
