@Tags(['audit'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'support/audit_fonts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/onboarding/welcome_screen.dart';
import 'package:tracktime/onboarding/flight_painter.dart';
import 'package:tracktime/onboarding/notification_screen.dart';
import 'package:tracktime/notifications/notification_permission.dart';
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
    await tester.pumpWidget(host(MediaQuery(
        data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 59, bottom: 34)),
        child: WelcomeScreen(onFinish: () async {}))));
    bool ready() =>
        tester.widgetList<CustomPaint>(find.byType(CustomPaint)).any((w) =>
            w.painter is FlightPainter &&
            (w.painter! as FlightPainter).sprites.length ==
                flightAssets.length);
    for (var attempt = 0; attempt < 40 && !ready(); attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(ready(), isTrue,
        reason:
            'Les 12 objets doivent être décodés avant la séquence de captures.');
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await capture('motion-intro-$i');
    }
    await capture('01-intro');
    await tester.tap(find.text('C’est parti'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await capture('motion-departure-$i');
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
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        await capture('motion-control-${shape.name}-$frame');
      }
    }
    var tab = 0, section = 0;
    await tester.pumpWidget(host(StatefulBuilder(
        builder: (context, setState) => Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GlideControl(
                          labels: const ['À voir', 'À venir'],
                          index: section,
                          onSelected: (i) => setState(() => section = i)),
                      const SizedBox(height: 36),
                      GlideControl(
                          navigation: true,
                          labels: const [
                            'Séries',
                            'Films',
                            'Explorer',
                            'Profil'
                          ],
                          icons: const [
                            Icons.layers_outlined,
                            Icons.movie_outlined,
                            Icons.search,
                            Icons.person_outline
                          ],
                          index: tab,
                          onSelected: (i) => setState(() => tab = i)),
                    ]))))));
    await tester.pumpAndSettle();
    await capture('04-glide-navigation');
    for (final destination in ['Profil', 'Séries', 'À venir', 'À voir']) {
      await tester.tap(find.text(destination));
      await tester.pump();
      for (var frame = 0; frame < 14; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
        await capture('edge-$destination-$frame');
      }
    }
    await tester.pumpWidget(host(NotificationScreen(
        onFinish: () async {}, permission: const _AuditPermission())));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 33));
    }
    await capture('05-notifications');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(NotificationScreen(
        onFinish: () async {},
        permission: const _AuditPermission(authorized: true))));
    await tester.pump();
    await capture('06-notifications-continue');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  }, skip: Platform.environment['NITRATE_DESIGN_AUDIT'] != '1');
}

// Presentation fixture only. Real channel behavior is covered separately.
class _AuditPermission extends NotificationPermission {
  const _AuditPermission({this.authorized = false});
  final bool authorized;
  @override
  Future<NotificationAccess> status() async => authorized
      ? NotificationAccess.authorized
      : NotificationAccess.notDetermined;
}
