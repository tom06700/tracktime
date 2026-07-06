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

  @override
  Set<Column> get primaryKey => {id};
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

@DriftDatabase(tables: [Shows, WatchedEpisodes, Movies])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tracktime');
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
