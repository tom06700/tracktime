import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/providers.dart';
import 'package:tracktime/screens/show_detail_screen.dart';
import 'package:tracktime/series/feed.dart';
import 'package:tracktime/settings/prefs.dart';
import 'package:tracktime/theme.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Base avec les clés étrangères actives, comme sur l'appareil.
AppDatabase _db() => AppDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
  ),
);

const _showId = 81797;

final _series = <String, Object?>{
  'name': 'One Piece',
  'overview': 'Luffy prend la mer.',
  'seasons': [
    {
      'number': 1,
      'type': {'type': 'official'},
    },
  ],
};

TvdbClient _client(int episodeCount) => TvdbClient(
  'test',
  client: MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/login')) {
      return http.Response('{"data":{"token":"t"}}', 200);
    }
    Object? body = <String, Object?>{};
    if (path.contains('/series/') && path.endsWith('/extended')) {
      body = _series;
    } else if (path.contains('/episodes/')) {
      body = {
        'episodes': [
          for (var n = 1; n <= episodeCount; n++)
            {
              'seasonNumber': 1,
              'number': n,
              'name': 'Épisode $n',
              'overview': 'Résumé $n',
            },
        ],
      };
    }
    return http.Response(
      jsonEncode({
        'data': body,
        'links': {'next': null},
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Future<void> _frames(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await _frames(tester, 2);
  await tester.tap(f);
  await _frames(tester);
}

/// Monte la fiche d'une série suivie et déplie sa saison 1.
Future<void> _openEpisodes(
  WidgetTester tester,
  AppDatabase db, {
  int episodeCount = 12,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        tvdbClientProvider.overrideWithValue(_client(episodeCount)),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: const ShowDetailScreen(showId: _showId, title: 'One Piece'),
      ),
    ),
  );
  await _frames(tester);
  await _tap(tester, find.text('Épisodes'));
  await _tap(tester, find.text('Saison 1'));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Série suivie, épisodes 1..[watchedUpTo] déjà vus.
Future<AppDatabase> _followedShow({required int watchedUpTo}) async {
  final db = _db();
  await db.upsertShow(
    ShowsCompanion.insert(id: const Value(_showId), name: 'One Piece'),
  );
  for (var n = 1; n <= watchedUpTo; n++) {
    await db.setEpisodeWatched(_showId, 1, n);
  }
  return db;
}

Set<int> _watchedNumbers(List<WatchedEpisode> rows) => {
  for (final w in rows) w.episode,
};

void main() {
  group('setEpisodesWatched', () {
    test('écrit tout d\'un coup, sans doublon', () async {
      final db = await _followedShow(watchedUpTo: 0);
      addTearDown(db.close);

      await db.setEpisodesWatched(_showId, [
        (season: 1, episode: 1),
        (season: 1, episode: 2),
        (season: 1, episode: 3),
      ]);
      // Rejouer ne doit rien casser : clé primaire (série, saison, épisode).
      await db.setEpisodesWatched(_showId, [
        (season: 1, episode: 2),
        (season: 1, episode: 3),
      ]);

      final rows = await db.select(db.watchedEpisodes).get();
      expect(rows, hasLength(3));
      expect(_watchedNumbers(rows), {1, 2, 3});
    });

    test('préserve la date d\'un épisode déjà vu', () async {
      final db = await _followedShow(watchedUpTo: 0);
      addTearDown(db.close);
      final vieux = DateTime(2020, 1, 1);
      await db.setEpisodeWatched(_showId, 1, 1, at: vieux);

      await db.setEpisodesWatched(_showId, [
        (season: 1, episode: 1),
        (season: 1, episode: 2),
      ]);

      final rows = await db.select(db.watchedEpisodes).get();
      final first = rows.firstWhere((w) => w.episode == 1);
      expect(first.watchedAt, vieux);
    });

    test('une liste vide ne touche pas la base', () async {
      final db = await _followedShow(watchedUpTo: 0);
      addTearDown(db.close);

      await db.setEpisodesWatched(_showId, const []);

      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
    });
  });

  group('proposition de rattrapage', () {
    testWidgets('cocher un épisode après un trou propose de le combler', (
      tester,
    ) async {
      final db = await _followedShow(watchedUpTo: 5);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));

      expect(
        find.text('Marquer les épisodes intermédiaires ?'),
        findsOneWidget,
      );
      expect(
        find.textContaining('4 épisodes entre ton dernier épisode vu'),
        findsOneWidget,
      );

      await _settle(tester);
    });

    testWidgets('« Tout marquer comme vu » comble le trou', (tester) async {
      final db = await _followedShow(watchedUpTo: 5);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));
      await _tap(tester, find.text('Tout marquer comme vu'));

      final rows = await db.select(db.watchedEpisodes).get();
      expect(_watchedNumbers(rows), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});

      await _settle(tester);
    });

    testWidgets('« Seulement cet épisode » ne touche à rien d\'autre', (
      tester,
    ) async {
      final db = await _followedShow(watchedUpTo: 5);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));
      await _tap(tester, find.text('Seulement cet épisode'));

      final rows = await db.select(db.watchedEpisodes).get();
      expect(_watchedNumbers(rows), {1, 2, 3, 4, 5, 10});

      await _settle(tester);
    });

    testWidgets('sans trou, aucune question n\'est posée', (tester) async {
      final db = await _followedShow(watchedUpTo: 9);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));

      expect(find.text('Tout marquer comme vu'), findsNothing);
      final rows = await db.select(db.watchedEpisodes).get();
      expect(_watchedNumbers(rows), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10});

      await _settle(tester);
    });

    testWidgets('décocher ne propose rien', (tester) async {
      final db = await _followedShow(watchedUpTo: 10);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));

      expect(find.text('Tout marquer comme vu'), findsNothing);
      final rows = await db.select(db.watchedEpisodes).get();
      expect(rows.any((w) => w.episode == 10), isFalse);

      await _settle(tester);
    });

    testWidgets('série neuve : cocher un épisode lointain ne propose rien', (
      tester,
    ) async {
      final db = await _followedShow(watchedUpTo: 0);
      addTearDown(db.close);

      await _openEpisodes(tester, db);
      await _tap(tester, find.textContaining('10. Épisode 10'));

      expect(find.text('Tout marquer comme vu'), findsNothing);
      final rows = await db.select(db.watchedEpisodes).get();
      expect(_watchedNumbers(rows), {10});

      await _settle(tester);
    });
  });

  test('après rattrapage, le fil propose l\'épisode suivant', () async {
    final db = await _followedShow(watchedUpTo: 49);
    addTearDown(db.close);
    await db.upsertEpisodes([
      for (var n = 1; n <= 61; n++)
        EpisodesCompanion.insert(
          showId: _showId,
          season: 1,
          episode: n,
          airDate: Value(DateTime(2026, 1, 1)),
        ),
    ]);

    await db.setEpisodesWatched(_showId, [
      for (var n = 50; n <= 60; n++) (season: 1, episode: n),
    ]);

    final feed = buildSeriesFeed(
      shows: await db.watchShowsWithProgress().first,
      episodes: await db.select(db.episodes).get(),
      watched: await db.allWatchedEpisodes(),
      now: DateTime(2026, 6, 1),
    );

    final next = feed.toWatch.single;
    expect(next.season, 1);
    expect(next.episode, 61);
    expect(next.precise, isTrue);
  });
}
