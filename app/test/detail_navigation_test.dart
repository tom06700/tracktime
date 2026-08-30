import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/explorer_screen.dart';
import 'package:tracktime/screens/movie_detail_screen.dart';
import 'package:tracktime/screens/show_detail_screen.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Compte les appels par chemin, pour vérifier ce que l'app demande vraiment.
class _Api {
  final List<String> calls = [];

  TvdbClient client({
    Map<String, Object?> series = const {},
    List<(int, int)> episodes = const [],
  }) => TvdbClient(
    'test',
    client: MockClient((req) async {
      final path = req.url.path;
      calls.add(path);
      Object? body;
      if (path.endsWith('/login')) {
        return http.Response('{"data":{"token":"t"},"status":"success"}', 200);
      } else if (path.contains('/series/') && path.endsWith('/extended')) {
        body = series;
      } else if (path.contains('/episodes/')) {
        final page = int.tryParse(req.url.queryParameters['page'] ?? '0');
        body = {
          'episodes': page != 0
              ? const []
              : [
                  for (final (s, n) in episodes)
                    {'seasonNumber': s, 'number': n, 'name': 'S${s}E$n'},
                ],
        };
      } else if (path.contains('/movies/') && path.endsWith('/extended')) {
        body = {
          'name': 'Dune',
          'runtime': 155,
          'first_release': {'date': '2021-09-15'},
          'genres': [
            {'name': 'Science-Fiction'},
          ],
        };
      } else {
        body = <String, Object?>{};
      }
      return http.Response(
        jsonEncode({'data': body}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  int countContaining(String fragment) =>
      calls.where((c) => c.contains(fragment)).length;
}

final _onePiece = <String, Object?>{
  'name': 'ワンピース',
  'overview': 'Luffy prend la mer.',
  'firstAired': '1999-10-20',
  'status': {'name': 'Continuing'},
  'genres': [
    {'name': 'Animation'},
  ],
  'seasons': [
    {
      'number': 1,
      'type': {'type': 'official'},
    },
  ],
};

Future<void> _pump(
  WidgetTester tester,
  AppDatabase db,
  TvdbClient tvdb,
  Widget home,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(tvdb),
      ],
      child: MaterialApp(theme: buildTheme(), home: home),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Base de test avec les clés étrangères actives, comme sur l'appareil.
AppDatabase _fkDb() => AppDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
  ),
);

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await _frames(tester);
}

/// Ouvre l'onglet Épisodes puis déplie la saison 1, seul moment où les
/// contrôles de progression deviennent atteignables.
Future<void> _openSeason(WidgetTester tester) async {
  await _tapAndSettle(tester, find.text('Épisodes'));
  await _tapAndSettle(tester, find.text('Saison 1'));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('la fiche série s\'ouvre sans que la série soit suivie', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _Api();

    await _pump(
      tester,
      db,
      api.client(series: _onePiece),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'),
    );

    // Titre traduit, titre d'origine visible, et l'invitation à ajouter.
    expect(find.text('Luffy prend la mer.'), findsOneWidget);
    expect(find.text('Ajouter à ma liste'), findsOneWidget);
    expect(find.text('Dans ma liste'), findsNothing);

    await _settle(tester);
  });

  testWidgets(
    'ouvrir une fiche non suivie ne télécharge pas les épisodes',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      // Le point de cette PR : la liste des épisodes est paginée et énorme
      // pour One Piece ; elle ne doit pas partir pour un simple aperçu.
      expect(api.countContaining('/extended'), 1);
      expect(api.countContaining('/episodes/'), 0);

      await _settle(tester);
    },
  );

