import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/settings_screen.dart';
import 'package:tracktime/theme.dart';

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  Future<void> Function(AppDatabase) onExport,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildTheme(),
        home: SettingsScreen(exportData: onExport),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('Réglages propose d\'exporter ses données', (tester) async {
    await _pump(tester, db, (_) async {});

    expect(find.text('Exporter mes données'), findsOneWidget);
    expect(
      find.text(
        'Crée une sauvegarde Nitrate de tes séries, films et visionnages',
      ),
      findsOneWidget,
    );
    // L'ordre du parcours : sauvegarder, restaurer, puis effacer.
    expect(find.text('DONNÉES'), findsOneWidget);
  });

  testWidgets('le tap lance l\'export sur la base courante', (tester) async {
    final calls = <AppDatabase>[];
    await _pump(tester, db, (d) async => calls.add(d));

    await tester.tap(find.text('Exporter mes données'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls, [db]);
  });

  testWidgets('un échec reste lisible, sans exception brute', (tester) async {
    await _pump(tester, db, (_) async => throw Exception('partage refusé'));

    await tester.tap(find.text('Exporter mes données'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(
      find.text('Impossible de créer la sauvegarde. Réessaie.'),
      findsOneWidget,
    );
  });

  testWidgets('un second tap ne relance pas un export en cours', (
    tester,
  ) async {
    var calls = 0;
    final gate = Completer<void>();
    await _pump(tester, db, (_) async {
      calls++;
      await gate.future;
    });

    await tester.tap(find.text('Exporter mes données'));
    await tester.pump();
    // Pendant l'attente, la ligne montre sa progression et n'est plus active.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Exporter mes données'), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
