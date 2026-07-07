import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/tmdb/add.dart';
import 'package:tracktime/tmdb/tvdb.dart';

http.Response _json(Map<String, Object?> body) => http.Response(
      json.encode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

/// MockClient routant les endpoints TheTVDB (login + extended + traduction).
MockClient _mock(Map<String, Map<String, Object?>> byPath,
    {void Function()? onCall}) {
  return MockClient((req) async {
    onCall?.call();
    if (req.method == 'POST' && req.url.path == '/v4/login') {
      return _json({
        'status': 'success',
        'data': {'token': 'tok'}
      });
    }
    final body = byPath[req.url.path];
    if (body == null) return http.Response('{}', 404);
    return _json({'status': 'success', 'data': body});
  });
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('addShowFromTvdb insère avec les métadonnées', () async {
    final client = _mock({
      '/v4/series/70523/extended': {
        'name': 'Dark',
        'image': 'https://artworks.thetvdb.com/dark.jpg',
        'averageRuntime': 53,
        'status': {'name': 'Ended'},
        'seasons': [
          {'type': {'type': 'official'}, 'number': 1},
          {'type': {'type': 'official'}, 'number': 2},
          {'type': {'type': 'official'}, 'number': 3},
        ],
        'genres': [
          {'name': 'Drama'},
          {'name': 'Science Fiction'},
        ],
      },
    });
    final name = await addShowFromTvdb(db, TvdbClient('k', client: client), 70523);
    expect(name, 'Dark');
    final show = await db.showById(70523);
    expect(show!.seasonCount, 3);
    expect(show.runtime, 53);
    expect(show.status, 'Ended');
    expect(show.genres, 'Drama|Science Fiction');
    expect(show.poster, 'https://artworks.thetvdb.com/dark.jpg');
  });

  test('addShowFromTvdb ne réappelle pas TheTVDB si déjà présente', () async {
    var calls = 0;
    final client = _mock({
      '/v4/series/70523/extended': {'name': 'Dark'},
    }, onCall: () => calls++);
    final tvdb = TvdbClient('k', client: client);
    await addShowFromTvdb(db, tvdb, 70523);
    final callsAfterFirst = calls;
    final name = await addShowFromTvdb(db, tvdb, 70523);
    expect(name, 'Dark');
    // Le 2e ajout ne déclenche aucun appel réseau supplémentaire.
    expect(calls, callsAfterFirst);
  });

  test('addMovieFromTvdb insère dans la watchlist (non vu)', () async {
    final client = _mock({
      '/v4/movies/496243/extended': {
        'name': 'Parasite',
        'image': 'https://artworks.thetvdb.com/pa.jpg',
        'runtime': 132,
        'first_release': {'date': '2019-05-30'},
        'genres': [
          {'name': 'Thriller'}
        ],
      },
    });
    final title =
        await addMovieFromTvdb(db, TvdbClient('k', client: client), 496243);
    expect(title, 'Parasite');
    final movie = await db.movieById(496243);
    expect(movie!.runtime, 132);
    expect(movie.watchedAt, isNull);
    expect(movie.releaseDate, DateTime(2019, 5, 30));
  });
}
