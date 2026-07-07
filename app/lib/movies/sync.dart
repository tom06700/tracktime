import '../db/database.dart';
import '../tmdb/tvdb.dart';

/// Rattrape les métadonnées manquantes des films (genres, date de sortie)
/// depuis TheTVDB. Une requête par titre, throttlée. Silencieux sans clé ou
/// en cas d'erreur réseau.
Future<void> backfillMovieMeta(
  AppDatabase db,
  TvdbClient tvdb, {
  Future<void> Function()? throttle,
}) async {
  if (tvdb.apiKey.isEmpty) return;

  for (final movie in await db.allMovies()) {
    if (movie.genres != null && movie.releaseDate != null) continue;
    try {
      final d = await tvdb.movieExtended(movie.id);
      if (movie.genres == null) {
        final g = TvdbClient.genresOf(d);
        if (g != null) await db.setMovieGenres(movie.id, g);
      }
      if (movie.releaseDate == null) {
        final r = TvdbClient.releaseDateOf(d);
        if (r != null) await db.setMovieReleaseDate(movie.id, r);
      }
    } catch (_) {
      // Ignoré.
    }
    await throttle?.call();
  }
}
