import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/onboarding/welcome_screen.dart';
import 'package:tracktime/onboarding/flight_painter.dart';
import 'package:tracktime/theme.dart';

void main() {
  testWidgets(
      'boucle continue, arrêt en arrière-plan et réduction des animations',
      (tester) async {
    Widget page(bool reduce) => MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
              child: child!),
          home: WelcomeScreen(onFinish: () async {}),
        );
    await tester.pumpWidget(page(false));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 20));
    expect(tester.binding.hasScheduledFrame, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('envol derrière le header jusqu’au bord supérieur',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 59, bottom: 34),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: WelcomeScreen(onFinish: () async {}),
    ));
    await tester.pump();
    final flight = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is FlightPainter);
    final bounds = tester.getRect(flight);
    expect(bounds.top, 0);
    expect(bounds.left, 0);
    expect(bounds.right, 390);
    expect(tester.getRect(find.text('nitrate')).top, greaterThanOrEqualTo(59));
    expect(find.text('Passer').hitTestable(), findsOneWidget);
    expect(find.text('C’est parti').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Widget host() => MaterialApp(
        theme: buildTheme(),
        home: const WelcomeGate(child: Scaffold(body: Text('Ma collection'))),
      );

  testWidgets('intro terminée : accès à la collection, préférence persistée',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Ma collection'), findsNothing);
    await tester.ensureVisible(find.text('C’est parti'));
    await tester.pump();
    expect(find.text('C’est parti').hitTestable(), findsOneWidget);
    await tester.tap(find.text('C’est parti'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('La suite.\nSans la manquer.'), findsOneWidget);
    await tester.ensureVisible(find.text('Plus tard'));
    await tester.pump();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(find.text('Ma collection'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance()).getBool('nitrate.welcome.v1'),
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('C’est parti'), findsNothing);
    expect(find.text('Ma collection'), findsOneWidget);
  });

  testWidgets(
      'petit écran, texte agrandi et mouvement réduit : action accessible',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: WelcomeScreen(onFinish: () async {
        finished = true;
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('C’est parti'));
    await tester.pump();
    expect(find.text('C’est parti').hitTestable(), findsOneWidget);
    await tester.tap(find.text('C’est parti'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
