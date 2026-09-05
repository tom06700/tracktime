import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/widgets/async_icon_button.dart';

void main() {
  testWidgets(
      'un seul enregistrement, erreur visible et possibilité de réessayer',
      (tester) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AsyncIconButton(
      icon: const Icon(Icons.undo),
      tooltip: 'Annuler vu',
      onPressed: () {
        calls++;
        return completion.future;
      },
    ))));
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    await tester.tap(find.byType(IconButton));
    expect(calls, 1);
    completion.completeError(StateError('storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Impossible d’enregistrer la modification. Réessaie.'),
        findsOneWidget);
    expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });
}
