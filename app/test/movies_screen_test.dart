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

/// Démonte l'arbre puis avance l'horloge : sans ça, les timers de fermeture
/// des streams drift restent en attente et sont signalés comme fuite.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _mount(WidgetTester tester, AppDatabase db, {Widget? child}) async {
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
    (_) async => http.Response('{"data":{"token":"t"},"status":"success"}', 200),
  ),
);

void main() {
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

    expect(find.text('Aucun film dans ta liste'), findsOneWidget);

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

    // Ciblage par icône plutôt que par label sémantique : find.bySemanticsLabel
    // exige d'activer l'arbre sémantique, que ce test n'a pas besoin d'ouvrir.
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    // Le bouton attend 220 ms avant d'écrire. Ce délai vit dans l'horloge
    // simulée : seul pump(Duration) le fait avancer — runAsync, qui bascule sur
    // l'horloge réelle, laisserait le timer en suspens.
    await tester.pump(const Duration(milliseconds: 300));
    // Puis du temps réel : l'écriture drift ne dépend pas de l'horloge simulée.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );

    final movies = await db.allMovies();
    expect(movies.single.watchedAt, isNotNull);

    // Le film quitte la collection et bascule vers la page des films vus.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
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

      expect(groups.map((g) => g.label), [
        'septembre 2026',
        'décembre 2026',
      ]);
      // Chronologique à l'intérieur d'un mois.
      expect(groups.first.movies.map((m) => m.movie.title), ['A', 'B']);
    });

    test('une liste vide ne produit aucun groupe', () {
      expect(groupReleasesByMonth([]), isEmpty);
    });
  });
}
