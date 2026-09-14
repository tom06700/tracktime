import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/series/widgets/season_selector.dart';

void main() {
  testWidgets('longue série : saison active visible, annulation et sélection', (
    tester,
  ) async {
    int? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: SeasonSelector(
              seasons: List.generate(31, (i) => i),
              selected: 23,
              onChanged: (s) => chosen = s,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saison 23'));
    await tester.pumpAndSettle();
    expect(find.text('Saison 23').hitTestable(), findsOneWidget);
    expect(find.text('Saison 24').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer les saisons'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
    await tester.tap(find.text('Saison 23'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saison 24'));
    await tester.pumpAndSettle();
    expect(chosen, 24);
    expect(find.text('Saisons'), findsNothing);
  });

  testWidgets('petit écran et texte agrandi : spéciaux accessibles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? chosen;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: SeasonSelector(
              seasons: const [0, 1, 2],
              selected: 2,
              onChanged: (s) => chosen = s,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Saison 2'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Spéciaux'));
    await tester.pumpAndSettle();
    expect(chosen, 0);
    expect(tester.takeException(), isNull);
  });
}
