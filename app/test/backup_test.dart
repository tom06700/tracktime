import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/backup/backup.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/import/importer.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('backupFileName est daté', () {
    expect(backupFileName(DateTime(2026, 7, 6)), 'tracktime-backup-2026-07-06.json');
    expect(backupFileName(DateTime(2026, 12, 31)),
        'tracktime-backup-2026-12-31.json');
  });

  test('buildBackup produit le format web attendu', () async {
    await importWebBackup(db, {
      'shows': [
        {
          'id': 1396,
          'name': 'Breaking Bad',
          'total': 62,
          'seasons': 5,
          'runtime': 47,
          'status': 'Ended',
          'watched': {'S1E1': '2020-01-01T00:00:00.000Z'},
        },
      ],
      'movies': [
        {'id': 27205, 'title': 'Inception', 'watchedAt': null},
      ],
    });

    final backup = await buildBackup(db, tmdbKey: 'ma-cle');
    expect(backup['key'], 'ma-cle');
    final shows = backup['shows'] as List;
    expect(shows.single['name'], 'Breaking Bad');
    expect((shows.single['watched'] as Map).containsKey('S1E1'), isTrue);
    final movies = backup['movies'] as List;
    expect(movies.single['title'], 'Inception');
    expect(movies.single['watchedAt'], isNull);
  });

  test('buildBackup omet la clé si vide', () async {
    final backup = await buildBackup(db, tmdbKey: '');
    expect(backup.containsKey('key'), isFalse);
  });

  test('aller-retour : buildBackup puis importWebBackup préserve les données',
      () async {
    await importWebBackup(db, {
      'shows': [
        {
          'id': 70523,
          'name': 'Dark',
          'total': 26,
          'watched': {
            'S1E1': '2019-12-01T00:00:00.000Z',
            'S1E2': '2019-12-02T00:00:00.000Z',
          },
        },
      ],
      'movies': [
        {'id': 496243, 'title': 'Parasite', 'watchedAt': '2022-01-01T00:00:00.000Z'},
      ],
    });

    final backup = await buildBackup(db);

    // Réimporte dans une base vierge.
    final db2 = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db2.close);
    final result = await importWebBackup(db2, backup);

    expect(result.shows, 1);
    expect(result.movies, 1);
    expect((await db2.watchEpisodesOf(70523).first).length, 2);
    expect((await db2.movieById(496243))!.watchedAt, isNotNull);
  });
}
