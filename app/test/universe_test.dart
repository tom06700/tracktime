import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/profile/universe.dart';

WatchStats _stats({
  int episodeCount = 0,
  int tvMinutes = 0,
  int moviesSeen = 0,
  int movieMinutes = 0,
  int showCount = 0,
  int doneShowCount = 0,
  int watchlistCount = 0,
}) =>
    WatchStats(
      episodeCount: episodeCount,
      tvMinutes: tvMinutes,
      moviesSeen: moviesSeen,
      movieMinutes: movieMinutes,
      showCount: showCount,
      doneShowCount: doneShowCount,
      watchlistCount: watchlistCount,
    );

void main() {
  test('genreColor : mots-clés FR mappés sur des teintes stables', () {
    expect(genreColor('Science-Fiction'), genreColor('science-fiction'));
    expect(genreColor('Drame'), isNot(genreColor('Comédie')));
  });

  test('buildUniverse : pondère les genres par le temps passé', () {
    final now = DateTime(2026, 7, 7);
    final shows = [
      ShowWithProgress(
        Show(
          id: 1,
          name: 'A',
          runtime: 40,
          addedAt: now,
          genres: 'Drame|Crime',
        ),
        10,
      ),
      ShowWithProgress(
        Show(
          id: 2,
          name: 'B',
          runtime: 40,
          addedAt: now,
          genres: 'Comédie',
        ),
        2,
      ),
    ];
    final movies = [
      Movie(
        id: 100,
        title: 'M',
        runtime: 120,
        addedAt: now,
        watchedAt: now,
        genres: 'Drame',
      ),
    ];

    final watched = [
      WatchedEpisode(
          showId: 1, season: 1, episode: 1, watchedAt: DateTime(2026, 7, 1)),
      WatchedEpisode(
          showId: 1, season: 1, episode: 2, watchedAt: DateTime(2026, 7, 5)),
      WatchedEpisode(
          showId: 2, season: 1, episode: 1, watchedAt: DateTime(2026, 6, 20)),
    ];

    final u = buildUniverse(
      shows: shows,
      watched: watched,
      movies: movies,
      profileName: 'Thomas',
      now: now,
      stats: _stats(showCount: 2, episodeCount: 12, doneShowCount: 0),
    );

    expect(u.hasGenres, isTrue);
    // A = 10 épisodes / 2 genres = 5 chacun ; film Drame = 2.5. Drame = 7.5.
    expect(u.genres.first.name, 'Drame');
    expect(u.palette, isNotEmpty);
    expect(u.badges, hasLength(6));
    expect(u.seed, greaterThan(0));
    // Dernière coche par série : la plus récente l'emporte.
    expect(u.lastActivityByShow[1], DateTime(2026, 7, 5));
    expect(u.lastActivityByShow[2], DateTime(2026, 6, 20));
    // Détail par jour pour la heatmap.
    expect(u.labelsByDay[DateTime(2026, 7, 1)], ['A · S1E1']);
    expect(u.labelsByDay[DateTime(2026, 7, 7)], ['M · film']);
  });

  test('buildUniverse : streaks courant (grâce d\'un jour) et record', () {
    final now = DateTime(2026, 7, 7, 21);
    WatchedEpisode w(int ep, DateTime at) =>
        WatchedEpisode(showId: 1, season: 1, episode: ep, watchedAt: at);

    final u = buildUniverse(
      shows: const [],
      watched: [
        // Record : 4 jours consécutifs en juin.
        w(1, DateTime(2026, 6, 1)),
        w(2, DateTime(2026, 6, 2)),
        w(3, DateTime(2026, 6, 3)),
        w(4, DateTime(2026, 6, 4)),
        // En cours : hier et avant-hier (rien aujourd'hui → grâce).
        w(5, DateTime(2026, 7, 5, 20)),
        w(6, DateTime(2026, 7, 6, 22)),
      ],
      movies: const [],
      profileName: 'T',
      now: now,
      stats: _stats(episodeCount: 6),
    );

    expect(u.bestStreak, 4);
    expect(u.currentStreak, 2);
  });

  test('buildUniverse : affiche phare par genre (série la plus vue)', () {
    final now = DateTime(2026, 7, 7);
    final u = buildUniverse(
      shows: [
        ShowWithProgress(
          Show(
              id: 1,
              name: 'A',
              runtime: 40,
              addedAt: now,
              poster: '/a.jpg',
              genres: 'Drame'),
          10,
        ),
        ShowWithProgress(
          Show(
              id: 2,
              name: 'B',
              runtime: 40,
              addedAt: now,
              poster: '/b.jpg',
              genres: 'Drame|Comédie'),
          3,
        ),
      ],
      watched: const [],
      movies: const [],
      profileName: 'T',
      now: now,
      stats: _stats(showCount: 2),
    );

    expect(u.posterByGenre['Drame'], '/a.jpg'); // la plus regardée gagne
    expect(u.posterByGenre['Comédie'], '/b.jpg');
  });

  test('buildUniverse : univers vide → palette par défaut, pas de genres', () {
    final now = DateTime(2026, 7, 7);
    final u = buildUniverse(
      shows: const [],
      watched: const [],
      movies: const [],
      profileName: '',
      now: now,
      stats: _stats(),
    );
    expect(u.hasGenres, isFalse);
    expect(u.genres, isEmpty);
    expect(u.palette, isNotEmpty); // repli cosmos froid
    expect(u.records, isEmpty);
    expect(u.lastActivityByShow, isEmpty);
  });
}
