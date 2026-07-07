import '../db/database.dart';
import '../movies/sync.dart';
import '../tmdb/tvdb.dart';

/// Rattrape les métadonnées manquantes (séries : genres ; films : genres +
/// date de sortie) via TheTVDB, pour les titres ajoutés/importés sans elles.
/// Une requête par titre, throttlée. Silencieux sans clé ou erreur réseau.
Future<void> backfillGenres(
  AppDatabase db,
  TvdbClient tvdb, {
  Future<void> Function()? throttle,
}) async {
  if (tvdb.apiKey.isEmpty) return;

  for (final show in await db.allShows()) {
    if (show.genres != null) continue;
    try {
      final g = TvdbClient.genresOf(await tvdb.seriesExtended(show.id));
      if (g != null) await db.setShowGenres(show.id, g);
    } catch (_) {
      // Ignoré.
    }
    await throttle?.call();
  }

  await backfillMovieMeta(db, tvdb, throttle: throttle);
}
