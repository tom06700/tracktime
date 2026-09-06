import 'package:go_router/go_router.dart';
import 'package:tracktime/brand/nitrate_brand.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/screens/shows_screen.dart';
import 'package:tracktime/series/feed.dart';
import 'package:tracktime/theme.dart';

/// Monte l'écran Séries sur une base en mémoire, sans réseau : le fil se
/// recompose depuis la base comme dans l'app.
Future<AppDatabase> _pump(WidgetTester tester,
    {bool seed = true, int otherShows = 0, GoRouter? router}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await db.close();
  });

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

  for (var i = 0; i < otherShows; i++) {
    final id = 100 + i;
    await db.upsertShow(ShowsCompanion.insert(id: Value(id), name: 'Série $i'));
    await db.upsertEpisodes([
      EpisodesCompanion.insert(
        showId: id,
        season: 1,
        episode: 1,
        airDate: Value(DateTime.now().subtract(const Duration(days: 1))),
      )
    ]);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(_silentTvdb()),
      ],
      child: router == null
          ? MaterialApp(
              theme: buildTheme(), home: const Scaffold(body: ShowsScreen()))
          : MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return db;
}

/// Démonte l'arbre puis avance l'horloge simulée : sans ça, les timers de
/// fermeture des streams drift restent en attente et le framework de test les
/// signale comme fuite.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Client TheTVDB muet : les écrans déclenchent une synchro au montage, et son
/// échec réseau lèverait une erreur asynchrone non gérée en plein test.
TvdbClient _silentTvdb() => TvdbClient(
      'test',
      client: MockClient(
        (_) async =>
            http.Response('{"data":{"token":"t"},"status":"success"}', 200),
      ),
    );

void main() {
  testWidgets('toute la carte ouvre l’épisode, marquer vu reste indépendant',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, state) => const Scaffold(body: ShowsScreen())),
      GoRoute(
          path: '/episode/:id/:season/:episode',
          builder: (_, state) => Scaffold(
              body: Text('Épisode ouvert ${state.pathParameters['episode']}'))),
    ]);
    addTearDown(router.dispose);
    final db = await _pump(tester, router: router);
    try {
      final card = find.byKey(const ValueKey('continue-watching-open'));
      for (final area in ['image', 'titre', 'espace']) {
        await Scrollable.ensureVisible(tester.element(card), alignment: .1);
        await tester.pumpAndSettle();
        final rect = tester.getRect(card);
        if (area == 'titre') {
          await tester.tap(find.text('Severance'));
        } else {
          await tester.tapAt(area == 'image'
              ? rect.topCenter + const Offset(0, 30)
              : rect.bottomCenter - const Offset(0, 5));
        }
        await tester.pumpAndSettle();
        expect(find.text('Épisode ouvert 4'), findsOneWidget);
        expect((await tester.runAsync(db.allWatchedEpisodes))!, isEmpty);
        router.pop();
        await tester.pumpAndSettle();
      }
      final command = find.text('Marquer vu');
      await Scrollable.ensureVisible(tester.element(command), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(command);
      await tester.runAsync(db.allWatchedEpisodes);
      await tester.pump();
      // A second tap during the confirmation must not bubble to the card.
      await tester.tapAt(tester.getCenter(find.text('Vu !')));
      await tester.pump(const Duration(seconds: 2));
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect((await tester.runAsync(db.allWatchedEpisodes))!.length, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await _settle(tester);
    }
  });
  testWidgets('À venir remplace la carte, retour À voir la rétablit',
      (tester) async {
    await _pump(tester);
    expect(find.text('Severance'), findsOneWidget);
    await tester.tap(find.text('À venir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Severance'), findsNothing);
    await tester.tap(find.text('À voir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Severance'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('le haut de page défile avec la carte au lieu de la découper',
      (tester) async {
    tester.view.physicalSize = const Size(390, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, otherShows: 3);
    final before = tester.getTopLeft(find.byType(NitrateWordmark)).dy;
    await tester.drag(find.byKey(const PageStorageKey('to-watch-feed')),
        const Offset(0, -260));
    await tester.pump(const Duration(seconds: 1));
    expect(
        tester.getTopLeft(find.byType(NitrateWordmark, skipOffstage: false)).dy,
        lessThan(before));
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

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

    await tester.ensureVisible(find.text('Explorer les séries'));
    await tester.tap(find.text('Explorer les séries'));
    await tester.pump();

    // Le CTA bascule l'onglet de la coquille au lieu d'empiler un écran.
    expect(captured.read(homeTabProvider), HomeTab.explorer);
    await _settle(tester);
  });

  testWidgets('accueil lisible sur petit écran avec texte agrandi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester);
    await tester.ensureVisible(find.text('Marquer vu'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _settle(tester);
  });

  testWidgets('le prochain épisode devient le héros', (tester) async {
    await _pump(tester);

    expect(find.text('Severance'), findsOneWidget);
    expect(find.textContaining('S02 · E04'), findsWidgets);
    expect(find.text('Marquer vu'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('marquer comme vu enregistre puis passe au suivant', (
    tester,
  ) async {
    final db = await _pump(tester);

    await tester.ensureVisible(find.text('Marquer vu'));
    await tester.pump();
    expect(find.text('Marquer vu').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Marquer vu'));
    await tester.pump();

    // La base en mémoire peut terminer pendant pump ; le test de commande
    // contrôle séparément l’absence de succès avant la fin d’une écriture.
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final watched = (await tester.runAsync(db.allWatchedEpisodes))!;
    expect(watched, hasLength(1));
    expect(watched.single.season, 2);
    expect(watched.single.episode, 4);

    // Laisser la confirmation se terminer après la lecture effective de la base.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('S02 · E05'), findsWidgets);
    await _settle(tester);
  }, timeout: const Timeout(Duration(seconds: 45)));

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
        // 3 jours : tombe dans « Cette semaine » quelle que soit l'heure du
        // run, là où « +1 jour » basculait de tranche selon l'heure.
        airDate: Value(DateTime.now().add(const Duration(days: 3))),
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

    expect(find.text('Cette semaine'), findsOneWidget);
    expect(find.text('The Last of Us'), findsOneWidget);
    await _settle(tester);
  });

  group('groupUpcoming', () {
    UpcomingEpisode ep(Show show, DateTime air) =>
        UpcomingEpisode(show: show, season: 1, episode: 1, airDate: air);

    test('répartit par proximité et omet les tranches vides', () {
      final now = DateTime(2026, 5, 10, 12);
      final show = Show(id: 1, name: 'X', runtime: 42, addedAt: now);

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
