import 'dart:math';
import 'package:drift/drift.dart';
import 'database.dart';

typedef CatchUpKey = ({int season, int episode});

class CatchUpPlan {
  CatchUpPlan(this.showId, this.season, this.episode, Iterable<CatchUpKey> keys)
      : keys = List.unmodifiable(keys);
  final int showId, season, episode;
  final List<CatchUpKey> keys;
}

class CatchUpReceipt {
  const CatchUpReceipt(this.token, this.count);
  final String token;
  final int count;
}

class CatchUpChanged implements Exception {}

/// Session-scoped undo ownership, separate from the user's watch timestamps.
/// TEMP triggers invalidate ownership even after raw SQL updates or a delete /
/// re-add in the same second. No persistent schema or history is rewritten.
class EpisodeCatchUp {
  EpisodeCatchUp(this.db);
  final AppDatabase db;

  Future<CatchUpPlan> prepare(int showId, int season, int episode) =>
      db.transaction(() async {
        final eps = await (db.select(db.episodes)
              ..where((e) => e.showId.equals(showId)))
            .get();
        final watched = await (db.select(db.watchedEpisodes)
              ..where((e) => e.showId.equals(showId)))
            .get();
        final seen = {
          for (final e in watched) (season: e.season, episode: e.episode)
        };
        final keys = eps
            .where((e) =>
                e.season < season ||
                (e.season == season && e.episode <= episode))
            .map((e) => (season: e.season, episode: e.episode))
            .where((e) => !seen.contains(e))
            .toList()
          ..sort((a, b) => a.season == b.season
              ? a.episode.compareTo(b.episode)
              : a.season.compareTo(b.season));
        return CatchUpPlan(showId, season, episode, keys);
      });

  Future<void> _ownership() async {
    await db.customStatement(
        '''CREATE TEMP TABLE IF NOT EXISTS episode_watch_operations
      (show_id INTEGER, season INTEGER, episode INTEGER, token TEXT NOT NULL,
      PRIMARY KEY(show_id, season, episode))''');
    for (final event in ['DELETE', 'UPDATE']) {
      await db.customStatement(
          '''CREATE TEMP TRIGGER IF NOT EXISTS episode_undo_${event.toLowerCase()}
        AFTER $event ON main.watched_episodes BEGIN
        DELETE FROM episode_watch_operations WHERE show_id = OLD.show_id
        AND season = OLD.season AND episode = OLD.episode; END''');
    }
    await db.customStatement(
        '''CREATE TEMP TRIGGER IF NOT EXISTS episode_undo_insert
      AFTER INSERT ON main.watched_episodes BEGIN
      DELETE FROM episode_watch_operations WHERE show_id = NEW.show_id
      AND season = NEW.season AND episode = NEW.episode; END''');
  }

  Future<CatchUpReceipt> apply(CatchUpPlan plan) => db.transaction(() async {
        final current = await prepare(plan.showId, plan.season, plan.episode);
        if (current.keys.length != plan.keys.length ||
            !current.keys.toSet().containsAll(plan.keys)) {
          throw CatchUpChanged();
        }
        await _ownership();
        final random = Random.secure();
        final token = List.generate(24,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
        for (final key in plan.keys) {
          await db.setEpisodeWatched(plan.showId, key.season, key.episode);
          await db.customStatement(
              'INSERT INTO episode_watch_operations VALUES (?, ?, ?, ?)',
              [plan.showId, key.season, key.episode, token]);
        }
        return CatchUpReceipt(token, plan.keys.length);
      });

  Future<int> undo(CatchUpReceipt receipt) => db.transaction(() async {
        await _ownership();
        return db.customUpdate('''DELETE FROM watched_episodes WHERE EXISTS
      (SELECT 1 FROM episode_watch_operations o WHERE o.token = ?
      AND o.show_id = watched_episodes.show_id AND o.season = watched_episodes.season
      AND o.episode = watched_episodes.episode)''',
            variables: [Variable.withString(receipt.token)],
            updates: {db.watchedEpisodes});
      });
}
