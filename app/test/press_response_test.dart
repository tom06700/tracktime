import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/press_response.dart';

void main() {
  testWidgets('bouton natif : pression, annulation et action unique',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
          body: Center(
              child: FilledButton(
        onPressed: () => taps++,
        child: const Text('Ouvrir'),
      ))),
    ));
    final label = find.text('Ouvrir');
    final gesture = await tester.startGesture(tester.getCenter(label));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<PressResponse>(find.byType(PressResponse)).pressed,
        isTrue);
    expect(taps, 0);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(tester.widget<PressResponse>(find.byType(PressResponse)).pressed,
        isFalse);
    expect(taps, 0);
    await tester.tap(label);
    expect(taps, 1);
  });

  testWidgets('glisser la liste annule la pression sans ouvrir la carte',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ListView(
      children: [
        PressTarget(
            onTap: () => taps++,
            child: const SizedBox(
              height: 150,
              child: Center(child: Text('Affiche')),
            )),
        const SizedBox(height: 1500),
      ],
    ))));
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Affiche')));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<PressResponse>(find.byType(PressResponse)).pressed,
        isTrue);
    await gesture.moveBy(const Offset(0, -70));
    await tester.pump();
    expect(tester.widget<PressResponse>(find.byType(PressResponse)).pressed,
        isFalse);
    await gesture.up();
    expect(taps, 0);
  });

  testWidgets('mouvement réduit : pression sans changement de taille',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: PressResponse(pressed: true, child: Text('Stable')),
    )));
    await tester.pumpAndSettle();
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);
  });

  testWidgets('bouton désactivé : aucun état de pression', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: Center(
              child: FilledButton(onPressed: null, child: Text('Patiente'))),
        )));
    await tester.tap(find.text('Patiente'));
    await tester.pumpAndSettle();
    expect(tester.widget<PressResponse>(find.byType(PressResponse)).pressed,
        isFalse);
  });
}
