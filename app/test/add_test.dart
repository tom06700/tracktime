import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/tmdb/add.dart';
import 'package:tracktime/tmdb/tmdb.dart';

http.Response _json(Map<String, Object?> body) => http.Response(
      json.encode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('addShowFromTmdb insère avec les métadonnées', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/3/tv/70523');
      return _json({
        'name': 'Dark',
        'poster_path': '/dark.jpg',
        'number_of_episodes': 26,
        'number_of_seasons': 3,
        'episode_run_time': [53],
        'status': 'Ended',
      });
    });
    final name = await addShowFromTmdb(db, TmdbClient('k', client: client), 70523);
    expect(name, 'Dark');
    final show = await db.showById(70523);
    expect(show!.totalEpisodes, 26);
    expect(show.runtime, 53);
    expect(show.status, 'Ended');
  });

  test('addShowFromTmdb ne réappelle pas TMDB si déjà présente', () async {
    var calls = 0;
    final client = MockClient((req) async {
      calls++;
      return _json({'name': 'Dark', 'number_of_episodes': 26});
    });
    final tmdb = TmdbClient('k', client: client);
    await addShowFromTmdb(db, tmdb, 70523);
    final name = await addShowFromTmdb(db, tmdb, 70523);
    expect(name, 'Dark');
    expect(calls, 1);
  });

  test('addMovieFromTmdb insère dans la watchlist (non vu)', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/3/movie/496243');
      return _json({
        'title': 'Parasite',
        'poster_path': '/pa.jpg',
        'runtime': 132,
      });
    });
    final title =
        await addMovieFromTmdb(db, TmdbClient('k', client: client), 496243);
    expect(title, 'Parasite');
    final movie = await db.movieById(496243);
    expect(movie!.runtime, 132);
    expect(movie.watchedAt, isNull);
  });
}
