import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/notifications/feed.dart';

void main() {
  final now = DateTime(2026, 9, 8, 16);
  Show show(int id, {DateTime? added}) => Show(
    id: id,
    name: 'Série $id',
    runtime: 42,
    addedAt: added ?? DateTime(2026, 8, 1),
  );
  Episode episode(int id, int number, DateTime? date, {int season = 1}) =>
      Episode(showId: id, season: season, episode: number, airDate: date);
  Movie movie(int id, DateTime? date, {DateTime? added}) => Movie(
    id: id,
    title: 'Film $id',
    runtime: 110,
    addedAt: added ?? DateTime(2026, 8, 1),
    releaseDate: date,
  );

  test(
    'vraies sorties récentes suivies, dates connues, sans futures ni spéciaux',
    () {
      final items = buildReleaseNotifications(
        shows: [show(1)],
        episodes: [
          episode(1, 1, DateTime(2026, 9, 8)),
          episode(1, 2, DateTime(2026, 9, 9)),
          episode(1, 3, null),
          episode(2, 1, now),
          episode(1, 4, now, season: 0),
          episode(1, 5, DateTime(2026, 7, 1)),
        ],
        movies: [
          movie(7, DateTime(2026, 9, 7)),
          movie(8, null),
          movie(9, DateTime(2026, 9, 9)),
        ],
        now: now,
      );
      expect(items.map((e) => e.id), ['episode:1:1:1', 'movie:7']);
      expect(items.first.location, '/episode/1/1/1');
      expect(items.last.location, '/movie/7');
    },
  );
  test('ne transforme pas l’ajout d’une ancienne œuvre en nouvelle sortie', () {
    expect(
      buildReleaseNotifications(
        shows: [show(1, added: now)],
        episodes: [episode(1, 1, DateTime(2026, 9, 7))],
        movies: [movie(7, DateTime(2026, 9, 7), added: now)],
        now: now,
      ),
      isEmpty,
    );
  });
  test(
    'inclut aujourd’hui et conserve un identifiant stable après correction de date',
    () {
      final first = buildReleaseNotifications(
        shows: [show(1)],
        episodes: [episode(1, 1, now)],
        movies: [],
        now: now,
      ).single;
      final corrected = buildReleaseNotifications(
        shows: [show(1)],
        episodes: [episode(1, 1, now.subtract(const Duration(days: 1)))],
        movies: [],
        now: now,
      ).single;
      expect(first.id, corrected.id);
      expect(first.day, DateTime(2026, 9, 8));
    },
  );
}
