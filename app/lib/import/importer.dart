import 'package:drift/drift.dart';

import '../db/database.dart';
import '../tmdb/tvdb.dart';
import 'parser.dart';

DateTime _dateOrNow(String? iso) =>
    (iso == null ? null : DateTime.tryParse(iso)) ?? DateTime.now();

/// Restaure un backup JSON exporté par la version web de TrackTime.
/// Fusionne dans la base (n'écrase pas l'existant). Renvoie la clé TMDB
/// trouvée dans le backup, le cas échéant.
Future<({int shows, int movies, String? tmdbKey})> importWebBackup(
    AppDatabase db, Map<String, dynamic> backup) async {
  var showCount = 0, movieCount = 0;

  await db.transaction(() async {
    for (final raw in (backup['shows'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final id = (raw['id'] as num?)?.toInt();
      final name = '${raw['name'] ?? ''}';
      if (id == null || name.isEmpty) continue;
      await db.upsertShow(ShowsCompanion.insert(
        id: Value(id),
        name: name,
        poster: Value(raw['poster'] as String?),
        totalEpisodes: Value((raw['total'] as num?)?.toInt()),
        seasonCount: Value((raw['seasons'] as num?)?.toInt()),
        runtime: Value((raw['runtime'] as num?)?.toInt() ?? 42),
        status: Value(raw['status'] as String?),
      ));
      final watched = raw['watched'];
      if (watched is Map) {
        for (final entry in watched.entries) {
          final m = RegExp(r'^S(\d+)E(\d+)$').firstMatch('${entry.key}');
          if (m == null) continue;
          await db.setEpisodeWatched(
            id,
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            at: _dateOrNow('${entry.value}'),
          );
        }
      }
      showCount++;
    }

    for (final raw in (backup['movies'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final id = (raw['id'] as num?)?.toInt();
      final title = '${raw['title'] ?? ''}';
      if (id == null || title.isEmpty) continue;
      if (await db.movieById(id) != null) continue;
      final watchedAt = raw['watchedAt'] as String?;
      await db.upsertMovie(MoviesCompanion.insert(
        id: Value(id),
        title: title,
        poster: Value(raw['poster'] as String?),
        runtime: Value((raw['runtime'] as num?)?.toInt() ?? 110),
        watchedAt:
            Value(watchedAt == null ? null : DateTime.tryParse(watchedAt)),
      ));
      movieCount++;
    }
  });

  final key = backup['key'];
  return (
    shows: showCount,
    movies: movieCount,
    tmdbKey: key is String && key.isNotEmpty ? key : null,
  );
}

class ImportSummary {
  int matched = 0;
  int failed = 0;
}

/// Importe des entrées TV Time parsées en les faisant correspondre sur
/// TheTVDB (matching par titre). [onProgress] est appelé après chaque élément.
Future<ImportSummary> runTvTimeImport(
  AppDatabase db,
  TvdbClient tvdb,
  ParsedData parsed, {
  required void Function(double pct, String? logLine) onProgress,
  Future<void> Function()? throttle,
}) async {
  final summary = ImportSummary();
  final showNames = parsed.byShow.keys.toList();

  // Dédoublonne les films par titre (un même film peut apparaître plusieurs fois).
  final uniqueMovies = <String, ParsedMovie>{};
  for (final m in parsed.movies) {
    uniqueMovies.putIfAbsent(m.title.toLowerCase(), () => m);
  }
  final movieList = uniqueMovies.values.toList();

  final total = showNames.length + movieList.length;
  var done = 0;

  void step(String? log) {
    done++;
    onProgress(total == 0 ? 1 : done / total, log);
  }

  for (final name in showNames) {
    try {
      final results = await tvdb.search(name, type: 'series');
      final id = results.isEmpty ? null : TvdbClient.tvdbId(results.first);
      if (id == null) {
        summary.failed++;
        step('❓ Série introuvable sur TheTVDB : $name');
      } else {
        if (await db.showById(id) == null) {
          final d = await tvdb.seriesExtended(id);
          await db.upsertShow(ShowsCompanion.insert(
            id: Value(id),
            name: '${d['name'] ?? name}',
            poster: Value(TvdbClient.posterOf(d)),
            runtime: Value((d['averageRuntime'] as num?)?.toInt() ?? 42),
            status: Value(TvdbClient.statusOf(d)),
            genres: Value(TvdbClient.genresOf(d)),
          ));
        }
        for (final ep in parsed.byShow[name]!) {
          await db.setEpisodeWatched(id, ep.season, ep.episode,
              at: _dateOrNow(ep.date));
        }
        summary.matched++;
        step(null);
      }
    } on TvdbException catch (e) {
      summary.failed++;
      step('⚠️ $name : $e');
    }
    await throttle?.call();
  }

  for (final m in movieList) {
    try {
      final results = await tvdb.search(m.title, type: 'movie');
      final id = results.isEmpty ? null : TvdbClient.tvdbId(results.first);
      if (id == null) {
        summary.failed++;
        step('❓ Film introuvable sur TheTVDB : ${m.title}');
      } else {
        if (await db.movieById(id) == null) {
          final r = results.first;
          await db.upsertMovie(MoviesCompanion.insert(
            id: Value(id),
            title: '${r['name'] ?? m.title}',
            poster: Value(r['image_url'] as String?),
            watchedAt: Value(m.watched ? _dateOrNow(m.date) : null),
          ));
        }
        summary.matched++;
        step(null);
      }
    } on TvdbException catch (e) {
      summary.failed++;
      step('⚠️ ${m.title} : $e');
    }
    await throttle?.call();
  }

  return summary;
}
