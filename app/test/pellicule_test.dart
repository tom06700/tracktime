import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/profile/genre_filmstrip.dart';
import 'package:tracktime/profile/universe.dart';
import 'package:tracktime/theme.dart';
import 'support/pellicule_fixture.dart';

Finder genre(String id) => find.byKey(ValueKey('pellicule-genre-$id'));
Finder segment(String id) => find.byKey(ValueKey('pellicule-segment-$id'));
Finder focus(String name, int value) => find.byWidgetPredicate((w) =>
    w is Semantics &&
    w.properties.liveRegion == true &&
    w.properties.label == '$name, $value pour cent');
Future<void> host(WidgetTester tester,
    {Universe? data,
    bool reduced = false,
    double width = 390,
    double scale = 1}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 1200),
              disableAnimations: reduced,
              textScaler: TextScaler.linear(scale)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child:
                      GenreFilmStrip(universe: data ?? pelliculeFixture()))))));
  await tester.pump();
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });
  testWidgets('segments, grands boutons et pourcentage partagent la sélection',
      (tester) async {
    addTearDown(tester.view.reset);
    await host(tester);
    expect(focus('Comédie', 19), findsOneWidget);
    await tester.tap(segment('genre:Drame'));
    await tester.pumpAndSettle();
    expect(focus('Drame', 8), findsOneWidget);
    final s = tester.widget<Semantics>(find
        .descendant(of: genre('genre:Drame'), matching: find.byType(Semantics))
        .first);
    expect(s.properties.selected, isTrue);
    await tester.ensureVisible(genre('rest'));
    await tester.tap(genre('rest'));
    await tester.pumpAndSettle();
    expect(focus('Autres', 37), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'un second appui rejoue ; les appuis rapides gardent le dernier choix',
      (tester) async {
    addTearDown(tester.view.reset);
    await host(tester);
    final transform =
        find.byKey(const ValueKey('pellicule-transform-genre:Comédie'));
    final initial = tester.widget<Transform>(transform).transform.clone();
    await tester.tap(segment('genre:Comédie'));
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.widget<Transform>(transform).transform, isNot(initial));
    await tester.tap(segment('genre:Drame'));
    await tester.pump(const Duration(milliseconds: 70));
    await tester.tap(segment('genre:Action'));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(segment('rest'));
    await tester.pumpAndSettle();
    expect(focus('Autres', 37), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
  testWidgets('réduction du mouvement : résultat immédiat sans ticker',
      (tester) async {
    addTearDown(tester.view.reset);
    await host(tester, reduced: true);
    await tester.tap(segment('genre:Drame'));
    await tester.pump();
    expect(focus('Drame', 8), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.tap(segment('genre:Drame'));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
  testWidgets('petit écran, grands textes, genres longs et parts minuscules',
      (tester) async {
    addTearDown(tester.view.reset);
    await host(tester,
        width: 320,
        scale: 2,
        data: pelliculeFixture(genres: const [
          GenreSlice('Documentaire historique et scientifique', 99.99),
          GenreSlice('Mystère', .01)
        ]));
    await tester.ensureVisible(genre('genre:Mystère'));
    await tester.tap(genre('genre:Mystère'));
    await tester.pumpAndSettle();
    expect(focus('Mystère', 0), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(genre('genre:Mystère')).height,
        greaterThanOrEqualTo(54));
  });
  testWidgets('vide, zéro, données invalides et disparition du genre actif',
      (tester) async {
    addTearDown(tester.view.reset);
    await host(tester);
    await tester.tap(segment('rest'));
    await tester.pump();
    await host(tester,
        data: pelliculeFixture(genres: const [GenreSlice('Animation', 1)]));
    expect(focus('Animation', 100), findsOneWidget);
    await host(tester,
        data: pelliculeFixture(genres: const [
          GenreSlice('Inconnu', 0),
          GenreSlice('Erreur', double.nan)
        ]));
    expect(find.byKey(const ValueKey('pellicule-empty')), findsOneWidget);
    expect(find.text('100 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'les largeurs conservent les poids et les arrondis totalisent 100',
      (tester) async {
    addTearDown(tester.view.reset);
    final u = pelliculeFixture(genres: const [
      GenreSlice('A', 1),
      GenreSlice('B', 1),
      GenreSlice('C', 1)
    ]);
    await host(tester, data: u);
    expect(tester.getSize(segment('genre:A')).width,
        closeTo(tester.getSize(segment('genre:B')).width, .001));
    expect(focus('A', 34), findsOneWidget);
    await tester.tap(segment('genre:B'));
    await tester.pumpAndSettle();
    expect(focus('B', 33), findsOneWidget);
    expect(u.totalGenreWeight, 3);
    expect(u.genres.first.weight, 1);
  });
}
