import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/series/widgets/episode_number_picker.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/series/widgets/episode_number_ruler.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ValueChanged<int?> result, {
    double scale = 1,
    double keyboard = 0,
    bool reduced = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result(
                await showEpisodeNumberPicker(
                  context: context,
                  season: 0,
                  numbers: const [3, 5, 1236],
                  names: const {3: 'Le départ', 5: 'Une nouvelle aventure'},
                ),
              ),
              child: const Text('Choisir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
  }

  testWidgets('numéros officiels : limites, trous, aperçu et confirmation', (
    tester,
  ) async {
    int? result;
    await open(tester, (n) => result = n);
    expect(find.text('Spéciaux · 3 épisodes'), findsOneWidget);
    expect(find.text('Le départ'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Épisode précédent',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Épisode suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Une nouvelle aventure'), findsOneWidget);
    expect(result, isNull);
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Ouvrir la fiche'));
    await tester.pumpAndSettle();
    expect(
      find.text('Ce numéro n’existe pas dans cette saison.'),
      findsOneWidget,
    );
    expect(result, isNull);
    await tester.enterText(find.byType(TextField), '1236');
    await tester.pumpAndSettle();
    expect(
      find.text('Ce numéro n’existe pas dans cette saison.'),
      findsNothing,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Épisode suivant',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Ouvrir la fiche'));
    await tester.pumpAndSettle();
    expect(result, 1236);
    expect(tester.takeException(), isNull);
  });

  testWidgets('réglette : glisser parmi les numéros officiels puis ouvrir', (
    tester,
  ) async {
    int? result;
    await open(tester, (n) => result = n, reduced: false);
    final ruler = find.byKey(const ValueKey('episode-number-ruler'));
    expect(ruler, findsOneWidget);
    await tester.timedDrag(
      ruler,
      const Offset(-100, 0),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(['5', '1236'], contains(field.controller!.text));
    final number = int.parse(field.controller!.text);
    await tester.tap(find.text('Ouvrir la fiche'));
    await tester.pumpAndSettle();
    expect(result, number);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appuis rapprochés : dernier numéro correct et bouton stable', (
    tester,
  ) async {
    await open(tester, (_) {}, reduced: false);
    final before = tester.getTopLeft(find.text('Ouvrir la fiche'));
    await tester.tap(find.byTooltip('Épisode suivant'));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byTooltip('Épisode suivant'));
    await tester.pump(const Duration(milliseconds: 45));
    await tester.tap(find.byTooltip('Épisode précédent'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '5',
    );
    expect(
      tester.getTopLeft(find.text('Ouvrir la fiche')).dy,
      closeTo(before.dy, 1),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Annuler'));
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'longue saison : réglette paresseuse et remise en position après saisie',
    (tester) async {
      var selected = 1;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: StatefulBuilder(
                  builder: (context, update) {
                    change = update;
                    return EpisodeNumberRuler(
                      numbers: List.generate(1236, (i) => i + 1),
                      selected: selected,
                      onChanged: (n) => update(() => selected = n),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Text).evaluate().length, lessThan(30));
      change(() => selected = 1236);
      await tester.pumpAndSettle();
      expect(find.text('1236').hitTestable(), findsOneWidget);
      expect(selected, 1236);
      expect(find.byType(Text).evaluate().length, lessThan(30));
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Choisir un épisode en glissant'),
        findsOneWidget,
      );
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tirer la poignée ferme sans sélectionner un épisode', (
    tester,
  ) async {
    var completed = false;
    int? result;
    await open(tester, (n) {
      completed = true;
      result = n;
    }, reduced: false);
    final top = tester.getTopLeft(find.byType(BottomSheet));
    await tester.timedDragFrom(
      top + const Offset(200, 22),
      const Offset(0, 480),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'petit écran, clavier et texte doublé : action et annulation accessibles',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      int? result;
      await open(tester, (n) => result = n, scale: 2, keyboard: 300);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Ouvrir la fiche'));
      await tester.pumpAndSettle();
      expect(find.text('Ouvrir la fiche').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Annuler'));
      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
