@Tags(['audit'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'support/audit_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/onboarding/welcome_screen.dart';
import 'package:tracktime/onboarding/notification_screen.dart';
import 'package:tracktime/widgets/modern_controls.dart';
import 'package:tracktime/theme.dart';

void main() {
  testWidgets('captures Flutter des références intégrées', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.runAsync(loadAuditFonts);
    final out = Directory('build/modern-audit')..createSync(recursive: true);
    Future<void> capture(String name) async {
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

    Widget host(Widget page) => MaterialApp(
        theme: buildTheme(), home: RepaintBoundary(key: key, child: page));
    await tester.pumpWidget(host(WelcomeScreen(onFinish: () async {})));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (i % 6 == 0) await capture('motion-intro-${i ~/ 6}');
    }
    await capture('01-intro');
    await tester.tap(find.text('C’est parti'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (i % 2 == 0) await capture('motion-departure-${i ~/ 2}');
    }
    await capture('02-departure');
    await tester.pump(const Duration(seconds: 1));
    for (final shape in CommandShape.values) {
      await tester.pumpWidget(host(Scaffold(
          body: Center(
              child: SizedBox(
                  width: 267,
                  child: ModernCommand(
                      shape: shape,
                      label: switch (shape) {
                        CommandShape.softCheck => 'Marquer vu',
                        CommandShape.attach => 'Ma liste',
                        CommandShape.nextUp => 'Épisode suivant',
                        CommandShape.surprise => 'Choisis pour moi',
                      },
                      onPressed: () {}))))));
      await tester.pumpAndSettle();
      await capture('03-${shape.name}');
    }
    await tester.pumpWidget(host(Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              GlideControl(
                  labels: const ['À voir', 'À venir'],
                  index: 0,
                  onSelected: (_) {}),
              const SizedBox(height: 36),
              GlideControl(
                  navigation: true,
                  labels: const ['Séries', 'Films', 'Explorer', 'Profil'],
                  icons: const [
                    Icons.layers_outlined,
                    Icons.movie_outlined,
                    Icons.search,
                    Icons.person_outline
                  ],
                  index: 1,
                  onSelected: (_) {}),
            ])))));
    await tester.pumpAndSettle();
    await capture('04-glide-navigation');
    await tester.pumpWidget(host(NotificationScreen(onFinish: () async {})));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await capture('05-notifications');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['NITRATE_DESIGN_AUDIT'] != '1');
}
