import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Une série suivie (id = identifiant TMDB).
class Shows extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get poster => text().nullable()();
  IntColumn get totalEpisodes => integer().nullable()();
  IntColumn get seasonCount => integer().nullable()();
  IntColumn get runtime => integer().withDefault(const Constant(42))();
  TextColumn get status => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  // Dernière synchro des épisodes TMDB (null = jamais).
  DateTimeColumn get episodesSyncedAt => dateTime().nullable()();
  // Genres TMDB séparés par « | » (null = pas encore récupérés).
  TextColumn get genres => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Métadonnées d'un épisode (cache TMDB) : titre, image, date de diffusion.
/// Sert à construire le fil « à voir » (prochain épisode, restants).
@DataClassName('Episode')
class Episodes extends Table {
  IntColumn get showId =>
      integer().references(Shows, #id, onDelete: KeyAction.cascade)();
  IntColumn get season => integer()();
  IntColumn get episode => integer()();
  TextColumn get name => text().nullable()();
  TextColumn get still => text().nullable()();
  DateTimeColumn get airDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {showId, season, episode};
}

/// Un épisode vu, équivalent de la clé "S3E7" de la version web.
class WatchedEpisodes extends Table {
  IntColumn get showId =>
      integer().references(Shows, #id, onDelete: KeyAction.cascade)();
  IntColumn get season => integer()();
  IntColumn get episode => integer()();
  DateTimeColumn get watchedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {showId, season, episode};
}

/// Un film (id = identifiant TMDB). watchedAt null = dans la watchlist.
@DataClassName('Movie')
class Movies extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get poster => text().nullable()();
  IntColumn get runtime => integer().withDefault(const Constant(110))();
  DateTimeColumn get watchedAt => dateTime().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  // Genres TMDB séparés par « | » (null = pas encore récupérés).
  TextColumn get genres => text().nullable()();
  // Date de sortie TMDB (null = pas encore récupérée) — onglet « À venir ».
  DateTimeColumn get releaseDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Série + nombre d'épisodes vus, pour les listes et les stats.
class ShowWithProgress {
  const ShowWithProgress(this.show, this.watchedCount);

  final Show show;
  final int watchedCount;

  double get progress {
    final total = show.totalEpisodes;
    if (total == null || total == 0) return 0;
    final p = watchedCount / total;
    return p > 1 ? 1 : p;
  }

  bool get isDone => progress >= 1;
}

class WatchStats {
  const WatchStats({
    required this.episodeCount,
    required this.tvMinutes,
    required this.moviesSeen,
    required this.movieMinutes,
    required this.showCount,
    required this.doneShowCount,
    required this.watchlistCount,
  });

  final int episodeCount;
  final int tvMinutes;
  final int moviesSeen;
  final int movieMinutes;
  final int showCount;
  final int doneShowCount;
  final int watchlistCount;

