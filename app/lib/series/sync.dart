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

/// Passes en cours, suivies séparément selon leur mode. Deux appels de même
/// mode partagent la même opération : sérialiser ne suffisait pas, le second
/// repartait pour un aller-retour réseau complet.
Future<SyncOutcome>? _inFlightNormal;
Future<SyncOutcome>? _inFlightForce;

/// Synchronise les séries dont le cache est absent ou périmé (24 h par défaut).
/// Ne lève jamais : les échecs sont comptés dans le [SyncOutcome] rendu.
///
/// [force] ignore le TTL et le cache mémoire — c'est le mode du « tirer pour
/// rafraîchir », qui doit réellement aller chercher les nouveautés.
///
/// Trois règles, dans cet ordre :
/// - deux appels de même mode lancés ensemble partagent la même passe ;
/// - une passe normale demandée pendant une passe forcée se raccroche à elle,
///   qui fait déjà davantage ;
/// - une passe forcée demandée pendant une passe normale s'exécute vraiment,
///   mais après elle — un rafraîchissement manuel ne doit jamais être avalé
///   par la synchro d'arrière-plan, ni écrire en même temps qu'elle.
Future<SyncOutcome> syncStaleShows(
  AppDatabase db,
  TvdbClient tvdb, {
  Duration maxAge = const Duration(hours: 24),
  bool force = false,
  Future<void> Function()? throttle,
}) {
  final sameMode = force ? _inFlightForce : _inFlightNormal;
  if (sameMode != null) return sameMode;
  if (!force && _inFlightForce != null) return _inFlightForce!;

  Future<SyncOutcome> run() => _syncStaleShows(
        db,
        tvdb,
        maxAge: maxAge,
        force: force,
        throttle: throttle,
      );

  final before = force ? _inFlightNormal : null;
  final next = before == null
      ? run()
      : before.then((_) => run(), onError: (_) => run());

  if (force) {
    _inFlightForce = next;
  } else {
    _inFlightNormal = next;
  }
  next.whenComplete(() {
    if (force) {
      if (identical(_inFlightForce, next)) _inFlightForce = null;
    } else if (identical(_inFlightNormal, next)) {
      _inFlightNormal = null;
    }
  });
  return next;
}

/// Remet les verrous à zéro entre deux tests (l'état est global au processus).
@visibleForTesting
void resetSyncLock() {
  _inFlightNormal = null;
  _inFlightForce = null;
}

Future<SyncOutcome> _syncStaleShows(
  AppDatabase db,
  TvdbClient tvdb, {
  required Duration maxAge,
  required bool force,
  Future<void> Function()? throttle,
}) async {
  if (tvdb.apiKey.isEmpty) return SyncOutcome.none;
  final now = DateTime.now();
  final List<Show> shows;
  try {
    shows = await db.allShows();
  } catch (e, st) {
    // Cette fonction ne lève pas : ses appelants sont des gestes d'interface.
    debugPrint('Synchro : lecture des séries impossible : $e\n$st');
    return const SyncOutcome(synced: 0, failed: 1);
  }
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
