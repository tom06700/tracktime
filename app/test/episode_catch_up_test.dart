import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/db/episode_catch_up.dart';

void main() {
  late AppDatabase db;
  late EpisodeCatchUp service;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = EpisodeCatchUp(db);
    await db
        .upsertShow(ShowsCompanion.insert(id: const Value(1), name: 'Série'));
    await db.upsertEpisodes([
      for (final k in [(0, 1), (1, 1), (1, 3), (2, 1), (2, 7), (2, 9)])
        EpisodesCompanion.insert(showId: 1, season: k.$1, episode: k.$2)
    ]);
  });
  tearDown(() => db.close());

  test('lot exact inter-saisons, spéciaux et trous, ancienne date conservée',
      () async {
    final old = DateTime(2020, 1, 2);
    await db.setEpisodeWatched(1, 1, 1, at: old);
    final plan = await service.prepare(1, 2, 7);
    expect(plan.keys, [
      (season: 0, episode: 1),
      (season: 1, episode: 3),
      (season: 2, episode: 1),
      (season: 2, episode: 7)
    ]);
    final receipt = await service.apply(plan);
    expect(receipt.count, 4);
    expect((await db.watchWatchedEpisode(1, 1, 1).first)!.watchedAt, old);
    expect(await db.watchWatchedEpisode(1, 2, 9).first, isNull);
    await service.undo(receipt);
    expect(await db.watchWatchedKeys(1).first, {'S1E1'});
    expect((await db.watchWatchedEpisode(1, 1, 1).first)!.watchedAt, old);
  });
  test('un catalogue modifié après confirmation rejette tout le lot', () async {
    final plan = await service.prepare(1, 2, 7);
    await db.upsertEpisodes(
        [EpisodesCompanion.insert(showId: 1, season: 1, episode: 2)]);
    await expectLater(service.apply(plan), throwsA(isA<CatchUpChanged>()));
    expect(await db.allWatchedEpisodes(), isEmpty);
  });
  test('une nouvelle coche après confirmation rejette tout le lot', () async {
    final plan = await service.prepare(1, 2, 7);
    await db.setEpisodeWatched(1, 2, 7);
    await expectLater(service.apply(plan), throwsA(isA<CatchUpChanged>()));
    expect(await db.watchWatchedKeys(1).first, {'S2E7'});
  });
  test(
      'annulation préserve une recoche à la même date et une modification directe',
      () async {
    final receipt = await service.apply(await service.prepare(1, 2, 7));
    final old = (await db.watchWatchedEpisode(1, 2, 7).first)!.watchedAt;
    await db.setEpisodeUnwatched(1, 2, 7);
    await db.setEpisodeWatched(1, 2, 7, at: old);
    await (db.update(db.watchedEpisodes)
          ..where((e) => e.season.equals(1) & e.episode.equals(3)))
        .write(WatchedEpisodesCompanion(watchedAt: Value(DateTime(2021))));
    await db.setEpisodeWatched(1, 2, 9);
    expect(await service.undo(receipt), 3);
    expect(await db.watchWatchedKeys(1).first, {'S1E3', 'S2E7', 'S2E9'});
    expect(await service.undo(receipt), 0);
  });
  test('deux lots ne partagent pas leur annulation', () async {
    final first = await service.apply(await service.prepare(1, 1, 3));
    final second = await service.apply(await service.prepare(1, 2, 9));
    await service.undo(first);
    expect(await db.watchWatchedKeys(1).first, {'S2E1', 'S2E7', 'S2E9'});
    await service.undo(second);
    expect(await db.allWatchedEpisodes(), isEmpty);
  });
}
