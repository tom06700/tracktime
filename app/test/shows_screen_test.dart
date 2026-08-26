import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/shows_screen.dart';
import 'package:tracktime/series/feed.dart';
import 'package:tracktime/theme.dart';

/// Monte l'écran Séries sur une base en mémoire, sans réseau : le fil se
/// recompose depuis la base comme dans l'app.
Future<AppDatabase> _pump(WidgetTester tester, {bool seed = true}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);

  if (seed) {
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(1), name: 'Severance'),
    );
    await db.upsertEpisodes([
      EpisodesCompanion.insert(
        showId: 1,
        season: 2,
        episode: 4,
        name: const Value("Woe's Hollow"),
        airDate: Value(DateTime.now().subtract(const Duration(days: 30))),
      ),
      EpisodesCompanion.insert(
        showId: 1,
        season: 2,
        episode: 5,
        name: const Value('Trojan\'s Horse'),
        airDate: Value(DateTime.now().subtract(const Duration(days: 23))),
      ),
    ]);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: ShowsScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return db;
}

void main() {
  testWidgets('une liste vide propose d\'aller explorer', (tester) async {
    late WidgetRef captured;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                captured = ref;
                return const ShowsScreen();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ta liste est vide'), findsOneWidget);
    expect(captured.read(homeTabProvider), HomeTab.series);

    await tester.tap(find.text('Explorer les séries'));
    await tester.pump();

    // Le CTA bascule l'onglet de la coquille au lieu d'empiler un écran.
    expect(captured.read(homeTabProvider), HomeTab.explorer);
  });

  testWidgets('le prochain épisode devient le héros', (tester) async {
    await _pump(tester);

    expect(find.text('Severance'), findsOneWidget);
    expect(find.textContaining('S02 | E04'), findsWidgets);
    expect(find.text('Marquer comme vu'), findsOneWidget);
  });

  testWidgets('marquer comme vu enregistre puis passe au suivant', (
    tester,
  ) async {
    final db = await _pump(tester);

    await tester.tap(find.text('Marquer comme vu'));
    await tester.pump();

    // Confirmation immédiate, avant même l'écriture.
    expect(find.text('Vu'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    final watched = await db.allWatchedEpisodes();
    expect(watched, hasLength(1));
    expect(watched.single.season, 2);
    expect(watched.single.episode, 4);

    // Le fil se recompose : l'épisode suivant prend la place du héros.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('S02 | E05'), findsWidgets);
  });

  testWidgets('l\'onglet À venir regroupe par échéance', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(2), name: 'The Last of Us'),
    );
    await db.upsertEpisodes([
      EpisodesCompanion.insert(
        showId: 2,
        season: 2,
        episode: 5,
        airDate: Value(DateTime.now().add(const Duration(days: 1, hours: 2))),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: ShowsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('À venir'));
    // Pas de pumpAndSettle : le battement des squelettes ne se termine jamais.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Demain'), findsOneWidget);
    expect(find.text('The Last of Us'), findsOneWidget);
  });

  group('groupUpcoming', () {
    UpcomingEpisode ep(Show show, DateTime air) => UpcomingEpisode(
      show: show,
      season: 1,
      episode: 1,
      airDate: air,
    );

    test('répartit par proximité et omet les tranches vides', () {
      final now = DateTime(2026, 5, 10, 12);
      final show = Show(
        id: 1,
        name: 'X',
        runtime: 42,
        addedAt: now,
      );

      final groups = groupUpcoming([
        ep(show, DateTime(2026, 5, 10, 21)),
        ep(show, DateTime(2026, 5, 11, 21)),
        ep(show, DateTime(2026, 5, 14, 21)),
        ep(show, DateTime(2026, 6, 20, 21)),
      ], now);

      expect(groups.map((g) => g.bucket), [
        UpcomingBucket.today,
        UpcomingBucket.tomorrow,
        UpcomingBucket.thisWeek,
        UpcomingBucket.later,
      ]);
    });

    test('ne produit que les tranches peuplées', () {
      final now = DateTime(2026, 5, 10, 12);
      final show = Show(id: 1, name: 'X', runtime: 42, addedAt: now);
      final groups = groupUpcoming([ep(show, DateTime(2026, 8, 1))], now);
      expect(groups, hasLength(1));
      expect(groups.single.bucket, UpcomingBucket.later);
    });
  });
}
