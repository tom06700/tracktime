import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracktime/onboarding/welcome_screen.dart';
import 'package:tracktime/theme.dart';

void main() {
  Widget host() => MaterialApp(
        theme: buildTheme(),
        home: const WelcomeGate(child: Scaffold(body: Text('Ma collection'))),
      );

  testWidgets('intro terminée : accès à la collection, préférence persistée',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Ma collection'), findsNothing);
    await tester.ensureVisible(find.text('Entrer dans Nitrate'));
    await tester.tap(find.text('Entrer dans Nitrate'));
    await tester.pumpAndSettle();
    expect(find.text('Ma collection'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance()).getBool('nitrate.welcome.v1'),
        isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Entrer dans Nitrate'), findsNothing);
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
    await tester.ensureVisible(find.text('Entrer dans Nitrate'));
    await tester.tap(find.text('Entrer dans Nitrate'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
    expect(tester.takeException(), isNull);
  });
}
