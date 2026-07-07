import '../db/database.dart';
import '../tmdb/add.dart';
import '../tmdb/tmdb.dart';

/// Rattrape les genres manquants : les séries et films ajoutés avant
/// l'arrivée de la colonne `genres` (ou importés) ont `genres == null`.
/// On interroge TMDB une fois par titre, en tâche de fond et throttlé.
/// Silencieux sans clé API ou en cas d'erreur réseau (mode dégradé).
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

  for (final movie in await db.allMovies()) {
    if (movie.genres != null) continue;
    try {
      final g = genresOf(await tmdb.movieDetails(movie.id));
      if (g != null) await db.setMovieGenres(movie.id, g);
    } catch (_) {
      // Ignoré.
    }
    await throttle?.call();
  }
}
