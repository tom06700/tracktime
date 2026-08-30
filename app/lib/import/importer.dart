import 'package:drift/drift.dart';

import '../db/database.dart';
import '../tmdb/add.dart';
import '../tmdb/search_result.dart';
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
/// TheTVDB (matching par titre). Traitement en parallèle borné pour la
/// rapidité. [onProgress] est appelé après chaque élément terminé.
Future<ImportSummary> runTvTimeImport(
  AppDatabase db,
  TvdbClient tvdb,
  ParsedData parsed, {
  required void Function(double pct, String? logLine) onProgress,
  int concurrency = 6,
}) async {
  final summary = ImportSummary();
  final showNames = parsed.byShow.keys.toList();

  // Dédoublonne les films par titre (un même film peut apparaître plusieurs fois).
  final uniqueMovies = <String, ParsedMovie>{};
  for (final m in parsed.movies) {
    uniqueMovies.putIfAbsent(m.title.toLowerCase(), () => m);
  }
  final movieList = uniqueMovies.values.toList();

  // Une tâche par titre ; renvoie une ligne de log (null si succès sans note).
  final tasks = <Future<String?> Function()>[
    for (final name in showNames)
      () => _importShow(db, tvdb, name, parsed.byShow[name]!, summary),
    for (final m in movieList) () => _importMovie(db, tvdb, m, summary),
  ];

  final total = tasks.length;
  var done = 0;
  final it = tasks.iterator;

  // Pool de workers : chacun tire la tâche suivante dès qu'il est libre
  // (répartition naturelle, pas de barrière entre séries et films).
  Future<void> worker() async {
    while (it.moveNext()) {
      final task = it.current;
      final log = await task();
      done++;
      onProgress(total == 0 ? 1 : done / total, log);
    }
  }

  final n = total < concurrency ? total : concurrency;
  await Future.wait([for (var i = 0; i < n; i++) worker()]);
  return summary;
}

/// Meilleure correspondance pour un titre, avec le classement de la recherche
/// d'Explorer.
///
/// L'ordre brut de TheTVDB ne convient pas : pour « One Piece » il place la
/// série live-action de 2023 en tête et l'animé en huitième position. Prendre
/// le premier résultat envoyait donc tout un historique sur la mauvaise série.
Future<MediaSearchResult?> _bestMatch(
  TvdbClient tvdb,
  String title,
  SearchMediaType type,
) async {
  final raw = await tvdb.search(
    title,
    type: type == SearchMediaType.series ? 'series' : 'movie',
  );
  final ranked = rankSearchResults(parseSearchResults(raw), title);
  for (final r in ranked) {
    if (r.type == type && r.tvdbId != null) return r;
  }
  return null;
}

Future<String?> _importShow(
  AppDatabase db,
  TvdbClient tvdb,
  String name,
  List<ParsedEpisode> episodes,
  ImportSummary summary,
) async {
  try {
    final match = await _bestMatch(tvdb, name, SearchMediaType.series);
    final id = match?.tvdbId;
    if (match == null || id == null) {
      summary.failed++;
      return '❓ Série introuvable sur TheTVDB : $name';
    }
    // Passe par le même chemin que « Ajouter à ma liste » : affiche, saisons
    // officielles. Le nom vient du résultat de recherche, qui porte déjà les
    // traductions — inutile de redemander, et ça évite de retomber sur le
    // titre d'origine si l'appel de traduction échoue en pleine rafale.
    final stored = await addShowFromTvdb(
      db,
      tvdb,
      id,
      preferredName: match.name,
    );
    for (final ep in episodes) {
      await db.setEpisodeWatched(id, ep.season, ep.episode,
          at: _dateOrNow(ep.date));
    }
    summary.matched++;
    // On dit à quoi chaque titre a été rattaché : sans ça, un mauvais
    // appariement ne se découvre qu'en ouvrant la fiche, des jours plus tard.
    return '✅ $name → $stored · TheTVDB $id';
  } on TvdbException catch (e) {
    summary.failed++;
    return '⚠️ $name : $e';
  }
}

Future<String?> _importMovie(
  AppDatabase db,
  TvdbClient tvdb,
  ParsedMovie m,
  ImportSummary summary,
) async {
  try {
    final match = await _bestMatch(tvdb, m.title, SearchMediaType.movie);
    final id = match?.tvdbId;
    if (match == null || id == null) {
      summary.failed++;
      return '❓ Film introuvable sur TheTVDB : ${m.title}';
    }
    if (await db.movieById(id) == null) {
      // Pas addMovieFromTvdb ici : l'import doit poser la date de visionnage,
      // alors que l'ajout manuel range le film dans la watchlist.
      await db.upsertMovie(MoviesCompanion.insert(
        id: Value(id),
        title: match.name,
        poster: Value(match.image),
        watchedAt: Value(m.watched ? _dateOrNow(m.date) : null),
      ));
    }
    summary.matched++;
    return '✅ ${m.title} → ${match.name} · TheTVDB $id';
  } on TvdbException catch (e) {
    summary.failed++;
    return '⚠️ ${m.title} : $e';
  }
}
