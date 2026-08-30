import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../tmdb/tvdb.dart';

/// Résultat d'une passe de synchronisation : de quoi dire à l'utilisateur que
/// le rafraîchissement n'a rien pu ramener, sans faire remonter d'exception.
class SyncOutcome {
  const SyncOutcome({required this.synced, required this.failed});

  /// Séries dont le cache d'épisodes a bien été mis à jour.
  final int synced;

  /// Séries dont la synchro a échoué (réseau, API indisponible…).
  final int failed;

  bool get hasFailures => failed > 0;

  static const none = SyncOutcome(synced: 0, failed: 0);
}

/// Synchronise le cache d'épisodes d'une série depuis TheTVDB (saisons > 0)
/// et met à jour ses compteurs (progression). Idempotent.
///
/// [force] contourne le cache mémoire du client : sans lui, un rafraîchissement
/// manuel relirait la liste déjà en mémoire et ne verrait jamais un épisode
/// ajouté depuis le premier chargement.
Future<void> syncShowEpisodes(
  AppDatabase db,
  TvdbClient tvdb,
  Show show, {
  bool force = false,
}) async {
  final eps = await tvdb.seriesEpisodes(show.id, force: force);
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
  // Uniquement après des écritures réussies : une date posée sur un échec
  // ferait taire la série pendant toute la durée du TTL.
  await db.markShowSynced(show.id, DateTime.now());
}

DateTime? _parseDate(Object? raw) =>
    (raw is String && raw.isNotEmpty) ? DateTime.tryParse(raw) : null;

/// Synchro en cours, s'il y en a une. Deux passes simultanées écriraient les
/// mêmes lignes et doubleraient les appels réseau : un appel qui arrive pendant
/// une passe s'enchaîne derrière elle au lieu de la doubler.
Future<SyncOutcome>? _inFlight;

/// Synchronise les séries dont le cache est absent ou périmé (24 h par défaut).
/// Ne lève jamais : les échecs sont comptés dans le [SyncOutcome] rendu.
///
/// [force] ignore le TTL et le cache mémoire — c'est le mode du « tirer pour
/// rafraîchir », qui doit réellement aller chercher les nouveautés.
Future<SyncOutcome> syncStaleShows(
  AppDatabase db,
  TvdbClient tvdb, {
  Duration maxAge = const Duration(hours: 24),
  bool force = false,
  Future<void> Function()? throttle,
}) {
  Future<SyncOutcome> run() => _syncStaleShows(
        db,
        tvdb,
        maxAge: maxAge,
        force: force,
        throttle: throttle,
      );

  final pending = _inFlight;
  final next = pending == null
      ? run()
      : pending.then((_) => run(), onError: (_) => run());
  _inFlight = next;
  next.whenComplete(() {
    if (identical(_inFlight, next)) _inFlight = null;
  });
  return next;
}

/// Remet le verrou à zéro entre deux tests (l'état est global au processus).
@visibleForTesting
void resetSyncLock() => _inFlight = null;

Future<SyncOutcome> _syncStaleShows(
  AppDatabase db,
  TvdbClient tvdb, {
  required Duration maxAge,
  required bool force,
  Future<void> Function()? throttle,
}) async {
  if (tvdb.apiKey.isEmpty) return SyncOutcome.none;
  final now = DateTime.now();
  final shows = await db.allShows();
  var synced = 0, failed = 0;
  for (final show in shows) {
    final syncedAt = show.episodesSyncedAt;
    if (!force && syncedAt != null && now.difference(syncedAt) < maxAge) {
      continue;
    }
    try {
      await syncShowEpisodes(db, tvdb, show, force: force);
      synced++;
    } catch (e, st) {
      // Mode dégradé : la série garde son cache précédent et sera retentée.
      // Tracé, parce qu'une synchro qui échoue en silence est indébogable.
      failed++;
      debugPrint('Synchro de « ${show.name} » (${show.id}) échouée : $e\n$st');
    }
    await throttle?.call();
  }
  return SyncOutcome(synced: synced, failed: failed);
}
