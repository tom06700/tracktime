import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/import/importer.dart';
import 'package:tracktime/import/parser.dart';
import 'package:tracktime/tmdb/tmdb.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('importWebBackup restaure séries, épisodes, films et clé', () async {
    final result = await importWebBackup(db, {
      'shows': [
        {
          'id': 1396,
          'name': 'Breaking Bad',
          'poster': '/p.jpg',
          'total': 62,
          'seasons': 5,
          'runtime': 47,
          'status': 'Ended',
          'watched': {
            'S1E1': '2020-01-01T00:00:00Z',
            'S1E2': '2020-01-02T00:00:00Z',
          },
        },
      ],
      'movies': [
        {'id': 27205, 'title': 'Inception', 'runtime': 148, 'watchedAt': null},
        {
          'id': 157336,
          'title': 'Interstellar',
          'watchedAt': '2021-05-05T00:00:00Z',
        },
      ],
      'key': 'ma-cle',
    });

    expect(result.shows, 1);
    expect(result.movies, 2);
    expect(result.tmdbKey, 'ma-cle');

    final show = await db.showById(1396);
    expect(show!.name, 'Breaking Bad');
    expect(show.totalEpisodes, 62);
    final eps = await db.watchEpisodesOf(1396).first;
    expect(eps.length, 2);

    final inception = await db.movieById(27205);
    expect(inception!.watchedAt, isNull);
    final interstellar = await db.movieById(157336);
    expect(interstellar!.watchedAt, isNotNull);
  });

  test('importWebBackup fusionne sans écraser les films existants', () async {
    await importWebBackup(db, {
      'shows': <Object>[],
      'movies': [
        {'id': 1, 'title': 'Déjà vu', 'watchedAt': '2020-01-01T00:00:00Z'},
      ],
    });
    // Second backup : même film, non vu — ne doit pas écraser watchedAt.
    await importWebBackup(db, {
      'shows': <Object>[],
      'movies': [
        {'id': 1, 'title': 'Déjà vu', 'watchedAt': null},
      ],
    });
    expect((await db.movieById(1))!.watchedAt, isNotNull);
  });

  test('runTvTimeImport fait correspondre via TMDB', () async {
    final client = MockClient((request) async {
      final path = request.url.path;
      Map<String, Object?> body;
      if (path == '/3/search/tv') {
        body = request.url.queryParameters['query'] == 'Dark'
            ? {
                'results': [
                  {'id': 70523, 'name': 'Dark'},
                ],
              }
            : {'results': <Object>[]};
      } else if (path == '/3/tv/70523') {
        body = {
          'name': 'Dark',
          'poster_path': '/dark.jpg',
          'number_of_episodes': 26,
          'number_of_seasons': 3,
          'episode_run_time': [53],
          'status': 'Ended',
        };
      } else if (path == '/3/search/movie') {
        body = {
          'results': [
            {'id': 496243, 'title': 'Parasite', 'poster_path': '/pa.jpg'},
          ],
        };
      } else {
        return http.Response('not found', 404);
      }
      return http.Response(json.encode(body), 200,
          headers: {'content-type': 'application/json'});
    });

    final parsed = ParsedData();
    parseCsvInto(parsed, '''
tv_show_name,season,episode,watched_at
Dark,1,1,2019-12-01
Dark,1,2,2019-12-02
Série Inconnue,1,1,
''');
    parsed.movies.add(const ParsedMovie('Parasite', '2022-01-01'));
    parsed.movies.add(const ParsedMovie('parasite', null)); // doublon

    final logs = <String>[];
    final summary = await runTvTimeImport(
      db,
      TmdbClient('test-key', client: client),
      parsed,
      onProgress: (pct, line) {
        if (line != null) logs.add(line);
      },
    );

    expect(summary.matched, 2); // Dark + Parasite
    expect(summary.failed, 1); // Série Inconnue
    expect(logs.single, contains('Série Inconnue'));

    final dark = await db.showById(70523);
    expect(dark!.runtime, 53);
    expect((await db.watchEpisodesOf(70523).first).length, 2);
    expect((await db.movieById(496243))!.watchedAt, isNotNull);
  });

  test('runTvTimeImport sans clé : tout échoue proprement', () async {
    final parsed = ParsedData();
    parseCsvInto(parsed, 'show,season,episode\nDark,1,1\n');
    final summary = await runTvTimeImport(
      db,
      TmdbClient(''),
      parsed,
      onProgress: (_, _) {},
    );
    expect(summary.failed, 1);
    expect(summary.matched, 0);
  });
}
