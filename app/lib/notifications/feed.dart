import '../db/database.dart';
import '../series/feed.dart' show calendarDay;

enum ReleaseKind { episode, movie }

class ReleaseNotification {
  const ReleaseNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.day,
    required this.location,
    this.poster,
    this.extra,
  });
  final String id, title, detail, location;
  final ReleaseKind kind;
  final DateTime day;
  final String? poster;
  final Object? extra;
}

/// Only dated releases since the work joined the collection; never guesses
/// streaming availability from a broadcast or theatrical release date.
List<ReleaseNotification> buildReleaseNotifications({
  required List<Show> shows,
  required List<Episode> episodes,
  required List<Movie> movies,
  required DateTime now,
}) {
  final today = calendarDay(now);
  final start = DateTime(today.year, today.month, today.day - 29);
  bool eligible(DateTime? date, DateTime added) =>
      date != null &&
      !calendarDay(date).isAfter(today) &&
      !calendarDay(date).isBefore(start) &&
      !calendarDay(date).isBefore(calendarDay(added));
  final followed = {for (final show in shows) show.id: show};
  final entries = <String, ReleaseNotification>{};
  for (final episode in episodes) {
    final show = followed[episode.showId];
    if (show == null ||
        episode.season <= 0 ||
        episode.episode <= 0 ||
        !eligible(episode.airDate, show.addedAt)) {
      continue;
    }
    final id = 'episode:${show.id}:${episode.season}:${episode.episode}';
    final code =
        'S${episode.season.toString().padLeft(2, '0')} · E${episode.episode.toString().padLeft(2, '0')}';
    entries[id] = ReleaseNotification(
      id: id,
      kind: ReleaseKind.episode,
      title: show.name,
      detail: episode.name?.trim().isNotEmpty == true
          ? '$code — ${episode.name}'
          : code,
      day: calendarDay(episode.airDate!),
      poster: show.poster,
      location: '/episode/${show.id}/${episode.season}/${episode.episode}',
      extra: {'name': show.name, 'poster': show.poster},
    );
  }
  for (final movie in movies) {
    if (!eligible(movie.releaseDate, movie.addedAt)) continue;
    final id = 'movie:${movie.id}';
    entries[id] = ReleaseNotification(
      id: id,
      kind: ReleaseKind.movie,
      title: movie.title,
      detail: 'Nouvelle sortie',
      day: calendarDay(movie.releaseDate!),
      poster: movie.poster,
      location: '/movie/${movie.id}',
      extra: movie.title,
    );
  }
  return entries.values.toList()..sort((a, b) {
    final date = b.day.compareTo(a.day);
    return date != 0 ? date : a.id.compareTo(b.id);
  });
}
