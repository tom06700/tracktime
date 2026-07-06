import 'package:flutter_test/flutter_test.dart';
import 'package:tracktime/db/database.dart';
import 'package:tracktime/series/feed.dart';

Show _show(int id, String name, {int? total, DateTime? addedAt}) => Show(
      id: id,
      name: name,
      runtime: 42,
      totalEpisodes: total,
      addedAt: addedAt ?? DateTime(2026, 1, 1),
    );

ShowWithProgress _swp(Show s, int watched) => ShowWithProgress(s, watched);

Episode _ep(int show, int s, int e, {DateTime? air, String? name}) => Episode(
      showId: show,
      season: s,
      episode: e,
      name: name,
      airDate: air,
    );

WatchedEpisode _w(int show, int s, int e, DateTime at) =>
    WatchedEpisode(showId: show, season: s, episode: e, watchedAt: at);

void main() {
  final now = DateTime(2026, 7, 6);
  final past = DateTime(2026, 1, 1);

  test('prochain à voir précis + « +N » restants', () {
    final show = _show(1, 'Dark', total: 4);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 2)],
      episodes: [
        _ep(1, 1, 1, air: past),
        _ep(1, 1, 2, air: past),
        _ep(1, 1, 3, air: past, name: 'Trois'),
        _ep(1, 1, 4, air: past),
      ],
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 2))),
        _w(1, 1, 2, now.subtract(const Duration(days: 1))),
      ],
      now: now,
    );
    expect(feed.toWatch, hasLength(1));
    final n = feed.toWatch.single;
    expect(n.season, 1);
    expect(n.episode, 3);
    expect(n.episodeName, 'Trois');
    expect(n.remaining, 1); // E4 reste après E3
    expect(n.precise, isTrue);
    expect(n.code, 'S01 | E03');
  });

  test('épisodes non diffusés exclus du « à voir » et du « +N »', () {
    final show = _show(1, 'Severance', total: 3);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 1)],
      episodes: [
        _ep(1, 1, 1, air: past),
        _ep(1, 1, 2, air: past),
        _ep(1, 1, 3, air: now.add(const Duration(days: 7))), // à venir
      ],
      watched: [_w(1, 1, 1, now.subtract(const Duration(days: 3)))],
      now: now,
    );
    final n = feed.toWatch.single;
    expect(n.episode, 2);
    expect(n.remaining, 0); // E3 pas encore diffusé
  });

  test('série à jour : absente de « à voir », présente dans l\'historique', () {
    final show = _show(1, 'Arcane', total: 2);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 2)],
      episodes: [_ep(1, 1, 1, air: past), _ep(1, 1, 2, air: past)],
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 5))),
        _w(1, 1, 2, now.subtract(const Duration(days: 4))),
      ],
      now: now,
    );
    expect(feed.toWatch, isEmpty);
    expect(feed.stale, isEmpty);
    expect(feed.history.first.show.name, 'Arcane');
    expect(feed.history.first.code, 'S01 | E02');
  });

  test('séparation récent / « pas regardé depuis un moment »', () {
    final recent = _show(1, 'Récent', total: 5);
    final old = _show(2, 'Ancien', total: 5);
    final feed = buildSeriesFeed(
      shows: [_swp(recent, 1), _swp(old, 1)],
      episodes: [
        _ep(1, 1, 1, air: past), _ep(1, 1, 2, air: past),
        _ep(2, 1, 1, air: past), _ep(2, 1, 2, air: past),
      ],
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 2))),
        _w(2, 1, 1, now.subtract(const Duration(days: 40))),
      ],
      now: now,
      staleAfter: const Duration(days: 21),
    );
    expect(feed.toWatch.map((n) => n.show.name), ['Récent']);
    expect(feed.stale.map((n) => n.show.name), ['Ancien']);
  });

  test('« à voir » trié par activité récente (le plus récent en tête)', () {
    final a = _show(1, 'A', total: 3);
    final b = _show(2, 'B', total: 3);
    final feed = buildSeriesFeed(
      shows: [_swp(a, 1), _swp(b, 1)],
      episodes: [
        _ep(1, 1, 1, air: past), _ep(1, 1, 2, air: past),
        _ep(2, 1, 1, air: past), _ep(2, 1, 2, air: past),
      ],
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 5))),
        _w(2, 1, 1, now.subtract(const Duration(days: 1))),
      ],
      now: now,
    );
    expect(feed.toWatch.map((n) => n.show.name), ['B', 'A']);
  });

  test('fallback sans métadonnées : prochain = max vu + 1, imprécis', () {
    final show = _show(1, 'SansCache', total: 10);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 3)],
      episodes: const [], // pas encore synchronisé
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 2))),
        _w(1, 1, 2, now.subtract(const Duration(days: 2))),
        _w(1, 1, 3, now.subtract(const Duration(days: 1))),
      ],
      now: now,
    );
    final n = feed.toWatch.single;
    expect(n.season, 1);
    expect(n.episode, 4);
    expect(n.precise, isFalse);
    expect(n.remaining, isNull);
  });

  test('série ajoutée sans coche : prochain = S1E1', () {
    final show = _show(1, 'Neuve', total: 10, addedAt: now);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 0)],
      episodes: const [],
      watched: const [],
      now: now,
    );
    final n = feed.toWatch.single;
    expect(n.season, 1);
    expect(n.episode, 1);
    expect(n.precise, isFalse);
  });

  test('historique limité et trié par date décroissante', () {
    final shows = [for (var i = 1; i <= 3; i++) _show(i, 'S$i', total: 2)];
    final feed = buildSeriesFeed(
      shows: [for (final s in shows) _swp(s, 1)],
      episodes: const [],
      watched: [
        _w(1, 1, 1, now.subtract(const Duration(days: 3))),
        _w(2, 1, 1, now.subtract(const Duration(days: 1))),
        _w(3, 1, 1, now.subtract(const Duration(days: 2))),
      ],
      now: now,
      historyLimit: 2,
    );
    expect(feed.history, hasLength(2));
    expect(feed.history.map((h) => h.show.name), ['S2', 'S3']);
  });
}
