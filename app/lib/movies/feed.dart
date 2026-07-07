import '../db/database.dart';

/// Fil de la page Films, à la manière de la page Séries : historique des films
/// vus en haut, watchlist « à voir » au milieu, films oubliés depuis longtemps
/// en bas. Les films pas encore sortis vont dans l'onglet « À venir ».
class MovieFeed {
  const MovieFeed({
    required this.history,
    required this.toWatch,
    required this.stale,
  });

  /// Films vus, du plus récent au plus ancien (grisés, comme l'historique
  /// des séries).
  final List<Movie> history;

  /// Films à voir déjà sortis, activité (ajout) récente d'abord.
  final List<Movie> toWatch;

  /// Films à voir sortis mais dans la liste depuis longtemps.
  final List<Movie> stale;

  bool get isEmpty => history.isEmpty && toWatch.isEmpty && stale.isEmpty;
}

/// Film pas encore sorti de la watchlist (onglet « À venir »).
class UpcomingMovie {
  const UpcomingMovie({required this.movie, required this.releaseDate});

  final Movie movie;
  final DateTime releaseDate;

  /// Nombre de jours (calendaires) avant la sortie.
  int daysFrom(DateTime now) {
    final a = DateTime(releaseDate.year, releaseDate.month, releaseDate.day);
    final n = DateTime(now.year, now.month, now.day);
    return a.difference(n).inDays;
  }
}

bool _released(Movie m, DateTime now) =>
    m.releaseDate == null || !m.releaseDate!.isAfter(now);

/// Construit le fil Films depuis l'état local. Pur et déterministe.
MovieFeed buildMovieFeed({
  required List<Movie> movies,
  required DateTime now,
  Duration staleAfter = const Duration(days: 30),
  int historyLimit = 8,
}) {
  // ---- Historique : films vus, plus récents d'abord ----
  final history = movies.where((m) => m.watchedAt != null).toList()
    ..sort((a, b) => b.watchedAt!.compareTo(a.watchedAt!));

  // ---- À voir : watchlist déjà sortie, ajout récent d'abord ----
  final watchlist = movies
      .where((m) => m.watchedAt == null && _released(m, now))
      .toList()
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  final threshold = now.subtract(staleAfter);
  final toWatch = <Movie>[];
  final stale = <Movie>[];
  for (final m in watchlist) {
    (m.addedAt.isBefore(threshold) ? stale : toWatch).add(m);
  }

  return MovieFeed(
    history: history.take(historyLimit).toList(),
    toWatch: toWatch,
    stale: stale,
  );
}

/// Films de la watchlist pas encore sortis, du plus proche au plus loin.
List<UpcomingMovie> buildUpcomingMovies({
  required List<Movie> movies,
  required DateTime now,
}) {
  final list = [
    for (final m in movies)
      if (m.watchedAt == null &&
          m.releaseDate != null &&
          m.releaseDate!.isAfter(now))
        UpcomingMovie(movie: m, releaseDate: m.releaseDate!),
  ]..sort((a, b) => a.releaseDate.compareTo(b.releaseDate));
  return list;
}
