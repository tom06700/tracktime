import 'package:drift/drift.dart';

import '../db/database.dart';
import '../tmdb/tvdb.dart';

/// Synchronise le cache d'épisodes d'une série depuis TheTVDB (saisons > 0)
/// et met à jour ses compteurs (progression). Idempotent.
Future<void> syncShowEpisodes(
    AppDatabase db, TvdbClient tvdb, Show show) async {
  final eps = await tvdb.seriesEpisodes(show.id);
  final rows = <EpisodesCompanion>[];
  var maxSeason = 0, total = 0;
  for (final e in eps) {
    final season = e['season'] as int;
    if (season < 1) continue; // on ignore les spéciaux (saison 0)
    final number = e['episode'] as int;
    rows.add(EpisodesCompanion.insert(
      showId: show.id,
      season: season,
      episode: number,
      name: Value(e['name'] as String?),
      still: Value(e['image'] as String?),
      airDate: Value(_parseDate(e['aired'])),
    ));
    if (season > maxSeason) maxSeason = season;
    total++;
  }
  if (rows.isNotEmpty) await db.upsertEpisodes(rows);
  if (total > 0) {
    await db.updateShowCounts(show.id, total: total, seasons: maxSeason);
  }
  await db.markShowSynced(show.id, DateTime.now());
}

DateTime? _parseDate(Object? raw) =>
    (raw is String && raw.isNotEmpty) ? DateTime.tryParse(raw) : null;

/// Synchronise en tâche de fond les séries dont le cache est absent ou périmé.
/// Silencieux en l'absence de clé API ou en cas d'erreur réseau.
Future<void> syncStaleShows(
  AppDatabase db,
  TvdbClient tvdb, {
  Duration maxAge = const Duration(days: 7),
  Future<void> Function()? throttle,
}) async {
  if (tvdb.apiKey.isEmpty) return;
  final now = DateTime.now();
  final shows = await db.allShows();
  for (final show in shows) {
    final synced = show.episodesSyncedAt;
    if (synced != null && now.difference(synced) < maxAge) continue;
    try {
      await syncShowEpisodes(db, tvdb, show);
    } catch (_) {
      // Mode dégradé.
    }
    await throttle?.call();
  }
}
