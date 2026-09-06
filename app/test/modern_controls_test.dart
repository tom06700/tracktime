import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/widgets/modern_controls.dart';

void main() {
  Widget host(Widget child,
          {double scale = 1, bool reduce = false}) =>
      MaterialApp(
          theme: buildTheme(),
          home: MediaQuery(
              data:
                  MediaQueryData(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: reduce),
              child: Scaffold(
                  body: Center(child: SizedBox(width: 280, child: child)))));

  testWidgets(
      'une commande attend la vraie sauvegarde et bloque le double appui',
      (tester) async {
    final save = Completer<void>();
    var writes = 0;
    await tester.pumpWidget(host(ModernCommand(
        shape: CommandShape.softCheck,
        label: 'Marquer vu',
        onPressed: () {
          writes++;
          return save.future;
        })));
    await tester.tap(find.text('Marquer vu'));
    await tester.pump();
    await tester.tap(find.text('Marquer vu'));
    expect(writes, 1);
    expect(tester.widget<ModernCommand>(find.byType(ModernCommand)).selected,
        isFalse);
    save.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('erreur visible et commande réessayable sans faux état confirmé',
      (tester) async {
    var tries = 0;
    await tester.pumpWidget(host(ModernCommand(
        shape: CommandShape.attach,
        label: 'Ma liste',
        onPressed: () async {
          tries++;
          throw StateError('failed');
        })));
    await tester.tap(find.text('Ma liste'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible d’enregistrer. Réessaie.'), findsOneWidget);
    expect(tester.widget<ModernCommand>(find.byType(ModernCommand)).selected,
        isFalse);
    await tester.tap(find.text('Ma liste'));
    await tester.pumpAndSettle();
    expect(tries, 2);
  });

  testWidgets('quitter pendant next up ne déclenche pas une navigation tardive',
      (tester) async {
    var opened = 0;
    await tester.pumpWidget(host(ModernCommand(
        shape: CommandShape.nextUp,
        label: 'Ouvrir',
        onPressed: () => opened++)));
    await tester.tap(find.text('Ouvrir'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(opened, 0);
  });

  testWidgets('familles à texte agrandi et mouvement réduit', (tester) async {
    for (final shape in CommandShape.values) {
      await tester.pumpWidget(host(
          ModernCommand(
              shape: shape, label: 'Une commande longue', onPressed: () {}),
          scale: 2,
          reduce: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Une commande longue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
