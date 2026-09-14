import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/profile/sections.dart';
import 'package:tracktime/screens/series_library_screen.dart';
import 'package:tracktime/theme.dart';

void main() {
  testWidgets(
    'Récentes place un ajout non commencé avant une ancienne série regardée',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.upsertShow(
        ShowsCompanion.insert(
          id: const Value(1),
          name: 'Ancienne série',
          addedAt: Value(DateTime(2025, 1, 1)),
        ),
      );
      await db.setEpisodeWatched(1, 1, 1, at: DateTime(2026, 9, 13));
      await db.upsertShow(
        ShowsCompanion.insert(
          id: const Value(450633),
          name: 'Young Sherlock',
          addedAt: Value(DateTime(2026, 9, 14)),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: buildTheme(),
            home: const SeriesLibraryScreen(),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      final tiles = tester
          .widgetList<SeriesPosterTile>(find.byType(SeriesPosterTile))
          .toList();
      expect(tiles.map((t) => t.item.show.id), [450633, 1]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
