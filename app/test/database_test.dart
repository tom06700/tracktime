import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'la progression compare les mêmes épisodes et conserve tout l’historique',
    () async {
      await db.upsertShow(
        ShowsCompanion.insert(
          id: const Value(1),
          name: 'One Piece',
          totalEpisodes: const Value(2),
        ),
      );
      await db.upsertEpisodes([
        EpisodesCompanion.insert(showId: 1, season: 1, episode: 1),
        EpisodesCompanion.insert(showId: 1, season: 1, episode: 2),
      ]);
      await db.setEpisodeWatched(1, 1, 1);
      await db.setEpisodeWatched(1, 0, 1);
      await db.setEpisodeWatched(1, 0, 2);
      await db.setEpisodeWatched(1, 99, 1); // ancienne numérotation importée
      final progress = (await db.watchShowsWithProgress().first).single;
      expect(progress.watchedCount, 4); // historique intact
      expect(progress.progress, .5); // un épisode du catalogue sur deux
      expect(progress.isDone, false);
      final stats = await db.watchStats().first;
      expect(stats.episodeCount, 4);
      expect(stats.doneShowCount, 0);
    },
  );

  test('setSeasonWatched coche puis décoche toute une saison', () async {
    await db.setSeasonWatched(1, 1, [1, 2, 3], true);
    var keys = await db.watchWatchedKeys(1).first;
    expect(keys, {'S1E1', 'S1E2', 'S1E3'});

    // Une autre saison n'est pas touchée.
    await db.setEpisodeWatched(1, 2, 1);
    await db.setSeasonWatched(1, 1, [1, 2, 3], false);
    keys = await db.watchWatchedKeys(1).first;
    expect(keys, {'S2E1'});
  });

  test('watchWatchedKeys ne renvoie que la série demandée', () async {
    await db.setEpisodeWatched(1, 1, 1);
    await db.setEpisodeWatched(2, 1, 1);
    expect(await db.watchWatchedKeys(1).first, {'S1E1'});
  });
}
