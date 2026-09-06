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

  test('fin de saison 22 : reprise en 23, jamais sur les spéciaux', () {
    final show = _show(81797, 'One Piece');
    final watched = [_w(81797, 22, 1155, now)];
    final episodes = [
      _ep(81797, 0, 1, air: past),
      _ep(81797, 22, 1155, air: past),
      _ep(81797, 23, 1156, air: past),
      _ep(81797, 23, 1158, air: past),
    ];
    final feed = buildSeriesFeed(
        shows: [_swp(show, 1)], episodes: episodes, watched: watched, now: now);
    expect(feed.toWatch.single.season, 23);
    expect(feed.toWatch.single.episode, 1156);
    expect(feed.toWatch.single.remaining, 1);
    expect(watched, hasLength(1));
    expect(episodes.first.season, 0);
  });

  test('saison suivante future : les spéciaux ne deviennent pas la reprise',
      () {
    final show = _show(1, 'One Piece');
    final feed = buildSeriesFeed(shows: [
      _swp(show, 1)
    ], episodes: [
      _ep(1, 0, 1, air: past),
      _ep(1, 22, 1155, air: past),
      _ep(1, 23, 1156, air: now.add(const Duration(days: 7)))
    ], watched: [
      _w(1, 22, 1155, now)
    ], now: now);
    expect(feed.toWatch, isEmpty);
    expect(feed.stale, isEmpty);
    expect(feed.history.single.episode, 1155);
  });

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
        _ep(1, 1, 1, air: past),
        _ep(1, 1, 2, air: past),
        _ep(2, 1, 1, air: past),
        _ep(2, 1, 2, air: past),
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
        _ep(1, 1, 1, air: past),
        _ep(1, 1, 2, air: past),
        _ep(2, 1, 1, air: past),
        _ep(2, 1, 2, air: past),
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

  group('buildUpcoming', () {
    test('tous les épisodes à venir, du plus proche au plus loin', () {
      final a = _show(1, 'A');
      final b = _show(2, 'B');
      final list = buildUpcoming(
        shows: [_swp(a, 0), _swp(b, 0)],
        episodes: [
          _ep(1, 2, 1, air: now.add(const Duration(days: 10))),
          _ep(1, 2, 2, air: now.add(const Duration(days: 17))),
          _ep(2, 1, 5, air: now.add(const Duration(days: 3))),
        ],
        now: now,
      );
      // Une série qui a deux rendez-vous annoncés en montre deux : on ne
      // masque plus tout ce qui suit le prochain épisode.
      expect(
        list.map((u) => '${u.show.name} ${u.code}'),
        ['B S01 | E05', 'A S02 | E01', 'A S02 | E02'],
      );
      expect(list.first.daysFrom(now), 3);
    });

    test('hier exclu, aujourd\'hui inclus', () {
      final a = _show(1, 'A');
      final list = buildUpcoming(
        shows: [_swp(a, 1)],
        episodes: [
          _ep(1, 1, 1, air: now.subtract(const Duration(days: 1))),
          _ep(1, 1, 2, air: now),
          _ep(1, 1, 3, air: now.add(const Duration(days: 5))),
        ],
        now: now,
      );
      expect(list.map((u) => u.episode), [2, 3]);
    });

    test('l\'épisode du jour reste affiché en fin de journée', () {
      final a = _show(1, 'A');
      // Le cas qui faisait disparaître l'épisode : TheTVDB le date à minuit,
      // donc dès 00 h 01 il était « passé » au sens d'une comparaison
      // d'instants, alors qu'il n'est pas encore diffusé.
      final list = buildUpcoming(
        shows: [_swp(a, 0)],
        episodes: [_ep(1, 1, 1, air: DateTime(2026, 7, 6))],
        now: DateTime(2026, 7, 6, 23, 30),
      );
      expect(list, hasLength(1));
      expect(list.single.daysFrom(DateTime(2026, 7, 6, 23, 30)), 0);
    });

    test('daysFrom en jours calendaires', () {
      final a = _show(1, 'A');
      final list = buildUpcoming(
        shows: [_swp(a, 0)],
        episodes: [
          _ep(1, 1, 1, air: DateTime(2026, 7, 7, 2)), // lendemain, 2h du matin
        ],
        now: DateTime(2026, 7, 6, 23), // veille, 23h
      );
      expect(list.single.daysFrom(DateTime(2026, 7, 6, 23)), 1);
    });

    test('une série hebdomadaire montre ses prochaines dates', () {
      // Cas One Piece : un épisode aujourd'hui, un dans une semaine, un dans
      // deux — les trois doivent apparaître.
      final op = _show(81797, 'One Piece');
      final list = buildUpcoming(
        shows: [_swp(op, 1000)],
        episodes: [
          _ep(81797, 21, 1120, air: now),
          _ep(81797, 21, 1121, air: now.add(const Duration(days: 7))),
          _ep(81797, 21, 1122, air: now.add(const Duration(days: 14))),
        ],
        now: now,
      );
      expect(list.map((u) => u.episode), [1120, 1121, 1122]);
      expect(list.map((u) => u.daysFrom(now)), [0, 7, 14]);
    });

    test('fenêtre de trois mois : au-delà, les dates ne sont pas fiables', () {
      final a = _show(1, 'A');
      final list = buildUpcoming(
        shows: [_swp(a, 0)],
        episodes: [
          _ep(1, 1, 1, air: now.add(const Duration(days: 89))),
          _ep(1, 1, 2, air: now.add(const Duration(days: 120))),
        ],
        now: now,
      );
      expect(list.map((u) => u.episode), [1]);
    });

    test('ordre déterministe entre deux épisodes du même jour', () {
      final z = _show(1, 'Zulu');
      final a = _show(2, 'Alpha');
      final day = now.add(const Duration(days: 2));
      final list = buildUpcoming(
        shows: [_swp(z, 0), _swp(a, 0)],
        episodes: [_ep(1, 1, 1, air: day), _ep(2, 3, 4, air: day)],
        now: now,
      );
      expect(list.map((u) => u.show.name), ['Alpha', 'Zulu']);
    });

    test('ignore les épisodes d\'une série non suivie', () {
      final a = _show(1, 'A');
      final list = buildUpcoming(
        shows: [_swp(a, 0)],
        episodes: [
          _ep(1, 1, 1, air: now.add(const Duration(days: 2))),
          _ep(99, 1, 1, air: now.add(const Duration(days: 1))),
        ],
        now: now,
      );
      expect(list.map((u) => u.show.id), [1]);
    });
  });

  group('groupUpcoming', () {
    test('répartit aujourd\'hui, demain, cette semaine, plus tard', () {
      final a = _show(1, 'A');
      final list = buildUpcoming(
        shows: [_swp(a, 0)],
        episodes: [
          _ep(1, 1, 1, air: now),
          _ep(1, 1, 2, air: now.add(const Duration(days: 1))),
          _ep(1, 1, 3, air: now.add(const Duration(days: 4))),
          _ep(1, 1, 4, air: now.add(const Duration(days: 30))),
        ],
        now: now,
      );
      final groups = groupUpcoming(list, now);
      expect(groups.map((g) => g.bucket), [
        UpcomingBucket.today,
        UpcomingBucket.tomorrow,
        UpcomingBucket.thisWeek,
        UpcomingBucket.later,
      ]);
      expect(groups.first.episodes.single.episode, 1);
    });

    test('« Plus tard » plafonné par série, tranches proches complètes', () {
      final op = _show(1, 'Quotidienne');
      final list = buildUpcoming(
        shows: [_swp(op, 0)],
        episodes: [
          for (var i = 0; i < 20; i++)
            _ep(1, 1, i + 1, air: now.add(Duration(days: i))),
        ],
        now: now,
      );
      expect(list, hasLength(20));
      final groups = {
        for (final g in groupUpcoming(list, now)) g.bucket: g.episodes,
      };
      // Jours 0 à 7 : rien n'est masqué.
      expect(groups[UpcomingBucket.today], hasLength(1));
      expect(groups[UpcomingBucket.tomorrow], hasLength(1));
      expect(groups[UpcomingBucket.thisWeek], hasLength(6)); // j+2 à j+7
      // Jours 8 à 19 : seulement les trois premiers.
      expect(groups[UpcomingBucket.later], hasLength(3));
      expect(
        groups[UpcomingBucket.later]!.map((u) => u.daysFrom(now)),
        [8, 9, 10],
      );
    });
  });

  group('hasAiredByDay', () {
    final ref = DateTime(2026, 7, 6, 14);

    test('hier oui, aujourd\'hui oui, demain non', () {
      expect(hasAiredByDay(DateTime(2026, 7, 5), ref), isTrue);
      expect(hasAiredByDay(DateTime(2026, 7, 6), ref), isTrue);
      expect(hasAiredByDay(DateTime(2026, 7, 6, 23), ref), isTrue);
      expect(hasAiredByDay(DateTime(2026, 7, 7), ref), isFalse);
    });

    test('date inconnue : considérée diffusée', () {
      expect(hasAiredByDay(null, ref), isTrue);
    });
  });

  test('l\'épisode diffusé aujourd\'hui entre dans « à voir »', () {
    final show = _show(1, 'Andor', total: 3);
    final feed = buildSeriesFeed(
      shows: [_swp(show, 1)],
      episodes: [
        _ep(1, 1, 1, air: past),
        _ep(1, 1, 2, air: DateTime(2026, 7, 6), name: 'Aujourd\'hui'),
        _ep(1, 1, 3, air: DateTime(2026, 7, 7)), // demain
      ],
      watched: [_w(1, 1, 1, DateTime(2026, 7, 4))],
      now: DateTime(2026, 7, 6, 9), // 9 h du matin, l'épisode est daté minuit
    );
    final n = feed.toWatch.single;
    expect(n.episode, 2);
    expect(n.episodeName, 'Aujourd\'hui');
    expect(n.remaining, 0, reason: 'celui de demain ne compte pas');
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
