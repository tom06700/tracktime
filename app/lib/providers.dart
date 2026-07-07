import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'demo/demo_seed.dart';
import 'series/feed.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  // Web + ?demo=1 : peuple une base vide d'exemples (fire-and-forget).
  maybeSeedDemo(db);
  return db;
});

final showsProvider = StreamProvider<List<ShowWithProgress>>(
    (ref) => ref.watch(databaseProvider).watchShowsWithProgress());

final moviesProvider = StreamProvider<List<Movie>>(
    (ref) => ref.watch(databaseProvider).watchMovies());

final statsProvider = StreamProvider<WatchStats>(
    (ref) => ref.watch(databaseProvider).watchStats());

/// Ensemble réactif des clés "SxEy" vues, pour l'écran de détail d'une série.
final watchedKeysProvider = StreamProvider.family<Set<String>, int>(
    (ref, showId) => ref.watch(databaseProvider).watchWatchedKeys(showId));

typedef EpisodeRef = ({int showId, int season, int episode});

/// L'épisode vu (avec sa date), pour la page détail d'épisode.
final watchedEpisodeProvider =
    StreamProvider.family<WatchedEpisode?, EpisodeRef>((ref, k) => ref
        .watch(databaseProvider)
        .watchWatchedEpisode(k.showId, k.season, k.episode));

final _allEpisodesProvider = StreamProvider<List<Episode>>(
    (ref) => ref.watch(databaseProvider).watchAllEpisodes());

final _allWatchedProvider = StreamProvider<List<WatchedEpisode>>(
    (ref) => ref.watch(databaseProvider).watchAllWatched());

/// Fil de la page Séries (historique · à voir · délaissées), recomposé dès
/// qu'une série, un épisode caché ou une coche change.
final seriesFeedProvider = Provider<AsyncValue<SeriesFeed>>((ref) {
  final shows = ref.watch(showsProvider);
  final episodes = ref.watch(_allEpisodesProvider);
  final watched = ref.watch(_allWatchedProvider);

  return shows.whenData((showList) {
    final feed = buildSeriesFeed(
      shows: showList,
      episodes: episodes.value ?? const [],
      watched: watched.value ?? const [],
      now: DateTime.now(),
    );
    return feed;
  });
});

/// Épisodes à venir (prochain de chaque série suivie, du plus proche au plus
/// loin), pour l'onglet « À venir ».
final upcomingProvider = Provider<AsyncValue<List<UpcomingEpisode>>>((ref) {
  final shows = ref.watch(showsProvider);
  final episodes = ref.watch(_allEpisodesProvider);
  return shows.whenData((showList) => buildUpcoming(
        shows: showList,
        episodes: episodes.value ?? const [],
        now: DateTime.now(),
      ));
});
