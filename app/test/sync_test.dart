import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/series/sync.dart';
import 'package:tracktime/tmdb/tvdb.dart';

/// Serveur TheTVDB de test : compte les appels et sert la liste d'épisodes
/// qu'on lui donne, qui peut changer entre deux passes.
class _Api {
  _Api(this.episodes);

  /// (saison, numéro) des épisodes servis. Modifiable en cours de test pour
  /// simuler la parution d'un nouvel épisode côté TheTVDB.
  List<(int, int)> episodes;

  /// Quand true, `/episodes/` répond 500.
  bool down = false;

  int episodeCalls = 0;

  TvdbClient client() => TvdbClient(
        'test-key',
        client: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/login')) {
            return http.Response(
              '{"data":{"token":"t"},"status":"success"}',
              200,
            );
          }
          if (path.contains('/episodes/')) {
            episodeCalls++;
            if (down) return http.Response('nope', 500);
            // Une seule page : le client s'arrête sous 100 épisodes.
            final page = int.tryParse(req.url.queryParameters['page'] ?? '0');
            final eps = page == 0
                ? [
                    for (final (s, n) in episodes)
                      {
                        'seasonNumber': s,
                        'number': n,
                        'name': 'S${s}E$n',
                        'aired': '2026-01-0$n',
                      },
                  ]
                : const [];
            return http.Response(
              jsonEncode({
                'data': {'episodes': eps},
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{"data":{}}', 200);
        }),
      );
}

AppDatabase _db() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _addShow(AppDatabase db, {DateTime? syncedAt}) => db.upsertShow(
      ShowsCompanion.insert(
        id: const Value(1),
        name: 'Ma série',
        episodesSyncedAt: Value(syncedAt),
      ),
    );

Future<List<Episode>> _episodesOf(AppDatabase db) => db.select(db.episodes).get();

void main() {
  setUp(resetSyncLock);

  test('une série fraîche n\'est pas resynchronisée', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db, syncedAt: DateTime.now());
    final api = _Api([(1, 1)]);

    final out = await syncStaleShows(db, api.client());

    expect(api.episodeCalls, 0, reason: 'le TTL de 24 h protège le réseau');
    expect(out.synced, 0);
  });

  test('au-delà de 24 h, la série est resynchronisée', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(
      db,
      syncedAt: DateTime.now().subtract(const Duration(hours: 25)),
    );
    final api = _Api([(1, 1)]);

    final out = await syncStaleShows(db, api.client());

    expect(api.episodeCalls, 1);
    expect(out.synced, 1);
    expect(await _episodesOf(db), hasLength(1));
  });

  test('force ignore le TTL', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db, syncedAt: DateTime.now());
    final api = _Api([(1, 1)]);

    final out = await syncStaleShows(db, api.client(), force: true);

    expect(api.episodeCalls, 1);
    expect(out.synced, 1);
  });

  test('force contourne aussi le cache mémoire du client', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(1, 1)]);
    // Le client est un singleton dans l'app : c'est le même entre les deux
    // passes, donc sa liste d'épisodes en mémoire aussi.
    final tvdb = api.client();

    await syncStaleShows(db, tvdb);
    expect(await _episodesOf(db), hasLength(1));

    // Un nouvel épisode paraît côté TheTVDB.
    api.episodes = [(1, 1), (1, 2)];

    // Sans force : le TTL ET le cache mémoire renverraient l'ancienne liste.
    await syncStaleShows(db, tvdb, force: true);

    expect(api.episodeCalls, 2);
    final eps = await _episodesOf(db)
      ..sort((a, b) => a.episode.compareTo(b.episode));
    expect(eps.map((e) => e.episode), [1, 2]);
  });

  test('sans force, le cache mémoire suffit et rien ne bouge', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(1, 1)]);
    final tvdb = api.client();

    await syncStaleShows(db, tvdb);
    api.episodes = [(1, 1), (1, 2)];
    // TTL neuf → la série est ignorée, sans même toucher au réseau.
    await syncStaleShows(db, tvdb);

    expect(api.episodeCalls, 1);
    expect(await _episodesOf(db), hasLength(1));
  });

  test('une synchro en échec ne date pas la série', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(1, 1)])..down = true;

    final out = await syncStaleShows(db, api.client());

    expect(out.failed, 1);
    expect(out.hasFailures, isTrue);
    final show = await db.showById(1);
    expect(
      show!.episodesSyncedAt,
      isNull,
      reason: 'sinon la série resterait muette pendant 24 h',
    );
  });

  test('un échec n\'arrête pas les autres séries', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(2), name: 'Autre'),
    );
    final api = _Api([(1, 1)]);
    final tvdb = api.client();

    // La première série échoue, la seconde passe.
    var first = true;
    final flaky = TvdbClient(
      'test-key',
      client: MockClient((req) async {
        if (req.url.path.endsWith('/login')) {
          return http.Response('{"data":{"token":"t"}}', 200);
        }
        if (req.url.path.contains('/episodes/')) {
          if (first) {
            first = false;
            return http.Response('nope', 500);
          }
          return http.Response(
            jsonEncode({
              'data': {
                'episodes': [
                  {'seasonNumber': 1, 'number': 1, 'aired': '2026-01-01'},
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"data":{}}', 200);
      }),
    );

    final out = await syncStaleShows(db, flaky);

    expect(out.synced, 1);
    expect(out.failed, 1);
    expect(tvdb.apiKey, isNotEmpty);
  });

  test('sans clé API, aucune requête', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(1, 1)]);

    final out = await syncStaleShows(db, TvdbClient(''));

    expect(api.episodeCalls, 0);
    expect(out.synced, 0);
  });

  test('deux synchros lancées ensemble ne se doublent pas', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(1, 1)]);
    final tvdb = api.client();

    // La seconde s'enchaîne derrière la première ; quand elle démarre, la
    // série vient d'être datée et se trouve donc à jour.
    await Future.wait([
      syncStaleShows(db, tvdb),
      syncStaleShows(db, tvdb),
    ]);

    expect(api.episodeCalls, 1);
  });

  test('les spéciaux (saison 0) restent hors du cache', () async {
    final db = _db();
    addTearDown(db.close);
    await _addShow(db);
    final api = _Api([(0, 1), (1, 1), (1, 2)]);

    await syncStaleShows(db, api.client());

    expect(await _episodesOf(db), hasLength(2));
    final show = await db.showById(1);
    expect(show!.totalEpisodes, 2);
    expect(show.seasonCount, 1);
    expect(show.episodesSyncedAt, isNotNull);
  });
}
