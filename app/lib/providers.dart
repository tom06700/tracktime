import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'demo/demo_seed.dart';
import 'movies/feed.dart';
import 'profile/profile.dart';
import 'profile/universe.dart';
import 'series/feed.dart';
import 'tmdb/media_detail.dart';
import 'settings/prefs.dart';

/// Onglet courant de la coquille. Porté par un provider plutôt que par l'état
/// local du Shell, pour qu'un écran enfant puisse demander l'ouverture d'un
/// autre onglet — le bouton « Explorer les séries » de l'état vide — sans
/// empiler une seconde instance de l'écran visé.
final homeTabProvider =
    NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => HomeTab.series;

  void select(int index) => state = index;
}

/// Index des onglets de la coquille, pour éviter les nombres nus.
abstract final class HomeTab {
  static const series = 0;
  static const movies = 1;
  static const explorer = 2;
  static const profile = 3;
}

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

/// Séries et films les mieux notés de TheTVDB, pour l'écran de découverte.
/// Chargés une fois puis conservés tant que l'onglet vit : la coquille garde
/// Explorer monté, donc aucun rappel réseau au changement d'onglet.
final popularSeriesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async =>
        (await ref.watch(tvdbClientProvider).mostPopular(movies: false))
            .take(20)
            .toList());

final popularMoviesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async =>
        (await ref.watch(tvdbClientProvider).mostPopular(movies: true))
            .take(20)
            .toList());

/// Films dont la sortie est annoncée.
final upcomingReleasesProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) async =>
        (await ref.watch(tvdbClientProvider).upcomingReleases())
            .take(20)
            .toList());

/// Fiche d'une série, chargée à la demande et mise en cache par le provider :
/// les rebuilds ne relancent pas la requête, et `ref.invalidate` la rejoue
/// pour le bouton « Réessayer ».
///
/// Volontairement limité à `/series/{id}/extended` : la liste des épisodes est
/// une requête paginée séparée, qu'on ne déclenche pas pour un simple aperçu
/// — One Piece en compte plus de mille.
final seriesDetailProvider = FutureProvider.family<SeriesDetail, int>((
  ref,
  id,
) async {
  final tvdb = ref.watch(tvdbClientProvider);
  final extended = await tvdb.seriesExtended(id);
  final fra = await tvdb.seriesTranslation(id, 'fra');
  return parseSeriesDetail(id, extended, translation: fra);
});

/// Fiche d'un film. `/movies/{id}/extended` ne porte pas de synopsis : il faut
/// aller le chercher dans les traductions, en français puis en anglais.
final movieDetailProvider = FutureProvider.family<MovieDetail, int>((
  ref,
  id,
) async {
  final tvdb = ref.watch(tvdbClientProvider);
  final extended = await tvdb.movieExtended(id);
  var translation = await tvdb.movieTranslation(id, 'fra');
  if ('${translation['overview'] ?? ''}'.trim().isEmpty) {
    final eng = await tvdb.movieTranslation(id, 'eng');
    translation = {...eng, ...translation};
  }
  return parseMovieDetail(id, extended, translation: translation);
});

/// Historique complet des épisodes vus, du plus récent au plus ancien.
final watchHistoryProvider = Provider<AsyncValue<List<WatchedEntry>>>((ref) {
  final shows = ref.watch(showsProvider);
  final episodes = ref.watch(_allEpisodesProvider);
  final watched = ref.watch(_allWatchedProvider);

  return shows.whenData((showList) => buildWatchHistory(
        shows: showList,
        episodes: episodes.value ?? const [],
        watched: watched.value ?? const [],
      ));
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

/// Fil de la page Films (historique · à voir · oubliés), recomposé dès
/// qu'un film ou son état change.
final movieFeedProvider = Provider<AsyncValue<MovieFeed>>((ref) {
  final movies = ref.watch(moviesProvider);
  return movies.whenData((list) => buildMovieFeed(
        movies: list,
        now: DateTime.now(),
      ));
});

/// Films à venir (watchlist pas encore sortie, du plus proche au plus loin),
/// pour l'onglet « À venir ».
final upcomingMoviesProvider = Provider<AsyncValue<List<UpcomingMovie>>>((ref) {
  final movies = ref.watch(moviesProvider);
  return movies.whenData((list) => buildUpcomingMovies(
        movies: list,
        now: DateTime.now(),
      ));
});

/// « Univers » du profil : palette de genres, activité, badges et records,
/// recomposé dès qu'une série, un film ou une coche change.
final universeProvider = Provider<AsyncValue<Universe>>((ref) {
  final shows = ref.watch(showsProvider);
  final movies = ref.watch(moviesProvider);
  final watched = ref.watch(_allWatchedProvider);
  final stats = ref.watch(statsProvider);
  final profile = ref.watch(profileProvider);

  return shows.whenData((showList) => buildUniverse(
        shows: showList,
        watched: watched.value ?? const [],
        movies: movies.value ?? const [],
        profileName: profile.value?.displayName ?? 'Cinéphile',
        now: DateTime.now(),
        stats: stats.value ??
            const WatchStats(
              episodeCount: 0,
              tvMinutes: 0,
              moviesSeen: 0,
              movieMinutes: 0,
              showCount: 0,
              doneShowCount: 0,
              watchlistCount: 0,
            ),
      ));
});
