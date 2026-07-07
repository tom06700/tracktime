import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/movies/feed.dart';

Movie _movie(
  int id, {
  DateTime? watchedAt,
  DateTime? addedAt,
  DateTime? releaseDate,
}) =>
    Movie(
      id: id,
      title: 'M$id',
      runtime: 120,
      addedAt: addedAt ?? DateTime(2026, 7, 1),
      watchedAt: watchedAt,
      releaseDate: releaseDate,
    );

void main() {
  final now = DateTime(2026, 7, 7);

  test('buildMovieFeed : historique trié, à voir récent, oubliés séparés', () {
    final movies = [
      // Vus (historique), plus récent d'abord.
      _movie(1, watchedAt: DateTime(2026, 6, 10)),
      _movie(2, watchedAt: DateTime(2026, 7, 5)),
      // À voir, sortis, ajout récent → toWatch.
      _movie(3, addedAt: DateTime(2026, 7, 6), releaseDate: DateTime(2020, 1, 1)),
      // À voir, sorti, ajouté il y a longtemps → stale.
      _movie(4, addedAt: DateTime(2026, 1, 1), releaseDate: DateTime(2019, 1, 1)),
      // Pas encore sorti → ni à voir ni oublié (va dans À venir).
      _movie(5, addedAt: DateTime(2026, 7, 6), releaseDate: DateTime(2026, 12, 1)),
    ];

    final feed = buildMovieFeed(movies: movies, now: now);

    expect(feed.history.map((m) => m.id), [2, 1]); // plus récent d'abord
    expect(feed.toWatch.map((m) => m.id), [3]);
    expect(feed.stale.map((m) => m.id), [4]);
  });

  test('buildMovieFeed : film sans date de sortie reste « à voir »', () {
    final feed = buildMovieFeed(
      movies: [_movie(1, addedAt: now, releaseDate: null)],
      now: now,
    );
    expect(feed.toWatch.map((m) => m.id), [1]);
  });

  test('buildUpcomingMovies : non sortis, du plus proche au plus loin', () {
    final movies = [
      _movie(1, releaseDate: DateTime(2026, 9, 1)),
      _movie(2, releaseDate: DateTime(2026, 8, 1)),
      _movie(3, releaseDate: DateTime(2020, 1, 1)), // déjà sorti → exclu
      _movie(4, watchedAt: now, releaseDate: DateTime(2027, 1, 1)), // vu → exclu
    ];
    final up = buildUpcomingMovies(movies: movies, now: now);
    expect(up.map((u) => u.movie.id), [2, 1]);
    expect(up.first.daysFrom(now), DateTime(2026, 8, 1).difference(now).inDays);
  });
}
