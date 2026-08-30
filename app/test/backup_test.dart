import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/backup/backup.dart';
import 'package:tracktime/backup/backup_format.dart';
import 'package:tracktime/backup/restore.dart';
import 'package:tracktime/db/database.dart';

AppDatabase _db() => AppDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
  ),
);

void main() {
  late AppDatabase db;
  setUp(() => db = _db());
  tearDown(() => db.close());

  test('backupFileName est daté', () {
    expect(
      backupFileName(DateTime(2026, 7, 6)),
      'nitrate-sauvegarde-2026-07-06.json',
    );
    expect(
      backupFileName(DateTime(2026, 12, 31)),
      'nitrate-sauvegarde-2026-12-31.json',
    );
  });

  test('la sauvegarde dit sa version, son app et son fournisseur', () async {
    await db.upsertShow(
      ShowsCompanion.insert(id: const Value(81797), name: 'One Piece'),
    );
    await db.setEpisodeWatched(81797, 1, 1, at: DateTime.utc(2026, 1, 2));
    await db.upsertMovie(
      MoviesCompanion.insert(id: const Value(1406), title: 'Dune'),
    );

    final backup = await buildBackup(db, now: DateTime.utc(2026, 8, 30, 20));

    expect(backup['schemaVersion'], 2);
    expect(backup['app'], 'nitrate');
    expect(backup['metadataProvider'], 'thetvdb');
    expect(backup['exportedAt'], '2026-08-30T20:00:00.000Z');

    final show = (backup['shows'] as List).single as Map;
    expect(show['id'], 81797);
    expect(show['provider'], 'thetvdb');
    expect(show['name'], 'One Piece');
    expect((show['watched'] as Map).keys, ['S1E1']);

    final movie = (backup['movies'] as List).single as Map;
    expect(movie['id'], 1406);
    expect(movie['provider'], 'thetvdb');
    expect(movie['title'], 'Dune');
  });

  test('plus aucune clé « tmdb » dans le fichier', () async {
    final backup = await buildBackup(db);
    expect(backup.containsKey('key'), isFalse);
    expect(backup.keys.any((k) => k.toLowerCase().contains('tmdb')), isFalse);
  });

  test(
    'aller-retour : séries, films, progression et dates préservés',
    () async {
      await db.upsertShow(
        ShowsCompanion.insert(
          id: const Value(70523),
          name: 'Dark',
          totalEpisodes: const Value(26),
          seasonCount: const Value(3),
          runtime: const Value(53),
          status: const Value('Ended'),
        ),
      );
      await db.setEpisodeWatched(70523, 1, 1, at: DateTime.utc(2019, 12, 1));
      await db.setEpisodeWatched(70523, 1, 2, at: DateTime.utc(2019, 12, 2));
      await db.upsertMovie(
        MoviesCompanion.insert(
          id: const Value(496243),
          title: 'Parasite',
          watchedAt: Value(DateTime.utc(2022, 1, 1)),
        ),
      );

      final file = await buildBackup(db);

      // Relu dans une base vierge, sans le moindre appel réseau.
      final db2 = _db();
      addTearDown(db2.close);
      final parsed = parseBackupFile(file);
      expect(parsed, isA<NitrateBackup>());
      final report = await restoreNitrateBackup(db2, parsed as NitrateBackup);

      expect(report.importedShows, 1);
      expect(report.importedMovies, 1);
      expect(report.importedEpisodes, 2);
      expect(report.errors, isEmpty);

      final show = await db2.showById(70523);
      expect(show!.name, 'Dark');
      expect(show.totalEpisodes, 26);
      expect(show.seasonCount, 3);
      expect(show.status, 'Ended');

      final eps = await db2.watchEpisodesOf(70523).first;
      expect(eps, hasLength(2));
      // drift relit les dates en heure locale : on compare des instants.
      expect(
        eps
            .firstWhere((e) => e.episode == 1)
            .watchedAt
            .isAtSameMomentAs(DateTime.utc(2019, 12, 1)),
        isTrue,
      );

      expect(
        (await db2.movieById(
          496243,
        ))!.watchedAt!.isAtSameMomentAs(DateTime.utc(2022, 1, 1)),
        isTrue,
      );
    },
  );
}
