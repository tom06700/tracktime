import 'dart:async';
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
  }) =>
      TvdbClient(
        'test',
        client: MockClient((req) async {
          final path = req.url.path;
          calls.add(path);
          Object? body;
          if (path.endsWith('/login')) {
            return http.Response(
                '{"data":{"token":"t"},"status":"success"}', 200);
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
              'overview': 'Le voyage sur Arrakis.',
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
    WidgetTester tester, AppDatabase db, TvdbClient tvdb, Widget home,
    {Size size = const Size(390, 844), double scale = 1,
      bool disableAnimations = true}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(tvdb),
      ],
      child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: disableAnimations),
              child: child!),
          home: home),
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
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f);
  await _frames(tester, 2);
  await tester.tap(f);
  await _frames(tester);
}

/// Ouvre l'onglet Épisodes puis déplie la saison 1, seul moment où les
/// contrôles de progression deviennent atteignables.
Future<void> _openSeason(WidgetTester tester) async {
  await _tapAndSettle(tester, find.text('Épisodes'));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('terminer toute la saison conserve la saison affichée', (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    await db.upsertShow(ShowsCompanion.insert(id: const Value(81797), name: 'One Piece'));
    await _pump(tester, db, _Api().client(series: _onePiece,
      episodes: [(1, 1), (1, 2), (2, 1)]),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'));
    await _openSeason(tester);
    await _tapAndSettle(tester, find.text('Non vus'));
    await _tapAndSettle(tester, find.text('Tout marquer vu'));
    await _tapAndSettle(tester, find.text('Confirmer'));
    await _frames(tester, 15);
    expect(find.text('Saison terminée'), findsOneWidget);
    expect(find.text('Saison 1'), findsOneWidget);
    expect((await db.allWatchedEpisodes()).length, 2);
    await _settle(tester);
  });
  testWidgets('le dernier épisode se retire sans changer automatiquement de saison', (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    await db.upsertShow(ShowsCompanion.insert(id: const Value(81797), name: 'One Piece'));
    await _pump(tester, db, _Api().client(series: _onePiece,
      episodes: [(1, 1), (2, 1)]),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'),
      disableAnimations: false);
    await _openSeason(tester);
    await _tapAndSettle(tester, find.text('Non vus'));
    await _frames(tester, 18);
    await tester.ensureVisible(find.byKey(const ValueKey('series-episode-check-1')));
    await _frames(tester);
    await tester.tap(find.byKey(const ValueKey('series-episode-check-1')));
    await _frames(tester, 2);
    expect(find.text('S1E1'), findsOneWidget);
    await _frames(tester, 16);
    expect(find.text('S1E1'), findsNothing);
    expect(find.text('Saison terminée'), findsOneWidget);
    expect(find.text('Saison 1'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Saison suivante · 2'));
    await _frames(tester, 15);
    expect(find.text('S2E1').hitTestable(), findsOneWidget);
    final watched = await db.allWatchedEpisodes();
    expect(watched.length, 1);
    expect(watched.single.season, 1);
    await _settle(tester);
  });
  testWidgets('une saison terminée garde les filtres à la même place', (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    await db.upsertShow(ShowsCompanion.insert(id: const Value(81797), name: 'One Piece'));
    await _pump(tester, db, _Api().client(series: _onePiece,
      episodes: [for (var n = 1; n <= 20; n++) (1, n)]),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'));
    await db.setSeasonWatched(81797, 1, [for (var n = 1; n <= 20; n++) n], true);
    await _frames(tester);
    await _openSeason(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1000));
    await _frames(tester);
    final selector = find.byKey(const ValueKey('season-selector'));
    final before = tester.getTopLeft(selector).dy;
    await tester.tap(find.text('Non vus'));
    await _frames(tester, 15);
    expect(tester.getTopLeft(selector).dy, closeTo(before, 1));
    expect(find.text('Saison terminée'), findsOneWidget);
    expect(find.text('20 épisodes vus'), findsOneWidget);
    await tester.tap(find.text('Revoir les épisodes'));
    await _frames(tester);
    expect(find.text('S1E1').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(selector).dy, closeTo(before, 1));
    await _settle(tester);
  });
  testWidgets('le retour et le titre de série restent visibles après défilement', (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    await _pump(tester, db,
      _Api().client(series: _onePiece, episodes: [for (var n = 1; n <= 100; n++) (1, n), (2, 1), (2, 2)]),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'));
    await _openSeason(tester);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1100));
    await _frames(tester);
    expect(find.byTooltip('Retour').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('series-compact-title')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('season-selector')).hitTestable(), findsOneWidget);
    expect(find.text('Non vus').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Non vus'));
    await _frames(tester);
    expect(find.text('S1E1').hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('season-selector')));
    await _frames(tester);
    await tester.tap(find.text('Saison 2').last);
    await _frames(tester);
    expect(find.text('S2E1').hitTestable(), findsOneWidget);
    expect(find.text('Non vus').hitTestable(), findsOneWidget);
    expect(await db.allWatchedEpisodes(), isEmpty);
    await _settle(tester);
  });
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
    expect(find.text('Ma liste'), findsOneWidget);
    expect(find.text('Dans ma liste'), findsNothing);

    await _settle(tester);
  });

  testWidgets('ouvrir une fiche non suivie ne télécharge pas les épisodes', (
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

    // Le point de cette PR : la liste des épisodes est paginée et énorme
    // pour One Piece ; elle ne doit pas partir pour un simple aperçu.
    expect(api.countContaining('/extended'), 1);
    expect(api.countContaining('/episodes/'), 0);

    await _settle(tester);
  });

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

    expect(find.text('Explorer les épisodes'), findsOneWidget);
    expect(find.text('Ma liste'), findsNothing);

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

      await _tapAndSettle(tester, find.text('Épisodes'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(tester.takeException(), isNull);
      expect(await db.select(db.episodes).get(), isEmpty);
      expect(await db.showById(81797), isNull);

      await _settle(tester);
    },
  );

  testWidgets('ajouter la série persiste les épisodes déjà consultés', (
    tester,
  ) async {
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
    await _tapAndSettle(tester, find.text('Épisodes'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(await db.select(db.episodes).get(), isEmpty);

    // Puis on ajoute : le cache d'épisodes doit rattraper son retard.
    await _tapAndSettle(tester, find.text('À propos'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await _tapAndSettle(tester, find.text('Ma liste'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(await db.showById(81797), isNotNull);
    expect(await db.select(db.episodes).get(), hasLength(2));

    await _settle(tester);
  });

  testWidgets('cocher un épisode d\'une série non suivie ne l\'ajoute pas', (
    tester,
  ) async {
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
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('series-episode-check-1')),
    );

    // Rien n'est entré dans la bibliothèque, et l'utilisateur sait pourquoi.
    expect(await db.showById(81797), isNull);
    expect(await db.select(db.watchedEpisodes).get(), isEmpty);
    expect(await db.select(db.episodes).get(), isEmpty);
    expect(find.textContaining('Ajoute d\'abord cette série'), findsOneWidget);

    await _settle(tester);
  });

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
      await _tapAndSettle(tester, find.text('Tout marquer vu'));

      expect(await db.showById(81797), isNull);
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
      expect(
        find.textContaining('Ajoute d\'abord cette série'),
        findsOneWidget,
      );

      await _settle(tester);
    },
  );

  testWidgets('une fois la série ajoutée, les coches fonctionnent', (
    tester,
  ) async {
    final db = _fkDb();
    addTearDown(db.close);
    final api = _Api();

    await _pump(
      tester,
      db,
      api.client(series: _onePiece, episodes: const [(1, 1), (1, 2)]),
      const ShowDetailScreen(showId: 81797, title: 'One Piece'),
    );

    await _tapAndSettle(tester, find.text('Ma liste'));
    expect(await db.showById(81797), isNotNull);

    await _openSeason(tester);
    await _tapAndSettle(
      tester,
      find.byKey(const ValueKey('series-episode-check-1')),
    );

    final watched = await db.select(db.watchedEpisodes).get();
    expect(watched.map((w) => 'S${w.season}E${w.episode}'), ['S1E1']);

    // Et la saison entière passe elle aussi.
    await _tapAndSettle(tester, find.text('Tout marquer vu'));
    await _tapAndSettle(tester, find.text('Confirmer'));
    final all = await db.select(db.watchedEpisodes).get();
    expect(all, hasLength(2));

    await _settle(tester);
  });

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
    expect(find.bySemanticsLabel('Ajouter à ma liste'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('une fiche film qui échoue garde un bouton retour', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final tvdb = TvdbClient(
      'test',
      sleep: (_) async {},
      client: MockClient((req) async {
        if (req.url.path.endsWith('/login')) {
          return http.Response('{"data":{"token":"t"}}', 200);
        }
        return http.Response('nope', 404);
      }),
    );

    await _pump(
      tester,
      db,
      tvdb,
      const MovieDetailScreen(movieId: 1406, title: 'Dune'),
    );

    expect(find.text('Impossible de charger ce film'), findsOneWidget);
    // Sans la coquille cinématique, le retour doit quand même être là.
    expect(find.bySemanticsLabel('Retour'), findsOneWidget);

    await _settle(tester);
  });

  testWidgets('une fiche film en attente garde un bouton retour', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final never = Completer<http.Response>();
    final tvdb = TvdbClient(
      'test',
      client: MockClient((req) async {
        if (req.url.path.endsWith('/login')) {
          return http.Response('{"data":{"token":"t"}}', 200);
        }
        return never.future;
      }),
    );

    await _pump(
      tester,
      db,
      tvdb,
      const MovieDetailScreen(movieId: 1406, title: 'Dune'),
    );

    expect(find.byType(MediaDetailSkeleton), findsOneWidget);
    expect(find.bySemanticsLabel('Retour'), findsOneWidget);

    never.complete(http.Response('nope', 404));
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

    expect(find.text('Marquer vu'), findsOneWidget);
    expect(find.text('Ma liste'), findsNothing);

    await _settle(tester);
  });

  testWidgets(
      'saison longue : accès direct officiel, trous et spéciaux sans écriture',
      (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    final api = _Api();
    final opened = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, _) =>
              const ShowDetailScreen(showId: 81797, title: 'One Piece')),
      GoRoute(
          path: '/episode/:id/:season/:number',
          builder: (_, state) {
            opened.add(
                '${state.pathParameters['season']}/${state.pathParameters['number']}');
            return const Scaffold(body: Text('Fiche officielle'));
          }),
    ]);
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      tvdbClientProvider
          .overrideWithValue(api.client(series: _onePiece, episodes: [
        (0, 3),
        for (var n = 1; n <= 1236; n++)
          if (n != 1200) (1, n),
      ])),
    ], child: MaterialApp.router(theme: buildTheme(), routerConfig: router)));
    await _frames(tester);
    await _openSeason(tester);
    expect(find.byType(IconButton).evaluate().length, lessThan(25),
        reason: 'La longue saison reste virtualisée.');
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await _frames(tester);
    final positionBeforeEpisode = tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;
    expect(positionBeforeEpisode, greaterThan(1000));
    await tester.tap(find.byTooltip('Aller à un numéro'));
    await _frames(tester);
    await tester.enterText(find.byType(TextField), '1200');
    await _tapAndSettle(tester, find.text('Ouvrir la fiche'));
    expect(
        find.text('Ce numéro n’existe pas dans cette saison.'), findsOneWidget);
    expect(opened, isEmpty);
    await tester.enterText(find.byType(TextField), '1236');
    await _tapAndSettle(tester, find.text('Ouvrir la fiche'));
    await _frames(tester);
    expect(opened, ['1/1236']);
    expect(await db.showById(81797), isNull);
    expect(await db.allWatchedEpisodes(), isEmpty);
    router.pop();
    await _frames(tester);
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels,
        closeTo(positionBeforeEpisode, 1));
    expect(find.text('Saison 1').hitTestable(), findsOneWidget);
    await _tapAndSettle(tester, find.byKey(const ValueKey('season-selector')));
    await _tapAndSettle(tester, find.text('Spéciaux').last);
    await _tapAndSettle(tester, find.byTooltip('Aller à un numéro'));
    await tester.enterText(find.byType(TextField), '3');
    await _tapAndSettle(tester, find.text('Ouvrir la fiche'));
    await _frames(tester);
    expect(opened, ['1/1236', '0/3']);
    expect(await db.allWatchedEpisodes(), isEmpty);
    await _settle(tester);
  });

  for (final film in [false, true]) {
    testWidgets(
        'fiche ${film ? 'film' : 'série'} : petit écran et texte doublé',
        (tester) async {
      final db = _fkDb();
      addTearDown(db.close);
      final api = _Api();
      await _pump(
          tester,
          db,
          api.client(series: {
            ..._onePiece,
            'name': 'Une très longue histoire à travers les océans du monde',
          }, episodes: [
            (1, 1236)
          ]),
          film
              ? const MovieDetailScreen(movieId: 1406, title: 'Dune')
              : const ShowDetailScreen(
                  showId: 81797, title: 'Une très longue histoire'),
          size: const Size(320, 740),
          scale: 2);
      expect(tester.takeException(), isNull);
      if (!film) {
        await _tapAndSettle(tester, find.text('Épisodes'));
        await _tapAndSettle(tester, find.byTooltip('Aller à un numéro'));
        expect(tester.takeException(), isNull);
        await _tapAndSettle(tester, find.byTooltip('Annuler'));
      } else {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await _frames(tester);
        expect(tester.takeException(), isNull);
      }
      expect(await db.allWatchedEpisodes(), isEmpty);
      await _settle(tester);
    });
  }

  testWidgets('film : ajout explicite, visionnage unique, résumé et annulation',
      (tester) async {
    final db = _fkDb();
    addTearDown(db.close);
    await _pump(tester, db, _Api().client(),
        const MovieDetailScreen(movieId: 1406, title: 'Dune'));
    await _tapAndSettle(tester, find.text('Marquer vu'));
    expect(find.text('Ajouter à ma liste'), findsOneWidget);
    expect(await db.movieById(1406), isNull);
    await _tapAndSettle(tester, find.text('Annuler'));
    expect(await db.movieById(1406), isNull);
    await _tapAndSettle(tester, find.text('Marquer vu'));
    await _tapAndSettle(tester, find.text('Ajouter'));
    expect((await db.movieById(1406))!.watchedAt, isNull);
    await _tapAndSettle(tester, find.text('Marquer vu'));
    expect((await db.movieById(1406))!.watchedAt, isNotNull);
    expect(await db.select(db.movies).get(), hasLength(1));
    expect(find.text('Film vu'), findsOneWidget);
    await _tapAndSettle(tester, find.text('Annuler'));
    expect((await db.movieById(1406))!.watchedAt, isNull);
    expect(find.text('Film vu'), findsNothing);
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
