import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/backup/backup_format.dart';
import 'package:tracktime/import/parser.dart';

void main() {
  group('readCsv', () {
    test('gère guillemets, virgules internes et échappements', () {
      final rows = readCsv('a,"b, c","d ""e"""\n1,2,3\r\n\r\n4,5,6');
      expect(rows, [
        ['a', 'b, c', 'd "e"'],
        ['1', '2', '3'],
        ['4', '5', '6'],
      ]);
    });
  });

  group('parseCsvInto', () {
    test('export épisodes TV Time', () {
      final parsed = ParsedData();
      parseCsvInto(parsed, '''
tv_show_name,season_number,episode_number,watched_at
Breaking Bad,1,2,2020-05-01T20:00:00Z
Breaking Bad,1,3,2020-05-02
"Orange, Is the New Black",2,1,
''');
      expect(parsed.byShow['Breaking Bad']!.length, 2);
      expect(parsed.byShow['Breaking Bad']![0].date, '2020-05-01');
      expect(parsed.byShow['Orange, Is the New Black']!.single.season, 2);
      expect(parsed.movies, isEmpty);
    });

    test('export films TV Time', () {
      final parsed = ParsedData();
      parseCsvInto(parsed, '''
movie_name,watched_at
Inception,2021-01-01
Interstellar,
''');
      expect(parsed.movies.length, 2);
      expect(parsed.movies.first.title, 'Inception');
      expect(parsed.movies.first.date, '2021-01-01');
    });

    test('colonne title générique sans colonne season = films', () {
      final parsed = ParsedData();
      parseCsvInto(parsed, 'title,created_at\nDune,2024-03-10\n');
      expect(parsed.movies.single.title, 'Dune');
    });
  });

  group('parseJsonInto', () {
    test('format tracktime_import', () {
      final parsed = ParsedData();
      final ok = parseJsonInto(parsed, {
        'tracktime_import': 1,
        'shows': [
          {
            'name': 'Dark',
            'episodes': [
              [1, 1, '2019-01-01'],
              [1, 2, null],
            ],
          },
          {'name': 'Suivie sans épisode', 'episodes': []},
        ],
        'movies': [
          {'title': 'Amélie', 'date': '2020-02-02', 'watched': true},
          {'title': 'À voir', 'watched': false},
        ],
      });
      expect(ok, isTrue);
      expect(parsed.byShow['Dark']!.length, 2);
      expect(parsed.byShow.containsKey('Suivie sans épisode'), isTrue);
      expect(parsed.movies[1].watched, isFalse);
    });

    test('export GDPR générique (liste d\'objets)', () {
      final parsed = ParsedData();
      final ok = parseJsonInto(parsed, {
        'data': {
          'objects': [
            {
              'entity_type': 'episode',
              'meta': {'name': 'Dark'},
              'season_number': 2,
              'episode_number': 3,
              'watched_at': '2021-06-06T10:00:00Z',
            },
            {
              'entity_type': 'movie',
              'meta': {'name': 'Parasite'},
              'created_at': '2022-07-07',
            },
          ],
        },
      });
      expect(ok, isTrue);
      expect(parsed.byShow['Dark']!.single.episode, 3);
      expect(parsed.movies.single.title, 'Parasite');
      expect(parsed.movies.single.date, '2022-07-07');
    });
  });

  group('parseFile', () {
    test('détecte une ancienne sauvegarde, sans lui faire confiance', () {
      const backup = '''
{"shows":[{"id":1396,"name":"Breaking Bad","watched":{"S1E1":"2020-01-01T00:00:00Z"}}],
 "movies":[{"id":27205,"title":"Inception","watchedAt":null}],
 "key":"abc123"}
''';
      final result = parseFile(ParsedData(), backup);
      expect(result, isA<BackupFileFound>());
      // Aucun fournisseur déclaré : ses identifiants devront être re-appariés.
      expect((result as BackupFileFound).backup, isA<LegacyBackup>());
    });

    test('détecte une sauvegarde Nitrate versionnée', () {
      const backup = '''
{"schemaVersion":2,"app":"nitrate","metadataProvider":"thetvdb",
 "shows":[{"id":81797,"name":"One Piece","watched":{}}],"movies":[]}
''';
      final result = parseFile(ParsedData(), backup);
      expect((result as BackupFileFound).backup, isA<NitrateBackup>());
    });

    test('JSON invalide → non reconnu', () {
      expect(parseFile(ParsedData(), '{oops'), isA<UnrecognizedFile>());
    });

    test('CSV → entrées comptées', () {
      final parsed = ParsedData();
      final result =
          parseFile(parsed, 'show,season,episode\nDark,1,1\nDark,1,2\n');
      expect((result as EntriesAdded).count, 2);
    });
  });
}
