import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

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