  testWidgets('une série déjà suivie affiche son appartenance', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(81797), name: 'One Piece'),
    );
    final api = _Api();

    await _pump(
      tester,
      db,
      api.client(series: _onePiece),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'),
    );

    expect(find.text('Dans ma liste'), findsOneWidget);
    expect(find.text('Ajouter à ma liste'), findsNothing);

    await _settle(tester);
  });

  testWidgets(
    'consulter les épisodes d\'une série non suivie n\'écrit rien en base',
    (tester) async {
      // Clés étrangères actives, comme sur l'appareil : écrire un épisode
      // rattaché à une série absente doit être impossible, pas silencieux.
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      await tester.tap(find.text('Épisodes'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(tester.takeException(), isNull);
      expect(await db.select(db.episodes).get(), isEmpty);
      expect(await db.showById(81797), isNull);

      await _settle(tester);
    },
  );

  testWidgets(
    'ajouter la série persiste les épisodes déjà consultés',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
        ),
      );
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      // On regarde les épisodes AVANT d'ajouter : rien n'est écrit.
      await tester.tap(find.text('Épisodes'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(await db.select(db.episodes).get(), isEmpty);

      // Puis on ajoute : le cache d'épisodes doit rattraper son retard.
      await tester.tap(find.text('À propos'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.text('Ajouter à ma liste'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(await db.showById(81797), isNotNull);
      expect(await db.select(db.episodes).get(), hasLength(2));

      await _settle(tester);
    },
  );

  testWidgets(
    'cocher un épisode d\'une série non suivie ne l\'ajoute pas',
    (tester) async {
      final db = _fkDb();
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      await _openSeason(tester);
      await _tapAndSettle(tester, find.textContaining('1. S1E1'));

      // Rien n'est entré dans la bibliothèque, et l'utilisateur sait pourquoi.
      expect(await db.showById(81797), isNull);
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
      expect(await db.select(db.episodes).get(), isEmpty);
      expect(
        find.textContaining('Ajoute d\'abord cette série'),
        findsOneWidget,
      );

      await _settle(tester);
    },
  );

  testWidgets(
    'cocher une saison entière d\'une série non suivie ne l\'ajoute pas',
    (tester) async {
      final db = _fkDb();
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      await _openSeason(tester);
      await _tapAndSettle(tester, find.byIcon(Icons.done_all));

      expect(await db.showById(81797), isNull);
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
      expect(
        find.textContaining('Ajoute d\'abord cette série'),
        findsOneWidget,
      );

      await _settle(tester);
    },
  );

  testWidgets(
    'une fois la série ajoutée, les coches fonctionnent',
    (tester) async {
      final db = _fkDb();
      addTearDown(db.close);
      final api = _Api();

      await _pump(
        tester,
        db,
        api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
        const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      );

      await _tapAndSettle(tester, find.text('Ajouter à ma liste'));
      expect(await db.showById(81797), isNotNull);

      await _openSeason(tester);
      await _tapAndSettle(tester, find.textContaining('1. S1E1'));

      final watched = await db.select(db.watchedEpisodes).get();
      expect(watched.map((w) => 'S${w.season}E${w.episode}'), ['S1E1']);

      // Et la saison entière passe elle aussi.
      await _tapAndSettle(tester, find.byIcon(Icons.done_all));
      final all = await db.select(db.watchedEpisodes).get();
      expect(all, hasLength(2));

      await _settle(tester);
    },
  );

  testWidgets('la fiche film charge ses détails depuis TheTVDB', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _Api();

    await _pump(
      tester,
      db,
      api.client(),
      const MovieDetailScreen(movieId: 1406, title: 'Dune'),
    );

    expect(find.text('Dune'), findsOneWidget);
    // Durée formatée, pas « 155 min ».
    expect(find.textContaining('2 h 35'), findsOneWidget);
    expect(find.text('Ajouter à ma liste'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('un film déjà dans la liste ne propose plus de l\'ajouter', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(1406), title: 'Dune'),
    );
    final api = _Api();

    await _pump(
      tester,
      db,
      api.client(),
      const MovieDetailScreen(movieId: 1406, title: 'Dune'),
    );

    expect(find.text('Dans ma liste'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('openMediaDetail route selon le type, par identifiant', (
    tester,
  ) async {
    final pushed = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => openMediaDetail(
                    context,
                    id: 81797,
                    isSeries: true,
                    title: 'One Piece',
                  ),
                  child: const Text('série'),
                ),
                TextButton(
                  onPressed: () => openMediaDetail(
                    context,
                    id: 1406,
                    isSeries: false,
                    title: 'Dune',
                  ),
                  child: const Text('film'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/show/:id',
          builder: (_, state) {
            pushed.add('/show/${state.pathParameters['id']}');
            return const Scaffold();
          },
        ),
        GoRoute(
          path: '/movie/:id',
          builder: (_, state) {
            pushed.add('/movie/${state.pathParameters['id']}');
            return const Scaffold();
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('série'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(pushed, ['/show/81797']);
  });
}
