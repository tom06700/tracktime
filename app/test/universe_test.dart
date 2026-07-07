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

    final u = buildUniverse(
      shows: shows,
      watched: const [],
      movies: movies,
      profileName: 'Thomas',
      now: now,
      stats: _stats(showCount: 2, episodeCount: 12, doneShowCount: 0),
    );

    expect(u.hasGenres, isTrue);
    // Drame domine (5 depuis A + 2.5 depuis le film) devant Crime (5) ? Non :
    // A = 10 épisodes / 2 genres = 5 chacun ; film Drame = 2.5. Drame = 7.5.
    expect(u.genres.first.name, 'Drame');
    expect(u.palette, isNotEmpty);
    expect(u.badges, hasLength(6));
    expect(u.seed, greaterThan(0));
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
  });
}
