import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/movie_history_screen.dart';
import 'package:tracktime/screens/movie_detail_screen.dart';
import 'package:tracktime/tmdb/media_detail.dart';
import 'package:tracktime/theme.dart';

Future<void> mount(WidgetTester t, AppDatabase db, Widget screen) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        movieDetailProvider(42).overrideWith(
          (ref) async =>
              const MovieDetail(id: 42, title: 'Dune', genres: [], cast: []),
        ),
      ],
      child: MaterialApp(theme: buildTheme(), home: screen),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> cleanup(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('history offers restoration and a confirmed removal', (t) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(
        id: const Value(42),
        title: 'Dune',
        watchedAt: Value(DateTime(2026, 9, 8)),
      ),
    );
    await mount(t, db, const MovieHistoryScreen());
    await t.tap(find.byTooltip('Actions pour Dune'));
    await t.pumpAndSettle();
    expect(find.text('Remettre à voir'), findsOneWidget);
    await t.tap(find.text('Retirer de ma liste'));
    await t.pumpAndSettle();
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(await db.movieById(42), isNotNull);
    await t.tap(find.byTooltip('Actions pour Dune'));
    await t.pumpAndSettle();
    await t.tap(find.text('Remettre à voir'));
    await t.pumpAndSettle();
    expect((await db.movieById(42))!.watchedAt, isNull);
    await cleanup(t);
  });
  testWidgets('film detail shares the menu and refreshes the seen action', (
    t,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(42), title: 'Dune'),
    );
    await mount(t, db, const MovieDetailScreen(movieId: 42));
    await t.tap(find.byTooltip('Actions pour Dune'));
    await t.pumpAndSettle();
    await t.tap(find.text('Marquer comme vu'));
    await t.pumpAndSettle();
    expect((await db.movieById(42))!.watchedAt, isNotNull);
    await t.tap(find.byTooltip('Actions pour Dune'));
    await t.pumpAndSettle();
    expect(find.text('Remettre à voir'), findsOneWidget);
    await t.tap(find.text('Retirer de ma liste'));
    await t.pumpAndSettle();
    await t.tap(find.text('Retirer'));
    await t.pumpAndSettle();
    expect(await db.movieById(42), isNull);
    expect(find.byTooltip('Ajouter à ma liste'), findsOneWidget);
    await cleanup(t);
  });
}
