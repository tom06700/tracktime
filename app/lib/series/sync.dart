import 'package:drift/drift.dart';

import '../db/database.dart';
import '../tmdb/tmdb.dart';

/// Synchronise le cache d'épisodes d'une série depuis TMDB (toutes les
/// saisons > 0). Idempotent : `insertAllOnConflictUpdate`.
Future<void> syncShowEpisodes(
    AppDatabase db, TmdbClient tmdb, Show show) async {
  final seasonCount = show.seasonCount ?? 1;
  final rows = <EpisodesCompanion>[];
  for (var n = 1; n <= seasonCount; n++) {
    final j = await tmdb.season(show.id, n);
    for (final e in (j['episodes'] as List? ?? const [])) {
      if (e is! Map) continue;
      final epNum = (e['episode_number'] as num?)?.toInt();
      if (epNum == null) continue;
      rows.add(EpisodesCompanion.insert(
        showId: show.id,
        season: n,
        episode: epNum,
        name: Value(e['name'] as String?),
        still: Value(e['still_path'] as String?),
        airDate: Value(_parseDate(e['air_date'])),
      ));
    }
  }
  if (rows.isNotEmpty) await db.upsertEpisodes(rows);
  await db.markShowSynced(show.id, DateTime.now());
}

DateTime? _parseDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

/// Synchronise en tâche de fond les séries dont le cache est absent ou périmé.
/// Silencieux en l'absence de clé API ou en cas d'erreur réseau (le fil
/// retombe alors sur l'estimation par coches).
Future<void> syncStaleShows(
  AppDatabase db,
  TmdbClient tmdb, {
  Duration maxAge = const Duration(days: 7),
  Future<void> Function()? throttle,
}) async {
  if (tmdb.apiKey.isEmpty) return;
  final now = DateTime.now();
  final shows = await db.allShows();
  for (final show in shows) {
    final synced = show.episodesSyncedAt;
    if (synced != null && now.difference(synced) < maxAge) continue;
    try {
      await syncShowEpisodes(db, tmdb, show);
    } catch (_) {
      // On ignore : le fil fonctionne en mode dégradé.
    }
    await throttle?.call();
  }
}
