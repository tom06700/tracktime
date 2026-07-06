import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tracktime/db/database.dart';
import 'package:tracktime/main.dart';
import 'package:tracktime/providers.dart';

void main() {
  testWidgets('affiche la coquille avec les 4 onglets', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TrackTimeApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Séries'), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.textContaining('Aucune série'), findsOneWidget);

    // Démonte l'arbre puis avance l'horloge simulée pour déclencher les
    // timers de fermeture des streams drift, sinon le framework de test
    // les signale comme fuites.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
