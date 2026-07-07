import '../db/database.dart';
import '../movies/sync.dart';
import '../tmdb/add.dart';
import '../tmdb/tmdb.dart';

/// Rattrape les métadonnées manquantes (séries : genres ; films : genres +
/// date de sortie) pour les titres ajoutés avant ces colonnes ou importés.
/// Une requête TMDB par titre, en tâche de fond et throttlé. Silencieux sans
/// clé API ou en cas d'erreur réseau (mode dégradé).
Future<void> backfillGenres(
  AppDatabase db,
  TmdbClient tmdb, {
  Future<void> Function()? throttle,
}) async {
  if (tmdb.apiKey.isEmpty) return;

  for (final show in await db.allShows()) {
    if (show.genres != null) continue;
    try {
      final g = genresOf(await tmdb.tvDetails(show.id));
      if (g != null) await db.setShowGenres(show.id, g);
    } catch (_) {
      // Ignoré : l'univers se construit avec ce qu'on a déjà.
    }
    await throttle?.call();
  }

  await backfillMovieMeta(db, tmdb, throttle: throttle);
}
