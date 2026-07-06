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

  // (id TMDB réel, nom, total, saisons, durée, statut, épisodes vus)
  const shows = [
    (1396, 'Breaking Bad', 62, 5, 47, 'Ended', 62),
    (70523, 'Dark', 26, 3, 53, 'Ended', 17),
    (2316, 'The Office', 201, 9, 24, 'Ended', 134),
    (66732, 'Stranger Things', 42, 5, 51, 'Returning Series', 33),
    (95396, 'Severance', 19, 2, 50, 'Returning Series', 9),
    (136315, 'The Bear', 28, 3, 30, 'Returning Series', 28),
    (94605, 'Arcane', 18, 2, 41, 'Ended', 18),
    (76331, 'Succession', 39, 4, 60, 'Ended', 12),
  ];

  // (id TMDB réel, titre, durée, vu ?)
  const movies = [
    (27205, 'Inception', 148, true),
    (157336, 'Interstellar', 169, true),
    (496243, 'Parasite', 132, true),
    (438631, 'Dune', 155, false),
    (872585, 'Oppenheimer', 180, false),
    (244786, 'Whiplash', 106, true),
    (129, 'Le Voyage de Chihiro', 125, false),
  ];

  await db.transaction(() async {
    for (final (id, name, total, seasons, runtime, status, seen) in shows) {
      await db.upsertShow(ShowsCompanion.insert(
        id: Value(id),
        name: name,
        totalEpisodes: Value(total),
        seasonCount: Value(seasons),
        runtime: Value(runtime),
        status: Value(status),
      ));
      final perSeason = (total / seasons).ceil();
      for (var i = 0; i < seen; i++) {
        await db.setEpisodeWatched(
            id, i ~/ perSeason + 1, i % perSeason + 1,
            at: DateTime(2026, 1 + i % 6, 1 + i % 27));
      }
    }
    for (final (id, title, runtime, seen) in movies) {
      await db.upsertMovie(MoviesCompanion.insert(
        id: Value(id),
        title: title,
        runtime: Value(runtime),
        watchedAt: Value(seen ? DateTime(2026, 3, 14) : null),
      ));
    }
  });
}