  int get totalMinutes => tvMinutes + movieMinutes;
}

@DriftDatabase(tables: [Shows, Episodes, WatchedEpisodes, Movies])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(episodes);
            await m.addColumn(shows, shows.episodesSyncedAt);
          }
          if (from < 3) {
            await m.addColumn(shows, shows.genres);
            await m.addColumn(movies, movies.genres);
          }
          if (from < 4) {
            await m.addColumn(movies, movies.releaseDate);
          }
          if (from < 5) {
            // Passage à TheTVDB : les données existantes utilisent des
            // identifiants TMDB, incompatibles (404 côté TheTVDB). On repart
            // proprement — l'utilisateur ré-ajoute / ré-importe.
            await delete(watchedEpisodes).go();
            await delete(episodes).go();
            await delete(shows).go();
            await delete(movies).go();
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'tracktime',
      // Sur le web : binaires servis à côté de l'app (résolus via <base href>).
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  // ---- Séries ----

  Stream<List<ShowWithProgress>> watchShowsWithProgress() {
    final count = watchedEpisodes.showId.count();
    final query = select(shows).join([
      leftOuterJoin(
        watchedEpisodes,
        watchedEpisodes.showId.equalsExp(shows.id),
        useColumns: false,
      ),
    ])
      ..addColumns([count])
      ..groupBy([shows.id])
      ..orderBy([OrderingTerm.asc(shows.name)]);

    return query.watch().map((rows) => rows
        .map((r) => ShowWithProgress(r.readTable(shows), r.read(count) ?? 0))
        .toList());
  }

  Future<Show?> showById(int id) =>
      (select(shows)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<List<Show>> allShows() => select(shows).get();

  Future<List<WatchedEpisode>> allWatchedEpisodes() =>
      select(watchedEpisodes).get();

  Stream<List<Show>> watchAllShows() => select(shows).watch();

  Future<void> setShowGenres(int id, String genres) =>
      (update(shows)..where((s) => s.id.equals(id)))
          .write(ShowsCompanion(genres: Value(genres)));

  /// Met à jour les compteurs d'une série après synchro des épisodes.
  Future<void> updateShowCounts(int id,
          {required int total, required int seasons}) =>
      (update(shows)..where((s) => s.id.equals(id))).write(ShowsCompanion(
        totalEpisodes: Value(total),
        seasonCount: Value(seasons),
      ));

  Future<void> setMovieGenres(int id, String genres) =>
      (update(movies)..where((m) => m.id.equals(id)))
          .write(MoviesCompanion(genres: Value(genres)));

  Future<void> setMovieReleaseDate(int id, DateTime date) =>
      (update(movies)..where((m) => m.id.equals(id)))
          .write(MoviesCompanion(releaseDate: Value(date)));

  // ---- Épisodes (cache TMDB) ----

  Future<void> upsertEpisodes(List<EpisodesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(episodes, rows));

  Future<void> markShowSynced(int showId, DateTime at) =>
      (update(shows)..where((s) => s.id.equals(showId)))
          .write(ShowsCompanion(episodesSyncedAt: Value(at)));

  Stream<List<Episode>> watchAllEpisodes() => select(episodes).watch();

  Stream<List<WatchedEpisode>> watchAllWatched() =>
      select(watchedEpisodes).watch();

  Future<List<Movie>> allMovies() => select(movies).get();

  /// Date d'ajout la plus ancienne (proxy « membre depuis »), ou null si vide.
  Future<DateTime?> earliestActivity() async {
    final dates = <DateTime>[
      for (final s in await allShows()) s.addedAt,
      for (final m in await allMovies()) m.addedAt,
    ];
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Future<Movie?> movieById(int id) =>
      (select(movies)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<void> upsertShow(ShowsCompanion entry) =>
      into(shows).insertOnConflictUpdate(entry);

  Future<void> deleteShow(int id) =>
      (delete(shows)..where((s) => s.id.equals(id))).go();

  Future<void> setEpisodeWatched(int showId, int season, int episode,
      {DateTime? at}) {
    return into(watchedEpisodes).insert(
      WatchedEpisodesCompanion.insert(
        showId: showId,
        season: season,
        episode: episode,
        watchedAt: at == null ? const Value.absent() : Value(at),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<void> setEpisodeUnwatched(int showId, int season, int episode) {
    return (delete(watchedEpisodes)
          ..where((e) =>
              e.showId.equals(showId) &
              e.season.equals(season) &
              e.episode.equals(episode)))
        .go();
  }

  Stream<List<WatchedEpisode>> watchEpisodesOf(int showId) =>
      (select(watchedEpisodes)..where((e) => e.showId.equals(showId))).watch();

  /// L'épisode vu (avec sa date), ou null s'il ne l'est pas.
  Stream<WatchedEpisode?> watchWatchedEpisode(
          int showId, int season, int episode) =>
      (select(watchedEpisodes)
            ..where((e) =>
                e.showId.equals(showId) &
                e.season.equals(season) &
                e.episode.equals(episode)))
          .watchSingleOrNull();

  /// Marque comme vu tout épisode (en cache) jusqu'à (season, episode) inclus
  /// — « rattraper jusqu'ici ». S'appuie sur la table episodes (remplie par la
  /// synchro / la page série).
  Future<void> markWatchedUpTo(int showId, int season, int episode) async {
    final eps =
        await (select(episodes)..where((e) => e.showId.equals(showId))).get();
    final toMark = eps.where((e) =>
        e.season < season || (e.season == season && e.episode <= episode));
    await batch((b) {
      for (final e in toMark) {
        b.insert(
          watchedEpisodes,
          WatchedEpisodesCompanion.insert(
              showId: showId, season: e.season, episode: e.episode),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }

  /// Diffuse l'ensemble des clés "SxEy" vues pour une série, pratique pour
  /// l'écran de détail (rendu réactif des coches).
  Stream<Set<String>> watchWatchedKeys(int showId) =>
      watchEpisodesOf(showId).map((eps) =>
          {for (final e in eps) 'S${e.season}E${e.episode}'});

  /// Coche/décoche toute une saison d'un coup à partir des numéros d'épisodes.
  Future<void> setSeasonWatched(
      int showId, int season, List<int> episodeNumbers, bool watched) {
    return transaction(() async {
      if (watched) {
        for (final ep in episodeNumbers) {
          await setEpisodeWatched(showId, season, ep);
        }
      } else {
        await (delete(watchedEpisodes)
              ..where((e) => e.showId.equals(showId) & e.season.equals(season)))
            .go();
      }
    });
  }

  // ---- Films ----

  Stream<List<Movie>> watchMovies() =>
      (select(movies)..orderBy([(m) => OrderingTerm.asc(m.title)])).watch();

  Future<void> upsertMovie(MoviesCompanion entry) =>
      into(movies).insertOnConflictUpdate(entry);

  Future<void> deleteMovie(int id) =>
      (delete(movies)..where((m) => m.id.equals(id))).go();

  Future<void> toggleMovieWatched(Movie m) {
    return (update(movies)..where((x) => x.id.equals(m.id))).write(
      MoviesCompanion(
        watchedAt: Value(m.watchedAt == null ? DateTime.now() : null),
      ),
    );
  }

  // ---- Stats ----

  Stream<WatchStats> watchStats() {
    // Recalcule à chaque changement d'une des trois tables.
    final query = customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM watched_episodes) AS ep_count,
        (SELECT COALESCE(SUM(s.runtime), 0)
           FROM watched_episodes w JOIN shows s ON s.id = w.show_id) AS tv_min,
        (SELECT COUNT(*) FROM movies WHERE watched_at IS NOT NULL) AS mv_seen,
        (SELECT COALESCE(SUM(runtime), 0)
           FROM movies WHERE watched_at IS NOT NULL) AS mv_min,
        (SELECT COUNT(*) FROM shows) AS show_count,
        (SELECT COUNT(*) FROM movies WHERE watched_at IS NULL) AS watchlist,
        (SELECT COUNT(*) FROM shows s
           WHERE s.total_episodes IS NOT NULL AND s.total_episodes > 0
             AND (SELECT COUNT(*) FROM watched_episodes w
                    WHERE w.show_id = s.id) >= s.total_episodes) AS done_shows
      ''',
      readsFrom: {shows, watchedEpisodes, movies},
    );

    return query.watchSingle().map((row) => WatchStats(
          episodeCount: row.read<int>('ep_count'),
          tvMinutes: row.read<int>('tv_min'),
          moviesSeen: row.read<int>('mv_seen'),
          movieMinutes: row.read<int>('mv_min'),
          showCount: row.read<int>('show_count'),
          doneShowCount: row.read<int>('done_shows'),
          watchlistCount: row.read<int>('watchlist'),
        ));
  }
}
