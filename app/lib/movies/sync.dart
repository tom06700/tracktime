import '../db/database.dart';
import '../tmdb/add.dart';
import '../tmdb/tmdb.dart';

/// Rattrape les métadonnées manquantes des films (genres, date de sortie) :
/// films ajoutés avant l'arrivée de ces colonnes ou importés. Une requête
/// TMDB par titre, en tâche de fond et throttlée. Silencieux sans clé API
/// ou en cas d'erreur réseau (mode dégradé).
Future<void> backfillMovieMeta(
  AppDatabase db,
  TmdbClient tmdb, {
  Future<void> Function()? throttle,
}) async {
  if (tmdb.apiKey.isEmpty) return;

  for (final movie in await db.allMovies()) {
    if (movie.genres != null && movie.releaseDate != null) continue;
    try {
      final d = await tmdb.movieDetails(movie.id);
      if (movie.genres == null) {
        final g = genresOf(d);
        if (g != null) await db.setMovieGenres(movie.id, g);
      }
      if (movie.releaseDate == null) {
        final r = releaseDateOf(d);
        if (r != null) await db.setMovieReleaseDate(movie.id, r);
      }
    } catch (_) {
      // Ignoré : le fil se construit avec ce qu'on a déjà.
    }
    await throttle?.call();
  }
}
