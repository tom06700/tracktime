import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tracktime/backup/backup_format.dart';
import 'package:tracktime/backup/restore.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/tmdb/tvdb.dart';

AppDatabase _db() => AppDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
  ),
);

/// TheTVDB de test : une table de résultats par (type, requête).
TvdbClient _tvdb(Map<String, List<Map<String, Object?>>> byQuery) => TvdbClient(
  'k',
  client: MockClient((req) async {
    if (req.url.path.endsWith('/login')) {
      return http.Response('{"data":{"token":"t"}}', 200);
    }
    final q = req.url.queryParameters['query'] ?? '';
    final type = req.url.queryParameters['type'] ?? '';
    return http.Response(
      jsonEncode({'data': byQuery['$type:$q'] ?? const []}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Map<String, Object?> _hit(
  int id,
  String name, {
  String type = 'series',
  Map<String, String>? translations,
  String? year,
}) => {
  'tvdb_id': '$id',
  'name': name,
  'type': type,
  'translations': ?translations,
  'year': ?year,
};

/// Ancienne sauvegarde TrackTime : pas de version, pas de fournisseur.
Map<String, Object?> _legacyFile({
  List<Map<String, Object?>> shows = const [],
  List<Map<String, Object?>> movies = const [],
}) => {'shows': shows, 'movies': movies};

LegacyBackup _legacy(Map<String, Object?> file) =>
    parseBackupFile(file) as LegacyBackup;

void main() {
  group('reconnaissance du fichier', () {
    test('sans version ni fournisseur → ancienne sauvegarde', () {
      final parsed = parseBackupFile(
        _legacyFile(
          shows: [
            {'id': 37854, 'name': 'One Piece'},
          ],
        ),
      );
      expect(parsed, isA<LegacyBackup>());
    });

    test('fournisseur TheTVDB déclaré → sauvegarde Nitrate', () {
      final parsed = parseBackupFile({
        'schemaVersion': 2,
        'metadataProvider': 'thetvdb',
        'shows': [
          {'id': 81797, 'name': 'One Piece'},
        ],
        'movies': <Object>[],
      });
      expect(parsed, isA<NitrateBackup>());
    });

    test('fournisseur TMDB déclaré → re-appariement, pas de copie d\'ID', () {
      final parsed = parseBackupFile({
        'metadataProvider': 'tmdb',
        'shows': [
          {'id': 37854, 'name': 'One Piece'},
        ],
      });
      expect(parsed, isA<LegacyBackup>());
    });

    test('version future → refus explicite', () {
      final parsed = parseBackupFile({
        'schemaVersion': 99,
        'metadataProvider': 'thetvdb',
        'shows': <Object>[],
      });
      expect(parsed, isA<UnsupportedBackup>());
      expect(
        (parsed as UnsupportedBackup).message,
        contains('version plus récente'),
      );
    });

    test('fournisseur inconnu → refus explicite', () {
      final parsed = parseBackupFile({
        'metadataProvider': 'trakt',
        'shows': <Object>[],
      });
      expect(parsed, isA<UnsupportedBackup>());
    });

    test('« shows » du mauvais type → refus, pas de plantage', () {
      expect(parseBackupFile({'shows': 'oops'}), isA<UnsupportedBackup>());
    });

    test('sans tableau reconnaissable → ce n\'est pas une sauvegarde', () {
      expect(parseBackupFile({'objects': []}), isNull);
      expect(parseBackupFile('du texte'), isNull);
      expect(parseBackupFile(null), isNull);
    });

    test('tableaux et champs facultatifs manquants', () {
      final parsed = parseBackupFile({'shows': <Object>[]}) as LegacyBackup;
      expect(parsed.shows, isEmpty);
      expect(parsed.movies, isEmpty);

      final partial =
          parseBackupFile({
                'shows': [
                  {'name': 'Minimale'},
                  {'id': 5}, // sans nom : ignorée
                ],
              })
              as LegacyBackup;
      expect(partial.shows.map((s) => s.name), ['Minimale']);
      expect(partial.shows.single.id, isNull);
    });

    test('entrées de progression illisibles ignorées', () {
      final parsed =
          parseBackupFile({
                'shows': [
                  {
                    'name': 'Bancale',
                    'watched': {
                      'S1E1': '2020-01-01T00:00:00Z',
                      'S0E1': null, // saison 0
                      'S1E0': null, // épisode 0
                      'pas une clé': '2020-01-01T00:00:00Z',
                      'S-1E2': null,
                    },
                  },
                ],
              })
              as LegacyBackup;
      final watched = parsed.shows.single.watched;
      expect(watched, hasLength(1));
      expect(watched.single.season, 1);
      expect(watched.single.episode, 1);
    });
  });

  group('ancienne sauvegarde : re-appariement', () {
    test('One Piece : l\'animé, jamais l\'ancien identifiant', () async {
      // Ordre brut de TheTVDB : la live-action d'abord, l'animé plus bas.
      final tvdb = _tvdb({
        'series:One Piece': [
          _hit(392276, 'ONE PIECE (2023)', year: '2023'),
          _hit(464521, 'THE ONE PIECE'),
          _hit(
            81797,
            'ワンピース',
            translations: {'fra': 'One Piece', 'eng': 'One Piece'},
            year: '1999',
          ),
        ],
      });
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {
                'id': 37854, // identifiant d'un autre fournisseur
                'name': 'One Piece',
                'watched': {
                  'S1E1': '2020-01-01T00:00:00Z',
                  'S1E2': '2020-01-02T00:00:00Z',
                },
              },
            ],
          ),
        ),
      );

      expect(await db.showById(37854), isNull, reason: 'ancien identifiant');
      final anime = await db.showById(81797);
      expect(anime, isNotNull);
      expect(anime!.name, 'One Piece');
      expect((await db.watchEpisodesOf(81797).first), hasLength(2));
      expect(report.importedShows, 1);
      expect(report.importedEpisodes, 2);
      expect(report.lines, contains('✅ One Piece → One Piece · TheTVDB 81797'));
    });

    test('un film ne peut pas être apparié par une série', () async {
      // La recherche typée « movie » ne rend qu'une série : rien à retenir.
      final tvdb = _tvdb({
        'movie:Dune': [_hit(1234, 'Dune', type: 'series')],
      });
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            movies: [
              {'id': 999, 'title': 'Dune', 'watchedAt': '2022-01-01T00:00:00Z'},
            ],
          ),
        ),
      );

      expect(await db.movieById(1234), isNull);
      expect(await db.movieById(999), isNull);
      expect(report.skippedMovies, 1);
      expect(report.errors.single, contains('aucune correspondance'));
    });

    test('un film legacy retrouve le bon film', () async {
      final tvdb = _tvdb({
        'movie:Parasite': [
          _hit(111, 'Parasite Eve', type: 'movie'),
          _hit(496243, 'Parasite', type: 'movie', year: '2019'),
        ],
      });
      final db = _db();
      addTearDown(db.close);

      await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            movies: [
              {
                'id': 496243999,
                'title': 'Parasite',
                'watchedAt': '2022-01-01T00:00:00Z',
              },
            ],
          ),
        ),
      );

      final movie = await db.movieById(496243);
      expect(movie, isNotNull);
      expect(movie!.watchedAt, isNotNull);
    });

    test('correspondance ambiguë → écartée avec un avertissement', () async {
      final tvdb = _tvdb({
        'series:The Office': [
          _hit(73244, 'The Office', year: '2005'),
          _hit(78107, 'The Office', year: '2001'),
        ],
      });
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {
                'name': 'The Office',
                'watched': {'S1E1': '2020-01-01T00:00:00Z'},
              },
            ],
          ),
        ),
      );

      expect(await db.showById(73244), isNull);
      expect(await db.showById(78107), isNull);
      expect(report.skippedShows, 1);
      expect(report.warnings.single, contains('plusieurs correspondances'));
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
    });

    test('l\'année départage deux homonymes', () async {
      final tvdb = _tvdb({
        'series:The Office': [
          _hit(73244, 'The Office', year: '2005'),
          _hit(78107, 'The Office', year: '2001'),
        ],
      });
      final db = _db();
      addTearDown(db.close);

      await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {'name': 'The Office', 'year': '2001'},
            ],
          ),
        ),
      );

      expect(await db.showById(78107), isNotNull);
      expect(await db.showById(73244), isNull);
    });

    test('correspondance approximative → écartée', () async {
      // « One Piece Film: Red » n'est qu'un préfixe : trop faible pour
      // rattacher un historique.
      final tvdb = _tvdb({
        'series:Skins': [_hit(1, 'Skins Redux')],
      });
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {'name': 'Skins'},
            ],
          ),
        ),
      );

      expect(await db.showById(1), isNull);
      expect(report.warnings.single, contains('incertaine'));
    });

    test('aucun résultat → erreur, import poursuivi', () async {
      final tvdb = _tvdb({
        'series:Connue': [_hit(70523, 'Connue')],
      });
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {'name': 'Inexistante'},
              {'name': 'Connue'},
            ],
          ),
        ),
      );

      expect(report.importedShows, 1);
      expect(report.skippedShows, 1);
      expect(await db.showById(70523), isNotNull);
      expect(report.errors.single, contains('Inexistante'));
    });

    test('fusionne avec une série déjà présente, sans doublon', () async {
      final tvdb = _tvdb({
        'series:Dark': [_hit(70523, 'Dark')],
      });
      final db = _db();
      addTearDown(db.close);
      await db.upsertShow(
        ShowsCompanion.insert(id: const Value(70523), name: 'Dark'),
      );
      final vieux = DateTime.utc(2019, 1, 1);
      await db.setEpisodeWatched(70523, 1, 1, at: vieux);

      await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {
                'name': 'Dark',
                'watched': {
                  'S1E1': '2021-06-06T00:00:00Z', // déjà vu localement
                  'S1E2': '2021-06-07T00:00:00Z',
                },
              },
            ],
          ),
        ),
      );

      expect(await db.allShows(), hasLength(1));
      final eps = await db.watchEpisodesOf(70523).first;
      expect(eps, hasLength(2));
      // La date locale l'emporte : la restauration complète, elle n'écrase pas.
      expect(
        eps.firstWhere((e) => e.episode == 1).watchedAt.isAtSameMomentAs(vieux),
        isTrue,
      );
    });

    test('les dates de la sauvegarde sont conservées', () async {
      final tvdb = _tvdb({
        'series:Dark': [_hit(70523, 'Dark')],
      });
      final db = _db();
      addTearDown(db.close);

      await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {
                'name': 'Dark',
                'watched': {'S1E1': '2019-12-01T00:00:00Z'},
              },
            ],
          ),
        ),
      );

      final ep = (await db.watchEpisodesOf(70523).first).single;
      expect(ep.watchedAt.isAtSameMomentAs(DateTime.utc(2019, 12, 1)), isTrue);
    });

    test('TheTVDB indisponible : l\'import n\'explose pas', () async {
      final tvdb = TvdbClient(
        'k',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response('{"data":{"token":"t"}}', 200);
          }
          return http.Response('boom', 500);
        }),
      );
      final db = _db();
      addTearDown(db.close);

      final report = await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {'name': 'Dark'},
            ],
          ),
        ),
      );

      expect(report.skippedShows, 1);
      expect(report.errors.single, contains('indisponible'));
      expect(await db.allShows(), isEmpty);
    });
  });

  group('écriture', () {
    test('aucune progression ne référence une série absente', () async {
      final tvdb = _tvdb({
        'series:Dark': [_hit(70523, 'Dark')],
        'series:Fantôme': const [],
      });
      final db = _db();
      addTearDown(db.close);

      await restoreLegacyBackup(
        db,
        tvdb,
        _legacy(
          _legacyFile(
            shows: [
              {
                'name': 'Dark',
                'watched': {'S1E1': null},
              },
              {
                'name': 'Fantôme',
                'watched': {'S1E1': null},
              },
            ],
          ),
        ),
      );

      final watched = await db.select(db.watchedEpisodes).get();
      expect(watched.map((w) => w.showId).toSet(), {70523});
    });

    test('une écriture fautive annule toute la transaction', () async {
      final db = _db();
      addTearDown(db.close);
      // Plan volontairement incohérent : une progression sur une série que le
      // plan ne crée pas. Clés étrangères actives → l'écriture échoue.
      const plan = ImportPlan(
        shows: [PlannedShow(id: 1, name: 'Valide')],
        movies: [PlannedMovie(id: 2, title: 'Valide aussi')],
        watched: [(showId: 999, season: 1, episode: 1, at: null)],
      );

      await expectLater(applyImportPlan(db, plan), throwsA(anything));

      expect(await db.allShows(), isEmpty, reason: 'transaction annulée');
      expect(await db.allMovies(), isEmpty);
      expect(await db.select(db.watchedEpisodes).get(), isEmpty);
    });
  });
}
