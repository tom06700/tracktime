import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/database.dart';

/// Mode démo (web uniquement) : `/flutter/?demo=1` remplit une base vide
/// d'exemples réalistes. Utile pour les aperçus visuels et les captures
/// d'écran (stores) sans dépendre de TMDB.
Future<void> maybeSeedDemo(AppDatabase db) async {
  if (!kIsWeb) return;
  if (Uri.base.queryParameters['demo'] != '1') return;
  if ((await db.allShows()).isNotEmpty) return;

  // (id TMDB, nom, total, saisons, durée, statut, épisodes vus)
  const shows = [
    (1396, 'Breaking Bad', 62, 5, 47, 'Ended', 62),
    (70523, 'Dark', 26, 3, 53, 'Returning Series', 17),
    (2316, 'The Office', 201, 9, 24, 'Ended', 134),
    (66732, 'Stranger Things', 42, 5, 51, 'Returning Series', 33),
    (95396, 'Severance', 19, 2, 50, 'Returning Series', 9),
    (136315, 'The Bear', 28, 3, 30, 'Returning Series', 28),
    (94605, 'Arcane', 18, 2, 41, 'Ended', 18),
    (76331, 'Succession', 39, 4, 60, 'Ended', 12),
  ];

  const movies = [
    (27205, 'Inception', 148, true),
    (157336, 'Interstellar', 169, true),
    (496243, 'Parasite', 132, true),
    (438631, 'Dune', 155, false),
    (872585, 'Oppenheimer', 180, false),
    (244786, 'Whiplash', 106, true),
    (129, 'Le Voyage de Chihiro', 125, false),
  ];

  final now = DateTime.now();

  await db.transaction(() async {
    for (var i = 0; i < shows.length; i++) {
      final (id, name, total, seasons, runtime, status, seen) = shows[i];
      final perSeason = (total / seasons).ceil();
      // Activité décalée : les premières séries sont récentes, les dernières
      // « pas regardées depuis un moment ».
      final activity = now.subtract(Duration(days: i * 4, hours: 3));

      await db.upsertShow(ShowsCompanion.insert(
        id: Value(id),
        name: name,
        totalEpisodes: Value(total),
        seasonCount: Value(seasons),
        runtime: Value(runtime),
        status: Value(status),
      ));

      final eps = <EpisodesCompanion>[];
      for (var idx = 0; idx < total; idx++) {
        final season = idx ~/ perSeason + 1;
        final ep = idx % perSeason + 1;
        eps.add(EpisodesCompanion.insert(
          showId: id,
          season: season,
          episode: ep,
          name: Value('Épisode $ep'),
          airDate: Value(now.subtract(Duration(days: total - idx + 30))),
        ));
        if (idx < seen) {
          await db.setEpisodeWatched(id, season, ep,
              at: activity.subtract(Duration(hours: (seen - 1 - idx) * 6)));
        }
      }
      // Séries en cours de diffusion : un prochain épisode daté dans le futur
      // (offsets distincts pour peupler l'onglet « À venir »).
      if (status == 'Returning Series') {
        final offset = [3, 10, 17, 30][i % 4];
        eps.add(EpisodesCompanion.insert(
          showId: id,
          season: seasons + 1,
          episode: 1,
          name: const Value('Premier de la nouvelle saison'),
          airDate: Value(now.add(Duration(days: offset))),
        ));
      }
      await db.upsertEpisodes(eps);
      await db.markShowSynced(id, now);
    }

    for (final (id, title, runtime, seen) in movies) {
      await db.upsertMovie(MoviesCompanion.insert(
        id: Value(id),
        title: title,
        runtime: Value(runtime),
        watchedAt: Value(seen ? now.subtract(const Duration(days: 20)) : null),
      ));
    }
  });
}
