import 'package:tracktime/widgets/watched_check.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/movies/feed.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/tmdb/tvdb.dart';
import 'package:tracktime/screens/movies_screen.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/movies/widgets/movie_poster_card.dart';

/// Démonte l'arbre puis avance l'horloge : sans ça, les timers de fermeture
/// des streams drift restent en attente et sont signalés comme fuite.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _mount(
  WidgetTester tester,
  AppDatabase db, {
  Widget? child,
}) async {
  // Surface d'iPhone : la surface de test par défaut (800×600) donnerait des
  // cellules de grille démesurées, poussant les boutons hors de l'écran.
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(_silentTvdb()),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: child ?? const MoviesScreen()),
      ),
    ),
  );
  // Plusieurs pompes : les flux drift émettent de façon asynchrone, une seule
  // ne suffit pas pour que la base ait alimenté les providers.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
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
  testWidgets(
    'la grille compacte passe à trois colonnes et garde les actions',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (var i = 0; i < 6; i++) {
        await db.upsertMovie(
          MoviesCompanion.insert(id: Value(i + 1), title: 'Film $i'),
        );
      }
      await _mount(tester, db);
      final wide = tester.getSize(find.byType(MoviePosterCard).first).width;
      await tester.tap(find.byTooltip('Vue d’ensemble'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      final cards = find.byType(MoviePosterCard);
      expect(tester.getSize(cards.first).width, lessThan(wide));
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(2)).dy,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Grandes affiches'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(tester.getSize(cards.first).width, wide);
      await _settle(tester);
    },
  );

  testWidgets('une liste vide propose d\'aller explorer', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    late WidgetRef captured;
    await _mount(
      tester,
      db,
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const MoviesScreen();
        },
      ),
    );

    expect(find.text('Ton prochain film t’attend.'), findsOneWidget);
    expect(find.bySemanticsLabel('Traverser la porte vers Explorer'), findsOneWidget);

    await tester.tap(find.text('Explorer les films'));
    await tester.pump();
    expect(captured.read(homeTabProvider), HomeTab.explorer);

    await _settle(tester);
  });

  testWidgets('les films à voir remplissent la grille', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(1), title: 'Dune'),
    );
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(2), title: 'Arrival'),
    );

    await _mount(tester, db);

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Arrival'), findsOneWidget);
    // Aucun film vu : pas de lien vers la page dédiée.
    expect(find.textContaining('Films vus'), findsNothing);

    await _settle(tester);
  });

  testWidgets('marquer vu retire le film de la grille', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(1), title: 'Dune'),
    );

    await _mount(tester, db);
    expect(find.text('Dune'), findsOneWidget);

    await tester.tap(find.text('Vu'));
    await tester.pump();
    // L’écriture démarre immédiatement, sans délai d’animation préalable.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );

    final movies = await db.allMovies();
    expect(movies.single.watchedAt, isNotNull);

    // La carte reste en place pour la coche, puis rejoint l’historique.
    await tester.pump();
    expect(find.text('Dune'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is WatchedCheck && w.confirmed),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Dune'), findsNothing);
    expect(find.textContaining('Films vus'), findsOneWidget);

    await _settle(tester);
  });

  group('groupReleasesByMonth', () {
    UpcomingMovie rel(String title, DateTime date) => UpcomingMovie(
      movie: Movie(
        id: title.hashCode,
        title: title,
        runtime: 110,
        addedAt: DateTime(2026),
      ),
      releaseDate: date,
    );

    test('regroupe par mois, du plus proche au plus lointain', () {
      final groups = groupReleasesByMonth([
        rel('C', DateTime(2026, 12, 18)),
        rel('A', DateTime(2026, 9, 3)),
        rel('B', DateTime(2026, 9, 24)),
      ]);

      expect(groups.map((g) => g.label), ['septembre 2026', 'décembre 2026']);
      // Chronologique à l'intérieur d'un mois.
      expect(groups.first.movies.map((m) => m.movie.title), ['A', 'B']);
    });

    test('une liste vide ne produit aucun groupe', () {
      expect(groupReleasesByMonth([]), isEmpty);
    });
  });
}
