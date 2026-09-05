import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tracktime/db/database.dart';
import 'package:tracktime/main.dart';
import 'package:tracktime/widgets/nav_bar.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';

void main() {
  testWidgets('affiche la coquille avec les 4 onglets', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Client sans clé : il refuse de partir en réseau. Aucun test ne doit
        // dépendre du vrai TheTVDB.
        tvdbClientProvider.overrideWithValue(TvdbClient('')),
      ],
      child: const NitrateApp(),
    ));
    // Pas de pumpAndSettle : le battement des squelettes de chargement est
    // une animation sans fin, qui ferait attendre le test indéfiniment.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.descendant(of: find.byType(NitrateNavBar), matching: find.text('Séries')), findsOneWidget);
    expect(find.text('Films'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Ta liste est vide'), findsOneWidget);

    // Démonte l'arbre puis avance l'horloge simulée pour déclencher les
    // timers de fermeture des streams drift, sinon le framework de test
    // les signale comme fuites.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
